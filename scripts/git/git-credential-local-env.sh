#!/usr/bin/env bash
# git-credential-local-env.sh — Git credential helper that reads GITHUB_TOKEN
# from local/.env. Configured per-repo so the token never leaks to global config.
#
# How it works:
#   Git calls this script with "get" on stdin when it needs credentials.
#   The script reads GITHUB_TOKEN from local/.env and returns it.
#
# Setup (done by setup.sh):
#   git config credential.helper "/path/to/git-credential-local-env.sh"

set -euo pipefail

# Find repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="$REPO_ROOT/local/.env"

# Only respond to "get" requests
ACTION="${1:-}"
if [ "$ACTION" != "get" ]; then
  exit 0
fi

# Read the request from stdin to get the host
HOST=""
PROTOCOL=""
while IFS='=' read -r key value; do
  case "$key" in
    protocol) PROTOCOL="$value" ;;
    host)     HOST="$value" ;;
  esac
done

# Only handle github.com (extend for Gitea/Forgejo if needed)
case "$HOST" in
  github.com|*.github.com) ;;
  *)
    # Unknown host — check for GITEA_TOKEN / FORGEJO_TOKEN pattern
    if [ -f "$ENV_FILE" ]; then
      source "$ENV_FILE"
      if [ -n "${GITEA_TOKEN:-}" ]; then
        echo "protocol=$PROTOCOL"
        echo "host=$HOST"
        echo "username=token"
        echo "password=$GITEA_TOKEN"
        echo ""
        exit 0
      fi
    fi
    exit 0
    ;;
esac

# Load token from local/.env
if [ ! -f "$ENV_FILE" ]; then
  exit 0
fi

source "$ENV_FILE"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  exit 0
fi

# Return credentials
echo "protocol=$PROTOCOL"
echo "host=$HOST"
echo "username=x-access-token"
echo "password=$GITHUB_TOKEN"
echo ""
