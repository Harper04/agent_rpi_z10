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

echo ""
echo "📋 New commits from template:"
git --no-pager log --oneline "$BASE..$UPSTREAM" | head -20

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

# --- Protect local/ from upstream deletions ---
# Upstream should never contain local/, but if it once did and then removed
# those files, the merge would propagate the deletion. Snapshot local/ before
# merging so we can restore it afterwards.
LOCAL_SNAPSHOT=""
if [ -d "$REPO_ROOT/local" ] && [ "$(git ls-files local/ | wc -l)" -gt 0 ]; then
  LOCAL_SNAPSHOT=$(mktemp -d)
  echo "🔒 Snapshotting local/ before merge..."
  git ls-files local/ | while read -r f; do
    mkdir -p "$LOCAL_SNAPSHOT/$(dirname "$f")"
    cp "$f" "$LOCAL_SNAPSHOT/$f"
  done
fi

if [ "$MODE" = "rebase" ]; then
  echo "🔄 Rebasing onto upstream/main..."
  git rebase upstream/main
else
  echo "🔀 Merging upstream/main..."
  git merge upstream/main --no-edit -m "chore: sync with upstream template $(date -I)"
fi

# --- Restore local/ if the merge deleted any files ---
if [ -n "$LOCAL_SNAPSHOT" ]; then
  DELETED=$(git diff --name-only --diff-filter=D HEAD~1 -- local/ 2>/dev/null || true)
  if [ -n "$DELETED" ]; then
    echo "⚠️  Merge deleted local/ files — restoring from snapshot..."
    echo "$DELETED" | while read -r f; do
      if [ -f "$LOCAL_SNAPSHOT/$f" ]; then
        mkdir -p "$(dirname "$f")"
        cp "$LOCAL_SNAPSHOT/$f" "$f"
        git add "$f"
        echo "  restored: $f"
      fi
    done
    git commit -m "fix: restore local/ files deleted by upstream merge"
    echo "✅ local/ files restored."
  fi
  rm -rf "$LOCAL_SNAPSHOT"
fi

echo ""
echo "✅ Shared files synced."

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
