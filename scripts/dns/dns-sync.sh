#!/usr/bin/env bash
# dns-sync.sh — Sync local DNS record files to AWS Route53.
#
# Record files live in local/dns/records/ (one file per hostname).
# File format (zone-file style, one record per line):
#   A     178.104.28.233
#   AAAA  2a01:4f8::1
#   MX    10 mail.example.com
#   CNAME example.com
#
# Optional comment: # ttl=600
#
# Ownership: each managed record gets a companion TXT record
#   _owner.<fqdn> TXT "managed-by=<OWNER_TAG>"
# Only records with a matching owner tag are deleted on cleanup.
#
# Usage:
#   dns-sync.sh              # apply changes
#   dns-sync.sh --dry-run    # show plan without applying
#   dns-sync.sh --diff       # alias for --dry-run

set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/../lib/common.sh" && common_init "$0"

# ── Defaults & Config ────────────────────────────────────────────────────────
safe_source "$ENV_FILE"

DNS_CONF="$REPO_ROOT/local/dns/dns.conf"
RECORD_DIR="$REPO_ROOT/local/dns/records"
DRY_RUN=false
OWNER_TAG="${HOSTNAME_SHORT}"
DEFAULT_TTL=300

[[ -f "$DNS_CONF" ]] && safe_source "$DNS_CONF"

# ── CLI args ─────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --dry-run|--diff) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: dns-sync.sh [--dry-run|--diff]"
      echo "Syncs local/dns/records/ to AWS Route53."
      exit 0 ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

# ── Preflight ────────────────────────────────────────────────────────────────
for cmd in aws jq; do
  command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd not found"; exit 1; }
done

if [[ ! -d "$RECORD_DIR" ]]; then
  echo "ERROR: Record directory not found: $RECORD_DIR"
  exit 1
fi

RECORD_FILES=()
while IFS= read -r f; do
  RECORD_FILES+=("$f")
done < <(find "$RECORD_DIR" -maxdepth 1 -type f ! -name '.*' ! -name '*.bak*' | sort)

