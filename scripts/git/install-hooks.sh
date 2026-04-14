#!/usr/bin/env bash
# install-hooks.sh — Install/update git hooks from scripts/hooks/.
#
# Idempotent — safe to run repeatedly. Called by setup.sh and sync-upstream.sh.
# Uses symlinks so hooks auto-update when the source script is synced from upstream.

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/../.." rev-parse --show-toplevel)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

install_hook() {
  local hook_name="$1"  # e.g. "pre-push"
  local src_file="$2"   # e.g. "scripts/hooks/pre-push-no-local-upstream.sh"
  local src="$REPO_ROOT/$src_file"
  local dst="$HOOKS_DIR/$hook_name"

  if [ ! -f "$src" ]; then
    return 0
  fi

  chmod +x "$src"

  # Already installed as symlink to the same target?
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    echo "  ℹ️  $hook_name hook up to date"
    return 0
  fi

  # Back up existing non-symlink hook
  if [ -f "$dst" ] && [ ! -L "$dst" ]; then
    cp "$dst" "${dst}.bak.$(date -I)"
    echo "  ⚠️  Backed up existing $hook_name hook"
  fi

  ln -sf "$src" "$dst"
  echo "  ✅ $hook_name hook installed → $src_file"
}

echo "📎 Installing git hooks..."
install_hook "pre-push" "scripts/hooks/pre-push-no-local-upstream.sh"
