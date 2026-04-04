#!/usr/bin/env bash
# propose-upstream.sh — Propose shared improvements back to the template repo.
#
# Since you own both the template and the machine repos (no fork needed),
# this script creates a feature branch with ONLY shared files and pushes
# it to the upstream (template) remote for review.
#
# Flow:
#   1. Detects shared files that differ from upstream/main
#   2. Creates a clean branch from upstream/main
#   3. Applies only the shared changes (never local/)
#   4. Pushes the branch to upstream
#   5. Returns to the original branch
#
# Usage:
#   ./scripts/git/propose-upstream.sh "better caddy TLS handling"
#   ./scripts/git/propose-upstream.sh --file .claude/agents/caddy.md "improved TLS"
#   ./scripts/git/propose-upstream.sh --yes "fix from agent"          # non-interactive
#   ./scripts/git/propose-upstream.sh --patch "description"           # export as .patch

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

FILES_TO_INCLUDE=()
DESCRIPTION=""
PATCH_MODE=false
YES=false
PUSH=true
SOURCE_BRANCH=$(git branch --show-current)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file|-f)    FILES_TO_INCLUDE+=("$2"); shift 2 ;;
    --patch|-p)   PATCH_MODE=true; shift ;;
    --yes|-y)     YES=true; shift ;;
    --no-push)    PUSH=false; shift ;;
    *)            DESCRIPTION="$1"; shift ;;
  esac
done

if [ -z "$DESCRIPTION" ]; then
  echo "Usage: $0 [--file <path>]... [--patch] [--yes] [--no-push] \"description\""
  echo ""
  echo "  --file <path>   Include specific file(s). Without this, auto-detects changes."
  echo "  --patch          Export as .patch file instead of pushing a branch."
  echo "  --yes, -y        Skip confirmation prompts (for headless/agent use)."
  echo "  --no-push        Create branch locally but don't push to upstream."
  echo ""
  echo "Examples:"
  echo "  $0 \"improve health-check skill\""
  echo "  $0 --file .claude/agents/caddy.md \"better TLS docs\""
  echo "  $0 --patch \"safety improvements\"    # creates .patch file"
  echo "  $0 --yes \"fix from agent\"           # non-interactive"
  exit 1
fi

# --- Verify upstream remote ---
if ! git remote get-url upstream &>/dev/null; then
  echo "❌ No 'upstream' remote configured."
  echo "   Run setup.sh first, or add manually:"
  echo "   git remote add upstream <template-repo-url>"
  exit 1
fi

echo "📡 Fetching upstream..."
git fetch upstream

# --- Determine files to include ---
SHARED_PREFIXES=( ".claude/" "scripts/" "docs/" "templates/" "CLAUDE.md" ".gitignore" ".env.example" "setup.sh" "README.md" )
BLOCKED_PREFIXES=( "local/" )

