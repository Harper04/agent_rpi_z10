#!/usr/bin/env bash
# manage-users.sh — Manage caddy-security local user database
#
# Usage:
#   ./scripts/caddy/manage-users.sh list
#   ./scripts/caddy/manage-users.sh add <username> <email> <password>
#   ./scripts/caddy/manage-users.sh remove <username>
#   ./scripts/caddy/manage-users.sh reset-password <username> <new-password>
#
# Note: caddy-security manages users.json. This script provides a CLI wrapper
# for common operations. For passkey management, use the web portal.

set -euo pipefail

USERS_FILE="/var/lib/caddy/users.json"

# Check dependencies
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required. Install with: apt install -y jq"
    exit 1
fi

if [ ! -f "$USERS_FILE" ]; then
    echo "ERROR: User database not found at $USERS_FILE"
    echo "Has Caddy with caddy-security been started at least once?"
    exit 1
fi

ACTION="${1:-help}"
shift || true

case "$ACTION" in
    list)
        echo "=== Caddy Portal Users ==="
        sudo jq -r '.revision as $rev | .users[] | "\(.username)\t\(.email_address.address // "n/a")\t\(.roles // [] | join(","))"' "$USERS_FILE" 2>/dev/null | \
            column -t -s $'\t' -N "USERNAME,EMAIL,ROLES" || echo "(no users found or unexpected format)"
        echo ""
        echo "Total: $(sudo jq '.users | length' "$USERS_FILE" 2>/dev/null || echo 0) users"
        ;;

    add)
        USERNAME="${1:?Usage: $0 add <username> <email> <password>}"
        EMAIL="${2:?Usage: $0 add <username> <email> <password>}"
        PASSWORD="${3:?Usage: $0 add <username> <email> <password>}"

        echo "Adding user: $USERNAME ($EMAIL)"
        echo ""
        echo "NOTE: caddy-security manages its own user database format."
        echo "The recommended way to add users is via the web portal's"
        echo "registration flow, or by setting AUTHP_ADMIN_* env vars"
        echo "for the initial admin user."
        echo ""
        echo "For programmatic user management, consider using the"
        echo "caddy-security API or restarting Caddy with updated"
        echo "AUTHP_ADMIN_* environment variables."
        echo ""
        echo "If you need to add users frequently, enable self-registration"
        echo "in the Caddyfile authentication portal block:"
        echo "  registration { ... }"
        ;;

    remove)
        USERNAME="${1:?Usage: $0 remove <username>}"

        echo "Removing user: $USERNAME"
        echo ""
        echo "WARNING: This directly modifies the user database."
        echo "A backup will be created first."

        # Backup
        BACKUP="${USERS_FILE}.bak.$(date -I)"
        sudo cp "$USERS_FILE" "$BACKUP"
        echo "Backup: $BACKUP"

        # Remove user
        sudo jq --arg user "$USERNAME" 'del(.users[] | select(.username == $user))' "$USERS_FILE" | \
            sudo tee "${USERS_FILE}.tmp" > /dev/null
        sudo mv "${USERS_FILE}.tmp" "$USERS_FILE"
        sudo chown caddy:caddy "$USERS_FILE"

        echo "User '$USERNAME' removed."
        echo "Reload Caddy to apply: sudo systemctl reload caddy"
        ;;

    reset-password)
        USERNAME="${1:?Usage: $0 reset-password <username> <new-password>}"
        NEW_PASSWORD="${2:?Usage: $0 reset-password <username> <new-password>}"

        echo "Password reset for user: $USERNAME"
        echo ""
        echo "NOTE: caddy-security stores bcrypt-hashed passwords."
        echo "Direct password reset via JSON manipulation is fragile."
        echo ""
        echo "Recommended approach:"
        echo "1. Remove the user: $0 remove $USERNAME"
        echo "2. Set AUTHP_ADMIN_USER=$USERNAME in /etc/caddy/env"
        echo "3. Set AUTHP_ADMIN_SECRET=$NEW_PASSWORD in /etc/caddy/env"
        echo "4. Delete users.json and restart Caddy (it recreates the admin)"
        echo ""
        echo "Or use the portal's password recovery if email is configured."
        ;;

    help|--help|-h)
        echo "Usage: $0 <action> [args]"
        echo ""
        echo "Actions:"
        echo "  list                              List all users"
        echo "  add <username> <email> <password>  Add a user (guidance)"
        echo "  remove <username>                  Remove a user"
        echo "  reset-password <username> <pass>   Reset password (guidance)"
        echo ""
        echo "User database: $USERS_FILE"
        echo "For passkey management, use the web portal."
        ;;

    *)
        echo "Unknown action: $ACTION"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
