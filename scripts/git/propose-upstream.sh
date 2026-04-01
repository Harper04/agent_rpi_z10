#!/usr/bin/env bash
# propose-upstream.sh — Propose shared improvements back to the upstream template.
#
# This script:
# 1. Creates a branch from upstream/main
# 2. Cherry-picks ONLY shared files (no local/ content) from the current branch
# 3. Pushes the branch to upstream for PR creation
#
# Usage:
#   ./scripts/git/propose-upstream.sh "improve caddy agent TLS handling"
#   ./scripts/git/propose-upstream.sh --file .claude/agents/caddy.md "better TLS docs"
#
# Prerequisites:
#   - git remote 'upstream' configured
#   - Push access to upstream (or fork + PR via GitHub)

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# --- Parse arguments ---
FILES_TO_INCLUDE=()
DESCRIPTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file|-f)
      FILES_TO_INCLUDE+=("$2")
      shift 2
      ;;
    *)
      DESCRIPTION="$1"
      shift
      ;;
  esac
done

if [ -z "$DESCRIPTION" ]; then
  echo "Usage: $0 [--file <path>]... \"description of the improvement\""
  echo ""
  echo "Examples:"
  echo "  $0 \"improve caddy agent TLS handling\""
  echo "  $0 --file .claude/agents/caddy.md \"better TLS docs\""
  echo "  $0 --file .claude/skills/health-check.md --file scripts/hooks/validate-destructive.sh \"safety improvements\""
  exit 1
fi

# --- Verify upstream remote ---
if ! git remote get-url upstream &>/dev/null; then
  echo "❌ No 'upstream' remote found."
  echo "   Add it with: git remote add upstream <template-repo-url>"
  exit 1
fi

echo "📡 Fetching upstream..."
git fetch upstream

# --- Determine which files to include ---
SHARED_PATHS=(
  ".claude/agents/"
  ".claude/skills/"
  ".claude/commands/"
  ".claude/settings.json"
  "scripts/"
  "docs/"
  "CLAUDE.md"
  ".gitignore"
  ".env.example"
)

BLOCKED_PATHS=(
  "local/"
  ".env"
  "*.key"
  "*.pem"
)

# If specific files given, use those; otherwise auto-detect changed shared files
if [ ${#FILES_TO_INCLUDE[@]} -eq 0 ]; then
  echo "🔍 Detecting shared files changed since upstream/main..."
  
  while IFS= read -r file; do
    is_shared=false
    for prefix in "${SHARED_PATHS[@]}"; do
      if [[ "$file" == $prefix* ]]; then
        is_shared=true
        break
      fi
    done
    
    is_blocked=false
    for pattern in "${BLOCKED_PATHS[@]}"; do
      if [[ "$file" == $pattern* ]]; then
        is_blocked=true
        break
      fi
    done
    
    if $is_shared && ! $is_blocked; then
      FILES_TO_INCLUDE+=("$file")
    fi
  done < <(git diff --name-only upstream/main...HEAD)
fi

if [ ${#FILES_TO_INCLUDE[@]} -eq 0 ]; then
  echo "ℹ️  No shared files changed relative to upstream/main."
  echo "   Nothing to propose."
  exit 0
fi

echo ""
echo "📦 Files to propose upstream:"
printf "   %s\n" "${FILES_TO_INCLUDE[@]}"

# --- Safety check: ensure no local content ---
for file in "${FILES_TO_INCLUDE[@]}"; do
  if [[ "$file" == local/* ]]; then
    echo "❌ BLOCKED: '$file' is in local/ — cannot push to upstream."
    exit 1
  fi
  if grep -qiE "(TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID|sk-ant-|password|secret)" "$file" 2>/dev/null; then
    echo "⚠️  WARNING: '$file' may contain secrets. Please review before pushing."
  fi
done

# --- Create proposal branch ---
BRANCH_SLUG=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 50)
BRANCH_NAME="propose/${BRANCH_SLUG}-$(date +%Y%m%d)"

echo ""
echo "🌿 Creating branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME" upstream/main

# --- Copy files from the working branch ---
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD@{-1} 2>/dev/null || echo "main")
for file in "${FILES_TO_INCLUDE[@]}"; do
  if git show "${CURRENT_BRANCH}:${file}" &>/dev/null; then
    mkdir -p "$(dirname "$file")"
    git show "${CURRENT_BRANCH}:${file}" > "$file"
    git add "$file"
  fi
done

git commit -m "propose: ${DESCRIPTION}

Files:
$(printf '  - %s\n' "${FILES_TO_INCLUDE[@]}")

Proposed from: $(hostname) ($(date -Is))"

echo ""
echo "✅ Proposal branch created: $BRANCH_NAME"
echo ""
echo "Next steps:"
echo "  1. Review:  git diff upstream/main...$BRANCH_NAME"
echo "  2. Push:    git push upstream $BRANCH_NAME"
echo "  3. Create PR on the upstream repository"
echo "  4. Return:  git checkout main"
echo ""
echo "Or push directly:"
echo "  git push upstream $BRANCH_NAME && git checkout main"