if [ ${#FILES_TO_INCLUDE[@]} -eq 0 ]; then
  echo "🔍 Auto-detecting shared file changes..."

  # Collect content changes, new files, renames, AND mode-only changes
  all_changed=$(git diff --name-only upstream/main..."$SOURCE_BRANCH" 2>/dev/null || git diff --name-only upstream/main...HEAD)

  while IFS= read -r file; do
    [ -z "$file" ] && continue

    # Check if shared
    shared=false
    for prefix in "${SHARED_PREFIXES[@]}"; do
      [[ "$file" == "$prefix"* || "$file" == "$prefix" ]] && shared=true && break
    done

    # Check if blocked
    for prefix in "${BLOCKED_PREFIXES[@]}"; do
      [[ "$file" == "$prefix"* ]] && shared=false && break
    done

    $shared && FILES_TO_INCLUDE+=("$file")
  done <<< "$all_changed"
fi

if [ ${#FILES_TO_INCLUDE[@]} -eq 0 ]; then
  echo "ℹ️  No shared files changed relative to upstream/main. Nothing to propose."
  exit 0
fi

echo ""
echo "📦 Files to propose:"
printf "   %s\n" "${FILES_TO_INCLUDE[@]}"

# --- Safety: block local/ and scan for secrets ---
# Match actual token patterns, not variable name references in scripts.
# This avoids false positives on files like setup.sh that mention
# TELEGRAM_BOT_TOKEN as a variable name without containing real secrets.
SECRET_PATTERNS=(
  'sk-ant-[a-zA-Z0-9]'                           # Anthropic API keys
  'ghp_[a-zA-Z0-9]{20}'                          # GitHub PATs (classic, 40+ chars)
  'github_pat_[a-zA-Z0-9]{20}'                   # GitHub PATs (fine-grained, 90+ chars)
  'ghu_[a-zA-Z0-9]'                              # GitHub user tokens
  'bot[0-9]+:[A-Za-z0-9_-]{30}'                  # Telegram bot tokens
  'AKIA[A-Z0-9]{16}'                             # AWS access key IDs
)
SECRET_REGEX=$(IFS='|'; echo "${SECRET_PATTERNS[*]}")

for file in "${FILES_TO_INCLUDE[@]}"; do
  if [[ "$file" == local/* ]]; then
    echo "❌ BLOCKED: '$file' is in local/"
    exit 1
  fi
  # Scan the source-branch version of the file (what we'd actually push)
  file_content=$(git show "${SOURCE_BRANCH}:${file}" 2>/dev/null) || continue
  if echo "$file_content" | grep -qE "$SECRET_REGEX"; then
    echo "⚠️  WARNING: '$file' may contain hardcoded secrets!"
    echo "$file_content" | grep -nE "$SECRET_REGEX" | head -5 | sed 's/^/   /'
    if $YES; then
      echo "   --yes passed, continuing..."
    else
      read -rp "   Continue? [y/N] " confirm
      [[ "$confirm" =~ ^[yY] ]] || exit 1
    fi
  fi
done

# --- Create branch name ---
SLUG=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 50)
BRANCH="propose/${SLUG}-$(date +%Y%m%d)"

# --- Patch mode: export as .patch file ---
if $PATCH_MODE; then
  PATCH_FILE="$REPO_ROOT/${BRANCH//\//-}.patch"
  git diff upstream/main -- "${FILES_TO_INCLUDE[@]}" > "$PATCH_FILE"
  echo ""
  echo "✅ Patch exported: $PATCH_FILE"
  echo "   Apply on template repo with: git apply $PATCH_FILE"
  exit 0
fi

# --- Branch mode: push to upstream ---
echo ""
echo "🌿 Creating branch: $BRANCH"

git checkout -b "$BRANCH" upstream/main

for file in "${FILES_TO_INCLUDE[@]}"; do
  mkdir -p "$(dirname "$file")"
  # Use git show piped to file — preserves trailing newlines and backslashes
  # (echo "$var" would strip trailing newlines and mangle backslashes)
  if ! git show "${SOURCE_BRANCH}:${file}" > "$file" 2>/dev/null; then
    echo "  ⚠️  Skipping '$file' — not found in $SOURCE_BRANCH"
    continue
  fi
  # Preserve file permissions from source branch (catches mode-only changes)
  src_mode=$(git ls-tree "$SOURCE_BRANCH" "$file" 2>/dev/null | awk '{print $1}')
  if [ "$src_mode" = "100755" ]; then
    chmod +x "$file"
  fi
  git add "$file"
done

# Check we have something to commit
if git diff --cached --quiet; then
  echo "ℹ️  No changes to commit. Returning to $SOURCE_BRANCH."
  git checkout "$SOURCE_BRANCH"
  git branch -D "$BRANCH"
  exit 0
fi

git commit -m "propose: ${DESCRIPTION}

$(printf '  - %s\n' "${FILES_TO_INCLUDE[@]}")

From: $(hostname) ($(date -Is))"

echo ""
echo "✅ Branch ready: $BRANCH"

if $PUSH; then
  echo ""
  echo "📤 Pushing to upstream..."
  git push upstream "$BRANCH"
  echo "✅ Pushed. Create a PR at:"
  echo "   https://github.com/$(git remote get-url upstream | sed -E 's#.*github.com[:/]##; s#\.git$##')/pull/new/$BRANCH"
else
  echo ""
  echo "Push manually:"
  echo "  git push upstream $BRANCH"
fi

# --- Return to original branch ---
echo ""
echo "↩️  Returning to $SOURCE_BRANCH"
git checkout "$SOURCE_BRANCH"
