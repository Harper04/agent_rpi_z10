#!/usr/bin/env bash
# sync-upstream.sh — Pull shared improvements from the template repo.
#
# Your machine repo was cloned from the template. The template remote
# is called 'upstream'. This script merges template updates into your
# machine's main branch without touching local/.
#
# Usage:
#   ./scripts/git/sync-upstream.sh              # merge
#   ./scripts/git/sync-upstream.sh --rebase     # rebase instead
#   ./scripts/git/sync-upstream.sh --dry-run    # preview only

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

MODE="merge"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebase)  MODE="rebase"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    *)         echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Verify ---
if ! git remote get-url upstream &>/dev/null; then
  echo "❌ No 'upstream' remote. Add it:"
  echo "   git remote add upstream <template-repo-url>"
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️  Uncommitted changes. Commit or stash first."
  exit 1
fi

echo "📡 Fetching upstream..."
git fetch upstream

UPSTREAM=$(git rev-parse upstream/main 2>/dev/null)
BASE=$(git merge-base HEAD upstream/main 2>/dev/null)

if [ "$UPSTREAM" = "$BASE" ]; then
  echo "✅ Already up to date with upstream template."
  exit 0
fi

# --- Load acknowledgements ---
ACK_FILE="$REPO_ROOT/local/.sync-ack"
ACKED_HASHES=()
if [ -f "$ACK_FILE" ]; then
  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    hash=$(echo "$line" | awk '{print $1}')
    [ -n "$hash" ] && ACKED_HASHES+=("$hash")
  done < "$ACK_FILE"
fi

# Collect all pending commits (short hashes)
ALL_PENDING=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  short=$(echo "$line" | awk '{print $1}')
  ALL_PENDING+=("$short")
done < <(git --no-pager log --oneline "$BASE..$UPSTREAM")

# Filter out acknowledged commits
UNACKED=()
ACKED_COUNT=0
for entry in "${ALL_PENDING[@]}"; do
  acked=false
  for ack in "${ACKED_HASHES[@]}"; do
    # Match if entry starts with ack hash or ack starts with entry (prefix match)
    if [[ "$entry" == "${ack}"* || "${ack}" == "${entry}"* ]]; then
      acked=true
      (( ACKED_COUNT++ )) || true
      break
    fi
  done
  $acked || UNACKED+=("$entry")
done

# All commits acknowledged?
if [ ${#UNACKED[@]} -eq 0 ]; then
  if [ $ACKED_COUNT -gt 0 ]; then
    echo "✅ Up to date (${ACKED_COUNT} commit(s) reviewed and acknowledged)."
  else
    echo "✅ Already up to date with upstream template."
  fi
  exit 0
fi

echo ""
echo "📋 New commits from template (${#UNACKED[@]} unreviewed):"
git --no-pager log --oneline "$BASE..$UPSTREAM" | head -20

if [ $ACKED_COUNT -gt 0 ]; then
  echo "   ℹ️  ${ACKED_COUNT} acknowledged commit(s) hidden — see local/.sync-ack"
fi

echo ""
echo "📁 Changed files:"
git diff --stat "$BASE..upstream/main" -- \
  .claude/ scripts/ docs/ templates/ CLAUDE.md .gitignore .env.example setup.sh README.md 2>/dev/null

if $DRY_RUN; then
  echo ""
  echo "ℹ️  Dry run — no changes applied."
  exit 0
fi

echo ""
if [ "$MODE" = "rebase" ]; then
  echo "🔄 Rebasing onto upstream/main..."
  git rebase upstream/main
else
  echo "🔀 Merging upstream/main..."
  git merge upstream/main --no-edit -m "chore: sync with upstream template $(date -I)"
fi

echo ""
echo "✅ Shared files synced."

# --- Install/update git hooks ---
INSTALL_HOOKS="$REPO_ROOT/scripts/git/install-hooks.sh"
if [ -x "$INSTALL_HOOKS" ]; then
  echo ""
  bash "$INSTALL_HOOKS"
fi

# --- Sync template updates to local/ ---
SYNC_TEMPLATES="$REPO_ROOT/scripts/git/sync-templates.sh"
if [ -x "$SYNC_TEMPLATES" ]; then
  echo ""
  echo "━━━ Template → local/ sync ━━━"
  if $DRY_RUN; then
    "$SYNC_TEMPLATES" --dry-run
  else
    "$SYNC_TEMPLATES"
  fi
fi

echo ""
echo "Conflict resolution tips:"
echo "  - Shared files (.claude/, scripts/): prefer upstream version"
echo "  - local/ is never in upstream, so no conflicts there"
echo "  - templates/local/: take upstream (your local/ is separate)"
echo ""
echo "Verify: claude --agent orchestrator -p '/status'"
