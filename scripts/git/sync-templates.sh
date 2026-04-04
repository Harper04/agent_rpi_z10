#!/usr/bin/env bash
# sync-templates.sh — Apply template updates to local/ files.
#
# When templates/local/ is updated upstream (bug fix, enhancement), this
# script detects which local files can be safely updated vs which were
# customized by the machine and need manual review.
#
# Uses local/.template-versions to track which template commit each
# local file was seeded/synced from.
#
# Usage:
#   ./scripts/git/sync-templates.sh              # interactive
#   ./scripts/git/sync-templates.sh --dry-run    # preview only
#   ./scripts/git/sync-templates.sh --yes        # auto-apply safe updates
#
# Called by sync-upstream.sh after merging shared files.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

DRY_RUN=false
AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=true; shift ;;
    --yes|-y)   AUTO_YES=true; shift ;;
    *)          echo "Unknown option: $1"; exit 1 ;;
  esac
done

VERSIONS_FILE="local/.template-versions"
TEMPLATES_DIR="templates/local"

# --- Ensure versions file exists ---
mkdir -p local
touch "$VERSIONS_FILE"

# --- Collect template files ---
if [ ! -d "$TEMPLATES_DIR" ]; then
  echo "ℹ️  No templates/local/ directory. Nothing to sync."
  exit 0
fi

# Find all files in templates/local/ (skip .gitkeep)
TEMPLATE_FILES=()
while IFS= read -r -d '' f; do
  rel="${f#$TEMPLATES_DIR/}"
  [[ "$rel" == *".gitkeep" ]] && continue
  TEMPLATE_FILES+=("$rel")
done < <(find "$TEMPLATES_DIR" -type f -print0 | sort -z)