if [[ ${#RECORD_FILES[@]} -eq 0 ]]; then
  echo "No record files found in $RECORD_DIR"
  echo "Create files like: $RECORD_DIR/app.example.com"
  exit 0
fi

echo "=== DNS Sync (owner=$OWNER_TAG, dry_run=$DRY_RUN) ==="
echo "Record files: ${#RECORD_FILES[@]}"
echo ""

# ── Fetch all hosted zones (once) ───────────────────────────────────────────
echo "Fetching hosted zones..."
ZONES_JSON=$(aws route53 list-hosted-zones --output json)
# Build associative arrays: zone_name -> zone_id
declare -A ZONE_MAP
while IFS=$'\t' read -r zid zname; do
  # Strip trailing dot from zone name
  zname="${zname%.}"
  ZONE_MAP["$zname"]="$zid"
done < <(echo "$ZONES_JSON" | jq -r '.HostedZones[] | select(.Config.PrivateZone == false) | [.Id, .Name] | @tsv')

if [[ ${#ZONE_MAP[@]} -eq 0 ]]; then
  echo "ERROR: No public hosted zones found in this AWS account."
  exit 1
fi

echo "Found ${#ZONE_MAP[@]} public zone(s): ${!ZONE_MAP[*]}"
echo ""

# ── Helper: find zone for FQDN (longest suffix match) ───────────────────────
resolve_zone() {
  local fqdn="$1"
  local best_match=""
  local best_len=0
  for zname in "${!ZONE_MAP[@]}"; do
    # Check if fqdn equals zname or ends with .zname
    if [[ "$fqdn" == "$zname" || "$fqdn" == *".$zname" ]]; then
      if [[ ${#zname} -gt $best_len ]]; then
        best_match="$zname"
        best_len=${#zname}
      fi
    fi
  done
  if [[ -z "$best_match" ]]; then
    echo ""
    return 1
  fi
  echo "${ZONE_MAP[$best_match]}"
}

# ── Parse all record files ───────────────────────────────────────────────────
# Build arrays: FQDN -> list of "TYPE VALUE" lines, grouped by zone
declare -A DESIRED_RECORDS  # key="fqdn|type" value="value1\nvalue2"
declare -A RECORD_TTL       # key="fqdn" value=ttl
declare -A FQDN_ZONE        # key="fqdn" value=zone_id
declare -A ZONE_FQDNS       # key=zone_id value="fqdn1 fqdn2 ..."
ERRORS=0

for file in "${RECORD_FILES[@]}"; do
  fqdn=$(basename "$file")
  ttl="$DEFAULT_TTL"

  # Auto-detect zone
  zone_id=$(resolve_zone "$fqdn") || true
  if [[ -z "$zone_id" ]]; then
    echo "ERROR: No hosted zone found for $fqdn — skipping"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  FQDN_ZONE["$fqdn"]="$zone_id"
  ZONE_FQDNS["$zone_id"]="${ZONE_FQDNS[$zone_id]:-} $fqdn"

  # Parse file
  while IFS= read -r line; do
    # Skip empty lines
    [[ -z "${line// /}" ]] && continue
    # Check for ttl comment
    if [[ "$line" =~ ^#[[:space:]]*ttl=([0-9]+) ]]; then
      ttl="${BASH_REMATCH[1]}"
      continue
    fi
    # Skip other comments
    [[ "$line" =~ ^# ]] && continue

    # Parse: TYPE VALUE...
    rtype=$(echo "$line" | awk '{print toupper($1)}')
    rvalue=$(echo "$line" | sed 's/^[[:space:]]*[^ ]*[[:space:]]*//')

    if [[ -z "$rtype" || -z "$rvalue" ]]; then
      echo "WARNING: Skipping malformed line in $fqdn: $line"
      continue
    fi

    key="${fqdn}|${rtype}"
    if [[ -n "${DESIRED_RECORDS[$key]:-}" ]]; then
      DESIRED_RECORDS["$key"]+=$'\n'"$rvalue"
    else
      DESIRED_RECORDS["$key"]="$rvalue"
    fi
  done < "$file"

  RECORD_TTL["$fqdn"]="$ttl"
done

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "WARNING: $ERRORS record file(s) had errors (see above)"
  echo ""
fi

# ── Fetch existing records per zone (once per zone) ──────────────────────────
declare -A EXISTING_RRSETS  # key=zone_id value=json

for zone_id in $(echo "${!ZONE_FQDNS[@]}" | tr ' ' '\n' | sort -u); do
  echo "Fetching records for zone $zone_id..."
  EXISTING_RRSETS["$zone_id"]=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "$zone_id" --output json)
done

# ── Helper: get existing record values from cached zone data ─────────────────
get_existing_values() {
  local zone_id="$1" fqdn="$2" rtype="$3"
  echo "${EXISTING_RRSETS[$zone_id]}" | jq -r \
    --arg name "${fqdn}." --arg type "$rtype" \
    '.ResourceRecordSets[] | select(.Name == $name and .Type == $type) | .ResourceRecords[].Value' 2>/dev/null
}

get_existing_ttl() {
  local zone_id="$1" fqdn="$2" rtype="$3"
  echo "${EXISTING_RRSETS[$zone_id]}" | jq -r \
    --arg name "${fqdn}." --arg type "$rtype" \
    '.ResourceRecordSets[] | select(.Name == $name and .Type == $type) | .TTL' 2>/dev/null
}

# ── Find all owned FQDNs in Route53 ─────────────────────────────────────────
declare -A OWNED_FQDNS  # key=fqdn value=zone_id (records we own in Route53)

for zone_id in "${!EXISTING_RRSETS[@]}"; do
  while IFS= read -r owner_name; do
    [[ -z "$owner_name" ]] && continue
    # _owner.app.example.com. -> app.example.com
    owner_name="${owner_name%.}"  # strip trailing dot
    fqdn="${owner_name#_owner.}"
    OWNED_FQDNS["$fqdn"]="$zone_id"
  done < <(echo "${EXISTING_RRSETS[$zone_id]}" | jq -r \
    --arg tag "\"managed-by=$OWNER_TAG\"" \
    '.ResourceRecordSets[] | select(.Type == "TXT" and (.Name | startswith("_owner.")) and (.ResourceRecords[]?.Value == $tag)) | .Name')
done

echo "Owned records in Route53: ${#OWNED_FQDNS[@]}"
echo ""

# ── Build change batches ─────────────────────────────────────────────────────
declare -A ZONE_CHANGES  # key=zone_id value=json array of changes
STATS_CREATE=0
STATS_UPDATE=0
STATS_DELETE=0
STATS_NOOP=0

# Helper: build a CHANGE json entry
make_change() {
  local action="$1" fqdn="$2" rtype="$3" ttl="$4"
  shift 4
  local values=("$@")

  local rrs=""
  for v in "${values[@]}"; do
    # TXT records need quoting
    if [[ "$rtype" == "TXT" ]]; then
      # Ensure value is quoted
      [[ "$v" =~ ^\" ]] || v="\"$v\""
    fi
    [[ -n "$rrs" ]] && rrs+=","
    rrs+="{\"Value\":\"$v\"}"
  done

  cat <<CHANGE
{
  "Action": "$action",
  "ResourceRecordSet": {
    "Name": "${fqdn}.",
    "Type": "$rtype",
    "TTL": $ttl,
    "ResourceRecords": [$rrs]
  }
}
CHANGE
}

add_zone_change() {
  local zone_id="$1" change="$2"
  if [[ -n "${ZONE_CHANGES[$zone_id]:-}" ]]; then
    ZONE_CHANGES["$zone_id"]+=",${change}"
  else
    ZONE_CHANGES["$zone_id"]="$change"
  fi
}

# ── Process desired records (CREATE/UPDATE) ──────────────────────────────────
declare -A DESIRED_FQDNS  # track which FQDNs we want

for key in "${!DESIRED_RECORDS[@]}"; do
  fqdn="${key%%|*}"
  rtype="${key##*|}"
  zone_id="${FQDN_ZONE[$fqdn]}"
  ttl="${RECORD_TTL[$fqdn]:-$DEFAULT_TTL}"
  DESIRED_FQDNS["$fqdn"]=1

  # Split values
  mapfile -t values <<< "${DESIRED_RECORDS[$key]}"

  # Get existing
  mapfile -t existing_values < <(get_existing_values "$zone_id" "$fqdn" "$rtype")
  existing_ttl=$(get_existing_ttl "$zone_id" "$fqdn" "$rtype")

  # Sort and compare
  desired_sorted=$(printf '%s\n' "${values[@]}" | sort)
  existing_sorted=$(printf '%s\n' "${existing_values[@]}" | sort)

  if [[ "$desired_sorted" == "$existing_sorted" && "$existing_ttl" == "$ttl" ]]; then
    STATS_NOOP=$((STATS_NOOP + 1))
    continue
  fi

  if [[ ${#existing_values[@]} -eq 0 || -z "${existing_values[0]}" ]]; then
    echo "  CREATE  $fqdn $rtype → ${values[*]} (TTL=$ttl)"
    STATS_CREATE=$((STATS_CREATE + 1))
  else
    echo "  UPDATE  $fqdn $rtype → ${values[*]} (TTL=$ttl)"
    STATS_UPDATE=$((STATS_UPDATE + 1))
  fi

  change=$(make_change "UPSERT" "$fqdn" "$rtype" "$ttl" "${values[@]}")
  add_zone_change "$zone_id" "$change"

  # Upsert owner TXT record
  owner_change=$(make_change "UPSERT" "_owner.${fqdn}" "TXT" "$ttl" "\"managed-by=$OWNER_TAG\"")
  add_zone_change "$zone_id" "$owner_change"
done

# ── Process deletions (owned records with no file) ───────────────────────────
for fqdn in "${!OWNED_FQDNS[@]}"; do
  if [[ -z "${DESIRED_FQDNS[$fqdn]:-}" ]]; then
    zone_id="${OWNED_FQDNS[$fqdn]}"

    # Find all record types for this fqdn in Route53
    while IFS=$'\t' read -r rtype rttl rvalues; do
      [[ -z "$rtype" ]] && continue
      [[ "$rtype" == "TXT" ]] && continue  # owner TXT handled separately

      echo "  DELETE  $fqdn $rtype (no file)"
      STATS_DELETE=$((STATS_DELETE + 1))

      mapfile -t vals < <(echo "$rvalues" | jq -r '.[].Value')
      change=$(make_change "DELETE" "$fqdn" "$rtype" "$rttl" "${vals[@]}")
      add_zone_change "$zone_id" "$change"
    done < <(echo "${EXISTING_RRSETS[$zone_id]}" | jq -r \
      --arg name "${fqdn}." \
      '.ResourceRecordSets[] | select(.Name == $name and .Type != "TXT") | [.Type, (.TTL | tostring), (.ResourceRecords | tojson)] | @tsv')

    # Delete owner TXT
    owner_change=$(make_change "DELETE" "_owner.${fqdn}" "TXT" "$DEFAULT_TTL" "\"managed-by=$OWNER_TAG\"")
    add_zone_change "$zone_id" "$owner_change"
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "--- Summary ---"
echo "  Create: $STATS_CREATE"
echo "  Update: $STATS_UPDATE"
echo "  Delete: $STATS_DELETE"
echo "  No-op:  $STATS_NOOP"

TOTAL_CHANGES=$((STATS_CREATE + STATS_UPDATE + STATS_DELETE))
if [[ $TOTAL_CHANGES -eq 0 ]]; then
  echo ""
  echo "Nothing to do — Route53 is in sync."
  exit 0
fi

# ── Apply changes ────────────────────────────────────────────────────────────
if $DRY_RUN; then
  echo ""
  echo "Dry run — no changes applied. Run without --dry-run to apply."
  exit 0
fi

echo ""
echo "Applying changes..."

for zone_id in "${!ZONE_CHANGES[@]}"; do
  changes="${ZONE_CHANGES[$zone_id]}"
  batch="{\"Changes\":[${changes}]}"

  # Validate JSON
  if ! echo "$batch" | jq . >/dev/null 2>&1; then
    echo "ERROR: Invalid JSON batch for zone $zone_id"
    echo "$batch" | jq . 2>&1 || true
    ERRORS=$((ERRORS + 1))
    continue
  fi

  result=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$zone_id" \
    --change-batch "$batch" \
    --output json 2>&1) || {
    echo "ERROR: Route53 API call failed for zone $zone_id:"
    echo "$result"
    ERRORS=$((ERRORS + 1))
    continue
  }

  change_id=$(echo "$result" | jq -r '.ChangeInfo.Id')
  status=$(echo "$result" | jq -r '.ChangeInfo.Status')
  echo "  Zone $zone_id: $status ($change_id)"
done

echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "Completed with $ERRORS error(s)."
  exit 1
else
  echo "Done. $TOTAL_CHANGES change(s) applied."
  exit 0
fi
