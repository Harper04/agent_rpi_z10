#!/usr/bin/env bash
# upstream-sync.sh — Auto-merge upstream/main if an LLM review deems it safe.
#
# Called directly from cron (NOT via cron-runner.sh / Claude).
# Fetches upstream, reviews the diff with Claude, and either auto-merges
# or notifies the operator via Telegram for manual review.
#
# Cron example:
#   30 */6 * * *  /path/to/sysadmin-agent/scripts/cron/upstream-sync.sh

set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/../lib/common.sh" && common_init "$0"

LOG_FILE="${LOG_DIR}/upstream-sync.log"

# ── Load env (Telegram credentials, OAuth token) ────────────────────────────
safe_source

# ── Cron PATH fix — DO NOT REMOVE ────────────────────────────────────────────
CRON_USER_HOME=$(eval echo "~$(whoami)")
for p in "$CRON_USER_HOME/.local/bin" "$CRON_USER_HOME/.npm-global/bin" "/usr/local/bin"; do
  [[ -d "$p" ]] && [[ ":$PATH:" != *":$p:"* ]] && export PATH="$p:$PATH"
done
if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
  token_line=$(grep -m1 '^export CLAUDE_CODE_OAUTH_TOKEN=' "$CRON_USER_HOME/.bashrc" 2>/dev/null || true)
  [[ -n "$token_line" ]] && eval "$token_line"
fi

log() { echo "[$(stamp)] $1" | tee -a "$LOG_FILE"; }

cd "$REPO_ROOT"

# ── Fetch upstream ───────────────────────────────────────────────────────────
log "=== upstream-sync run start ==="
git fetch upstream main >>"$LOG_FILE" 2>&1 || {
  log "ERROR: git fetch upstream failed"
  telegram_send "❌ *upstream-sync FAILED* on \`${HOSTNAME_SHORT}\`
\`git fetch upstream\` failed. Check: \`${LOG_FILE}\`"
  exit 1
}

# ── Check for new commits ───────────────────────────────────────────────────
NEW_COMMITS=$(git log main..upstream/main --oneline 2>/dev/null)
if [[ -z "$NEW_COMMITS" ]]; then
  log "No new upstream commits. Nothing to do."
  log "=== upstream-sync run complete ==="
  exit 0
fi

COMMIT_COUNT=$(echo "$NEW_COMMITS" | wc -l)
log "Found ${COMMIT_COUNT} new upstream commit(s):"
echo "$NEW_COMMITS" >> "$LOG_FILE"

# ── Build diff summary for LLM review ───────────────────────────────────────
DIFF_STAT=$(git diff main..upstream/main --stat -- ':!local/' ':!templates/local/' 2>/dev/null)
DIFF_FULL=$(git diff main..upstream/main -- ':!local/' ':!templates/local/' 2>/dev/null | head -500)

# ── LLM safety review ───────────────────────────────────────────────────────
log "Requesting LLM safety review..."

REVIEW_PROMPT="You are reviewing upstream changes to be merged into a machine-specific sysadmin-agent repo.

COMMITS:
${NEW_COMMITS}

DIFF STAT:
${DIFF_STAT}

DIFF (first 500 lines):
${DIFF_FULL}

Evaluate whether this merge is SAFE to auto-apply. Consider:
1. Could any change break existing services on the target machine?
2. Are there destructive operations (rm, DROP, disable, delete)?
3. Do any changes modify security-sensitive files (.env, credentials, SSH, firewall)?
4. Are there merge conflicts likely with local modifications?
5. Do changes look like normal improvements (docs, recipes, bug fixes, new features)?

Respond with EXACTLY one of these two formats:
SAFE: <one-line reason>
UNSAFE: <one-line reason>

Nothing else. No markdown, no extra text."

VERDICT=$(claude -p "$REVIEW_PROMPT" --output-format text 2>/dev/null | tail -1) || VERDICT="UNSAFE: LLM review failed"
log "LLM verdict: $VERDICT"

# ── Act on verdict ───────────────────────────────────────────────────────────
if [[ "$VERDICT" == SAFE:* ]]; then
  REASON="${VERDICT#SAFE: }"
  log "Auto-merging upstream/main..."

  MERGE_OUTPUT=$(git merge upstream/main -m "auto-merge upstream/main: ${REASON}

Reviewed by LLM and deemed safe to auto-apply.
Commits: ${COMMIT_COUNT}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>" 2>&1) || {
    log "ERROR: merge failed — likely conflict"
    log "$MERGE_OUTPUT"
    git merge --abort 2>/dev/null || true
    telegram_send "⚠️ *upstream-sync: merge conflict* on \`${HOSTNAME_SHORT}\`

LLM approved but merge failed (conflict).
\`\`\`
${NEW_COMMITS}
\`\`\`
Manual merge required."
    exit 1
  }

  log "$MERGE_OUTPUT"

  # Verify cron-runner.sh token block survived (known merge pitfall)
  if ! grep -q "CLAUDE_CODE_OAUTH_TOKEN" "$REPO_ROOT/scripts/cron/cron-runner.sh" 2>/dev/null; then
    log "WARNING: cron-runner.sh lost OAUTH_TOKEN block after merge!"
    git merge --abort 2>/dev/null || true
    telegram_send "⚠️ *upstream-sync: post-merge check failed* on \`${HOSTNAME_SHORT}\`

cron-runner.sh lost the OAUTH_TOKEN block. Auto-merge reverted.
Manual merge required."
    exit 1
  fi

  # Push to origin
  git push origin main >>"$LOG_FILE" 2>&1 || true

  telegram_send "✅ *upstream-sync* on \`${HOSTNAME_SHORT}\`

Auto-merged ${COMMIT_COUNT} commit(s) from upstream.
LLM: \`${REASON}\`
\`\`\`
${NEW_COMMITS}
\`\`\`"

  log "Auto-merge complete."
else
  REASON="${VERDICT#UNSAFE: }"
  log "Merge flagged as unsafe. Notifying operator."

  telegram_send "🔍 *upstream-sync: review needed* on \`${HOSTNAME_SHORT}\`

${COMMIT_COUNT} new upstream commit(s) require manual review.
LLM: \`${REASON}\`
\`\`\`
${NEW_COMMITS}
\`\`\`
Run \`/sync\` or \`git merge upstream/main\` to apply."
fi

# ── Rotate log ───────────────────────────────────────────────────────────────
if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE")" -gt 524288 ]; then
  mv "$LOG_FILE" "${LOG_FILE}.1"
fi

log "=== upstream-sync run complete ==="
