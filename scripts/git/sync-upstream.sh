#!/usr/bin/env bash
# sync-upstream.sh — Pull shared improvements from the upstream template.
#
# This merges upstream/main into the current branch, pulling in:
# - Updated agents, skills, commands, hooks
# - Improved scripts
# - Template updates
#
# Your local/ directory is never affected (it doesn't exist in upstream).
#
# Usage:
#   ./scripts/git/sync-upstream.sh          # merge upstream/main
#   ./scripts/git/sync-upstream.sh --rebase  # rebase onto upstream/main
#   ./scripts/git/sync-upstream.sh --dry-run # show what would change

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

# --- Verify upstream remote ---
if ! git remote get-url upstream &>/dev/null; then
  echo "❌ No 'upstream' remote found."
  echo "   Add it with: git remote add upstream <template-repo-url>"
  exit 1
fi

# --- Check for uncommitted changes ---
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️  You have uncommitted changes. Commit or stash them first."
  exit 1
fi

echo "📡 Fetching upstream..."
git fetch upstream

CURRENT=$(git rev-parse HEAD)
UPSTREAM=$(git rev-parse upstream/main)
BASE=$(git merge-base HEAD upstream/main)

if [ "$UPSTREAM" = "$BASE" ]; then
  echo "✅ Already up to date with upstream."
  exit 0
fi

# --- Show what would change ---
echo ""
echo "📋 Changes from upstream since last sync:"
git --no-pager log --oneline "$BASE..$UPSTREAM" | head -20

echo ""
echo "📁 Files that would change:"
git diff --stat "$BASE..upstream/main" -- \
  .claude/ scripts/ docs/ CLAUDE.md .gitignore .env.example

if $DRY_RUN; then
  echo ""
  echo "ℹ️  Dry run — no changes applied."
  echo "   Run without --dry-run to apply."
  exit 0
fi

# --- Apply changes ---
echo ""
if [ "$MODE" = "rebase" ]; then
  echo "🔄 Rebasing onto upstream/main..."
  git rebase upstream/main
else
  echo "🔀 Merging upstream/main..."
  git merge upstream/main --no-edit -m "chore: sync with upstream template $(date -I)"
fi

echo ""
echo "✅ Sync complete."
echo ""
echo "If there were conflicts:"
echo "  1. Resolve them (shared files should generally take upstream version)"
echo "  2. Keep your local/ customizations"
echo "  3. git add <resolved-files> && git commit"
echo ""
echo "Post-sync checklist:"
echo "  - [ ] Check that agents still work: claude --agent orchestrator -p '/status'"
echo "  - [ ] Review any new agents/skills that were added"
echo "  - [ ] Update local/CLAUDE.local.md if new features need local config"
