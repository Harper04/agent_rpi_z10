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
#   5. You merge it there (via PR or direct merge)
#
# Usage:
#   ./scripts/git/propose-upstream.sh "better caddy TLS handling"
#   ./scripts/git/propose-upstream.sh --file .claude/agents/caddy.md "improved TLS"
#   ./scripts/git/propose-upstream.sh --patch "description"  # export as .patch file instead

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

FILES_TO_INCLUDE=()
DESCRIPTION=""
PATCH_MODE=false
SOURCE_BRANCH=$(git branch --show-current)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file|-f)  FILES_TO_INCLUDE+=("$2"); shift 2 ;;
    --patch|-p) PATCH_MODE=true; shift ;;
    *)          DESCRIPTION="$1"; shift ;;
  esac
done

if [ -z "$DESCRIPTION" ]; then
  echo "Usage: $0 [--file <path>]... [--patch] \"description\""
  echo ""
  echo "  --file <path>   Include specific file(s). Without this, auto-detects changes."
  echo "  --patch          Export as .patch file instead of pushing a branch."
  echo ""
  echo "Examples:"
  echo "  $0 \"improve health-check skill\""
  echo "  $0 --file .claude/agents/caddy.md \"better TLS docs\""
  echo "  $0 --patch \"safety improvements\"    # creates .patch file"
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

  while IFS= read -r file; do
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
  done < <(git diff --name-only upstream/main..."$SOURCE_BRANCH" 2>/dev/null || git diff --name-only upstream/main...HEAD)
fi

if [ ${#FILES_TO_INCLUDE[@]} -eq 0 ]; then
  echo "ℹ️  No shared files changed relative to upstream/main. Nothing to propose."
  exit 0
fi

echo ""
echo "📦 Files to propose:"
printf "   %s\n" "${FILES_TO_INCLUDE[@]}"

# --- Safety: block local/ and scan for secrets ---
for file in "${FILES_TO_INCLUDE[@]}"; do
  if [[ "$file" == local/* ]]; then
    echo "❌ BLOCKED: '$file' is in local/"
    exit 1
  fi
  if [ -f "$file" ] && grep -qiE "(TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID|sk-ant-|password=|secret=)" "$file" 2>/dev/null; then
    echo "⚠️  WARNING: '$file' may contain secrets — review before pushing!"
    read -rp "   Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[yY] ]] || exit 1
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
  if git show "${SOURCE_BRANCH}:${file}" &>/dev/null; then
    mkdir -p "$(dirname "$file")"
    git show "${SOURCE_BRANCH}:${file}" > "$file"
    git add "$file"
  fi
done

git commit -m "propose: ${DESCRIPTION}

$(printf '  - %s\n' "${FILES_TO_INCLUDE[@]}")

From: $(hostname) ($(date -Is))"

echo ""
echo "✅ Branch ready: $BRANCH"
echo ""
echo "Push to template repo:"
echo "  git push upstream $BRANCH"
echo ""
echo "Then on the template repo, merge the branch:"
echo "  git checkout main && git merge $BRANCH && git push"
echo "  git branch -d $BRANCH"
echo ""
echo "Return to machine branch:"
echo "  git checkout $SOURCE_BRANCH"