if [ ${#TEMPLATE_FILES[@]} -eq 0 ]; then
  echo "ℹ️  No template files found."
  exit 0
fi

# --- Categorize each file ---
AUTO_UPDATE=()
NEEDS_REVIEW=()
NEW_FILES=()
UNCHANGED=()

for rel in "${TEMPLATE_FILES[@]}"; do
  template_file="$TEMPLATES_DIR/$rel"
  local_file="local/$rel"

  # Get current template content hash
  template_hash=$(git hash-object "$template_file" 2>/dev/null || md5sum "$template_file" | awk '{print $1}')

  # Get the hash recorded when this file was last synced
  recorded_hash=$(grep "^${rel}=" "$VERSIONS_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true)

  if [ ! -f "$local_file" ]; then
    # File doesn't exist locally — new template file
    NEW_FILES+=("$rel")
  elif [ "$template_hash" = "$recorded_hash" ]; then
    # Template hasn't changed since last sync
    UNCHANGED+=("$rel")
  else
    # Template changed. Check if local file was customized.
    local_hash=$(git hash-object "$local_file" 2>/dev/null || md5sum "$local_file" | awk '{print $1}')

    if [ -n "$recorded_hash" ] && [ "$local_hash" = "$recorded_hash" ]; then
      # Local file matches the old template version — safe to auto-update
      AUTO_UPDATE+=("$rel")
    elif [ -z "$recorded_hash" ]; then
      # No recorded version (pre-tracking file). Compare content directly.
      if diff -q "$template_file" "$local_file" &>/dev/null; then
        # Identical — just record the hash
        UNCHANGED+=("$rel")
      else
        # Different and no history — needs review
        NEEDS_REVIEW+=("$rel")
      fi
    else
      # Local was customized AND template changed — needs review
      NEEDS_REVIEW+=("$rel")
    fi
  fi
done

# --- Report ---
echo "📦 Template sync status:"
echo ""

total_actionable=$(( ${#AUTO_UPDATE[@]} + ${#NEW_FILES[@]} + ${#NEEDS_REVIEW[@]} ))

if [ "$total_actionable" -eq 0 ]; then
  echo "  ✅ All template files up to date. (${#UNCHANGED[@]} files unchanged)"

  # Still update version tracking for any untracked files
  for rel in "${UNCHANGED[@]}"; do
    template_file="$TEMPLATES_DIR/$rel"
    template_hash=$(git hash-object "$template_file" 2>/dev/null || md5sum "$template_file" | awk '{print $1}')
    if ! grep -q "^${rel}=" "$VERSIONS_FILE" 2>/dev/null; then
      echo "${rel}=${template_hash}" >> "$VERSIONS_FILE"
    fi
  done
  exit 0
fi

if [ ${#AUTO_UPDATE[@]} -gt 0 ]; then
  echo "  🔄 Auto-update (local unmodified): ${#AUTO_UPDATE[@]} files"
  printf "     %s\n" "${AUTO_UPDATE[@]}"
fi

if [ ${#NEW_FILES[@]} -gt 0 ]; then
  echo "  🆕 New template files: ${#NEW_FILES[@]} files"
  printf "     %s\n" "${NEW_FILES[@]}"
fi

if [ ${#NEEDS_REVIEW[@]} -gt 0 ]; then
  echo "  ⚠️  Needs review (local customized): ${#NEEDS_REVIEW[@]} files"
  printf "     %s\n" "${NEEDS_REVIEW[@]}"
fi

echo "  ℹ️  Unchanged: ${#UNCHANGED[@]} files"

if $DRY_RUN; then
  echo ""
  echo "ℹ️  Dry run — no changes applied."

  # Show diffs for review files
  if [ ${#NEEDS_REVIEW[@]} -gt 0 ]; then
    echo ""
    echo "--- Diffs for files needing review ---"
    for rel in "${NEEDS_REVIEW[@]}"; do
      echo ""
      echo "=== $rel ==="
      diff -u "local/$rel" "$TEMPLATES_DIR/$rel" 2>/dev/null | head -30 || true
    done
  fi
  exit 0
fi

# --- Apply ---
echo ""

# Auto-update files
if [ ${#AUTO_UPDATE[@]} -gt 0 ]; then
  if $AUTO_YES; then
    confirm="y"
  else
    read -rp "Apply ${#AUTO_UPDATE[@]} auto-updates? [Y/n] " confirm
    confirm="${confirm:-y}"
  fi

  if [[ "$confirm" =~ ^[yY] ]]; then
    for rel in "${AUTO_UPDATE[@]}"; do
      mkdir -p "$(dirname "local/$rel")"
      cp "$TEMPLATES_DIR/$rel" "local/$rel"
      template_hash=$(git hash-object "$TEMPLATES_DIR/$rel")
      # Update version tracking
      if grep -q "^${rel}=" "$VERSIONS_FILE" 2>/dev/null; then
        sed -i "s|^${rel}=.*|${rel}=${template_hash}|" "$VERSIONS_FILE"
      else
        echo "${rel}=${template_hash}" >> "$VERSIONS_FILE"
      fi
      echo "  ✅ Updated: $rel"
    done
  fi
fi

# New files
if [ ${#NEW_FILES[@]} -gt 0 ]; then
  if $AUTO_YES; then
    confirm="y"
  else
    read -rp "Copy ${#NEW_FILES[@]} new template files to local/? [Y/n] " confirm
    confirm="${confirm:-y}"
  fi

  if [[ "$confirm" =~ ^[yY] ]]; then
    for rel in "${NEW_FILES[@]}"; do
      mkdir -p "$(dirname "local/$rel")"
      cp "$TEMPLATES_DIR/$rel" "local/$rel"
      template_hash=$(git hash-object "$TEMPLATES_DIR/$rel")
      echo "${rel}=${template_hash}" >> "$VERSIONS_FILE"
      echo "  🆕 Created: $rel"
    done
  fi
fi

# Files needing review — just report, don't auto-apply
if [ ${#NEEDS_REVIEW[@]} -gt 0 ]; then
  echo ""
  echo "  ⚠️  ${#NEEDS_REVIEW[@]} files need manual review:"
  for rel in "${NEEDS_REVIEW[@]}"; do
    echo "     diff local/$rel templates/local/$rel"
  done
  echo ""
  echo "  To accept the template version:"
  echo "     cp templates/local/<file> local/<file>"
  echo "  Then run this script again to update version tracking."
fi

# Update version tracking for unchanged files
for rel in "${UNCHANGED[@]}"; do
  template_hash=$(git hash-object "$TEMPLATES_DIR/$rel" 2>/dev/null || md5sum "$TEMPLATES_DIR/$rel" | awk '{print $1}')
  if ! grep -q "^${rel}=" "$VERSIONS_FILE" 2>/dev/null; then
    echo "${rel}=${template_hash}" >> "$VERSIONS_FILE"
  fi
done

# Sort versions file for readability
sort -o "$VERSIONS_FILE" "$VERSIONS_FILE"

echo ""
echo "✅ Template sync complete."
