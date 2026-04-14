#!/usr/bin/env bash
# pre-push — Block pushes to the upstream remote that contain local/ files.
#
# Installed as a symlink: .git/hooks/pre-push → scripts/hooks/pre-push-no-local-upstream.sh
# Install: bash scripts/git/install-hooks.sh
#
# Git calls pre-push with: $1=remote-name $2=remote-url
# and feeds lines on stdin: <local-ref> <local-sha> <remote-ref> <remote-sha>

set -euo pipefail

remote_name="$1"

# Only guard the upstream remote — pushes to origin are unrestricted
if [ "$remote_name" != "upstream" ]; then
  exit 0
fi

ZERO="0000000000000000000000000000000000000000"

while IFS=' ' read -r local_ref local_sha remote_ref remote_sha; do
  # Skip deletes
  [ "$local_sha" = "$ZERO" ] && continue

  # For new branches, compare against upstream/main
  if [ "$remote_sha" = "$ZERO" ]; then
    base=$(git merge-base "$local_sha" upstream/main 2>/dev/null || echo "$ZERO")
    if [ "$base" = "$ZERO" ]; then
      range="$local_sha"
    else
      range="${base}..${local_sha}"
    fi
  else
    range="${remote_sha}..${local_sha}"
  fi

  # Check for local/ files in the diff
  local_files=$(git diff --name-only "$range" -- local/ 2>/dev/null || true)

  if [ -n "$local_files" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  BLOCKED: local/ files detected in push to upstream"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Remote: $remote_name ($2)"
    echo "  Ref:    $local_ref → $remote_ref"
    echo ""
    echo "  Files:"
    echo "$local_files" | sed 's/^/    /'
    echo ""
    echo "  local/ is machine-specific and must NEVER reach upstream."
    echo "  Use /contribute or propose-upstream.sh to push shared changes."
    echo ""
    exit 1
  fi
done

exit 0
