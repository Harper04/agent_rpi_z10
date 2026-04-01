---
name: rotate-token
description: Rotate the GitHub fine-grained PAT for this machine
user-invocable: true
---

# Rotate GitHub Token

Guide the operator through rotating the fine-grained PAT.

## Steps

1. **Check current token validity:**
   ```bash
   source local/.env
   curl -s -o /dev/null -w "HTTP %{http_code}" \
     -H "Authorization: Bearer $GITHUB_TOKEN" \
     https://api.github.com/user
   ```

2. **If expired or soon-to-expire**, tell the operator:
   - Go to https://github.com/settings/personal-access-tokens
   - Create new token scoped to: template repo + this machine's repo
   - Permissions: Contents (Read and write)

3. **Once operator provides the new token**, update it:
   ```bash
   # Update token in local/.env
   sed -i "s|^GITHUB_TOKEN=.*|GITHUB_TOKEN=<new-token>|" local/.env
   ```

4. **Verify new token:**
   ```bash
   source local/.env
   curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
     https://api.github.com/user | jq '.login'
   ```

5. **Test git access:**
   ```bash
   git fetch upstream
   git fetch origin
   ```

6. **Document** in `local/docs/changelog.md`.

## Token Expiration Reminder

Fine-grained PATs have an expiration date. Consider adding a cron job
to check token validity weekly:
```bash
# In crontab:
0 8 * * 1  /path/to/sysadmin-agent/scripts/cron/cron-runner.sh "rotate-token check"
```
