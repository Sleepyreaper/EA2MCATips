#!/usr/bin/env bash
# Diagnose YOUR effective MCA billing access at a scope BEFORE you try to set up
# subscription automation. Read-only. Answers the two questions that matter:
#   1. Can you CREATE subscriptions under the invoice section?
#   2. Can you ASSIGN billing roles (i.e. delegate to a service principal)?
#
# This is the exact check to run before scripts/assign_billing_role.sh — if (2) is
# NO, the role grant will fail with AuthorizationFailed no matter how many times
# you retry, and a billing OWNER must grant the role (or grant you ownership).
#
# Auth: az login first.
#
# Usage:
#   scripts/check_billing_access.sh \
#     --billing-account "<BA>" --billing-profile "<BP>" --invoice-section "<IS>"
set -euo pipefail

API="${BILLING_API_VERSION:-2024-04-01}"
BILLING_PROFILE=""; INVOICE_SECTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --billing-account) BILLING_ACCOUNT="$2"; shift 2;;
    --billing-profile) BILLING_PROFILE="$2"; shift 2;;
    --invoice-section) INVOICE_SECTION="$2"; shift 2;;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
    *) echo "Unknown argument: $1" >&2; exit 1;;
  esac
done
: "${BILLING_ACCOUNT:?--billing-account required}"
command -v az >/dev/null || { echo "Azure CLI (az) not found. Run 'az login'." >&2; exit 1; }

ME=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "?")
MENAME=$(az account show --query user.name -o tsv 2>/dev/null || echo "?")
echo "Signed in as : ${MENAME} (object id ${ME})"
echo "Billing acct : ${BILLING_ACCOUNT}"
echo

echo "== Q1: Which invoice sections can you CREATE subscriptions under? =="
az rest --method post \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/${BILLING_ACCOUNT}/listInvoiceSectionsWithCreateSubscriptionPermission?api-version=${API}" \
  -o json 2>/dev/null | python3 -c "
import sys, json
try: d=json.load(sys.stdin)
except Exception: print('  (could not read - check access)'); sys.exit()
vals=d.get('value',[])
if not vals: print('  NONE - you cannot create subscriptions on this account.')
for v in vals:
    p=v.get('properties',v)
    print('  -', p.get('invoiceSectionDisplayName'), '|', (p.get('invoiceSectionId','') or '').split('/')[-1])
" 2>&1

echo
echo "== Q2: Can you ASSIGN billing roles (delegate to a service principal)? =="
SCOPE="/providers/Microsoft.Billing/billingAccounts/${BILLING_ACCOUNT}"
LABEL="billing account"
if [[ -n "$INVOICE_SECTION" ]]; then
  : "${BILLING_PROFILE:?--billing-profile required with --invoice-section}"
  SCOPE="${SCOPE}/billingProfiles/${BILLING_PROFILE}/invoiceSections/${INVOICE_SECTION}"; LABEL="invoice section"
elif [[ -n "$BILLING_PROFILE" ]]; then
  SCOPE="${SCOPE}/billingProfiles/${BILLING_PROFILE}"; LABEL="billing profile"
fi
echo "  Scope: ${LABEL}"
az rest --method get --url "https://management.azure.com${SCOPE}/billingRoleDefinitions?api-version=${API}" -o json 2>/dev/null \
  | python3 -c "
import sys, json
try: defs=json.load(sys.stdin).get('value',[])
except Exception: defs=[]
# Roles that include role-assignment write = ability to delegate
OWNER_HINTS=('owner',)
owner_roles=[r for r in defs if any(h in (r.get('properties',{}).get('roleName','') or '').lower() for h in OWNER_HINTS)]
print('  Owner-tier roles defined here:', ', '.join(sorted(r['properties']['roleName'] for r in owner_roles)) or '(none)')
print('  NOTE: to ASSIGN a role at this scope you must HOLD one of the owner roles')
print('        (Invoice section owner / Billing profile owner / Billing account owner)')
print('        WITH effective manage-access. A non-owner (e.g. subscription creator)')
print('        cannot delegate, and CANNOT self-grant ownership.')
"
echo
echo "== Your billing role assignments on this account =="
az rest --method get --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/${BILLING_ACCOUNT}/billingRoleAssignments?api-version=${API}" -o json 2>/dev/null \
  | ME="$ME" python3 -c "
import sys, json, os
me=os.environ.get('ME','')
try: vals=json.load(sys.stdin).get('value',[])
except Exception: vals=[]
mine=[a for a in vals if a.get('properties',{}).get('principalId')==me]
if not mine: print('  (no direct assignments found for you at account scope)')
for a in mine:
    p=a.get('properties',{})
    print('  roleDefinition:', (p.get('roleDefinitionId','') or '').split('/')[-1], '(', p.get('roleDefinitionName','') or 'name n/a', ')')
"
echo
echo "Interpretation:"
echo "  - Q1 lists sections you can CREATE in (create_subscription.sh / terraform work there)."
echo "  - For Q2: if assign_billing_role.sh returns 403 'billingRoleAssignments/write',"
echo "    you are NOT an effective owner at that scope -> a billing OWNER must grant the"
echo "    SP the role, or grant YOU 'Invoice section owner' first."
