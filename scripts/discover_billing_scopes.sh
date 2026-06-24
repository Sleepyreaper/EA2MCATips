#!/usr/bin/env bash
# Discover the MCA billing scope identifiers you need for subscription creation:
# billing account name(s), billing profile name(s), and invoice section name(s).
#
# Auth: run `az login` first. Read-only — makes only GET calls.
#
# Usage:
#   scripts/discover_billing_scopes.sh                 # list billing accounts
#   scripts/discover_billing_scopes.sh --account <BA>  # + profiles & invoice sections
#
# Env override: BILLING_ACCOUNT, BILLING_API_VERSION (default 2020-05-01)
set -euo pipefail

API="${BILLING_API_VERSION:-2024-04-01}"
BASE="https://management.azure.com/providers/Microsoft.Billing"
ACCOUNT="${BILLING_ACCOUNT:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account) ACCOUNT="$2"; shift 2;;
    -h|--help) sed -n '2,15p' "$0"; exit 0;;
    *) echo "Unknown argument: $1" >&2; exit 1;;
  esac
done

command -v az >/dev/null || { echo "Azure CLI (az) not found. Install it and run 'az login'." >&2; exit 1; }

pp() { python3 -c "import sys,json;d=json.load(sys.stdin);[print(' -',x.get('name','?'),'  =>',x.get('properties',{}).get('displayName','')) for x in d.get('value',[])]"; }

echo "== Billing accounts =="
az rest --method get --url "${BASE}/billingAccounts?api-version=${API}" -o json | pp

if [[ -n "$ACCOUNT" ]]; then
  # If the caller passed a display name rather than an API name, resolve it.
  # API names contain colons or underscores and never spaces; display names may have spaces.
  if echo "$ACCOUNT" | grep -q ' '; then
    RESOLVED=$(az rest --method get --url "${BASE}/billingAccounts?api-version=${API}" -o json \
      | python3 -c "
import sys, json
accounts = json.load(sys.stdin).get('value', [])
target = sys.argv[1].lower()
matches = [a['name'] for a in accounts if a.get('properties', {}).get('displayName', '').lower() == target]
print(matches[0] if matches else '')
" "$ACCOUNT")
    if [[ -z "$RESOLVED" ]]; then
      echo "ERROR: No billing account found with display name '${ACCOUNT}'." >&2
      echo "       Run this script without --account to list available accounts." >&2
      exit 1
    fi
    echo "(Resolved display name '${ACCOUNT}' → API name '${RESOLVED}')"
    ACCOUNT="$RESOLVED"
  fi
  echo
  echo "== Billing profiles in ${ACCOUNT} =="
  az rest --method get --url "${BASE}/billingAccounts/${ACCOUNT}/billingProfiles?api-version=${API}" -o json | pp

  echo
  echo "== Invoice sections (per profile) in ${ACCOUNT} =="
  PROFILES=$(az rest --method get --url "${BASE}/billingAccounts/${ACCOUNT}/billingProfiles?api-version=${API}" -o json \
    | python3 -c "import sys,json;print('\n'.join(x.get('name','') for x in json.load(sys.stdin).get('value',[])))")
  for bp in $PROFILES; do
    [[ -z "$bp" ]] && continue
    echo "  billingProfile: ${bp}"
    az rest --method get --url "${BASE}/billingAccounts/${ACCOUNT}/billingProfiles/${bp}/invoiceSections?api-version=${API}" -o json \
      | python3 -c "import sys,json;[print('    - invoiceSection:',x.get('name','?'),'  =>',x.get('properties',{}).get('displayName','')) for x in json.load(sys.stdin).get('value',[])]"
  done
  echo
  echo "Use these three names as billing_account_name / billing_profile_name / invoice_section_name."
  echo
  echo "NOTE: invoice section 'name' values are GUIDs — use the GUID (not the display name)"
  echo "      in billing scope paths, terraform.tfvars, and API calls."
fi
