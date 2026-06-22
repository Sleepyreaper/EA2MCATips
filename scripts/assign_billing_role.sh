#!/usr/bin/env bash
# Assign ANY MCA billing role (least privilege) to a principal at the smallest
# scope you specify. Resolves the role BY NAME against the scope's billing role
# definitions — no hardcoded role GUIDs. Parameterized; no secrets in the file.
#
# Scope is the deepest of the IDs you pass:
#   --invoice-section  -> invoice section scope
#   --billing-profile  -> billing profile scope (omit --invoice-section)
#   --billing-account  -> billing account scope (omit the other two)
#
# Auth: `az login` as someone who can manage billing role assignments at that scope
# (e.g. billing account owner / billing profile owner).
#
# Mutating: defaults to --dry-run. Pass --apply to actually create the assignment.
#
# Usage:
#   scripts/assign_billing_role.sh \
#     --billing-account "<BA>" --billing-profile "<BP>" [--invoice-section "<IS>"] \
#     --role "Invoice manager" --principal-id "<OBJECT_ID>" [--apply]
#
# For a SERVICE PRINCIPAL, --principal-id is the service principal (enterprise
# application) OBJECT ID, and you may also need --principal-tenant-id <TENANT_GUID>.
#
# Common roles: "Billing account owner|contributor|reader",
#   "Billing profile owner|contributor|reader", "Invoice manager",
#   "Invoice section owner|contributor|reader", "Azure subscription creator".
set -euo pipefail

API="${BILLING_API_VERSION:-2024-04-01}"
APPLY="false"
INVOICE_SECTION=""
BILLING_PROFILE=""
PRINCIPAL_TENANT_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --billing-account)     BILLING_ACCOUNT="$2"; shift 2;;
    --billing-profile)     BILLING_PROFILE="$2"; shift 2;;
    --invoice-section)     INVOICE_SECTION="$2"; shift 2;;
    --role)                ROLE_NAME="$2"; shift 2;;
    --principal-id)        PRINCIPAL_ID="$2"; shift 2;;
    --principal-tenant-id) PRINCIPAL_TENANT_ID="$2"; shift 2;;
    --apply)               APPLY="true"; shift;;
    -h|--help)             sed -n '2,29p' "$0"; exit 0;;
    *) echo "Unknown argument: $1" >&2; exit 1;;
  esac
done

: "${BILLING_ACCOUNT:?--billing-account required}"
: "${ROLE_NAME:?--role required}"
: "${PRINCIPAL_ID:?--principal-id (object ID) required}"
command -v az >/dev/null || { echo "Azure CLI (az) not found. Run 'az login'." >&2; exit 1; }

BASE="/providers/Microsoft.Billing/billingAccounts/${BILLING_ACCOUNT}"
if [[ -n "$INVOICE_SECTION" ]]; then
  : "${BILLING_PROFILE:?--billing-profile required when --invoice-section is set}"
  SCOPE="${BASE}/billingProfiles/${BILLING_PROFILE}/invoiceSections/${INVOICE_SECTION}"
elif [[ -n "$BILLING_PROFILE" ]]; then
  SCOPE="${BASE}/billingProfiles/${BILLING_PROFILE}"
else
  SCOPE="${BASE}"
fi

echo "Scope     : ${SCOPE}"
echo "Role      : ${ROLE_NAME}"
echo "Principal : ${PRINCIPAL_ID}"

echo "Resolving role definition by name..."
ROLE_DEF_ID=$(az rest --method get \
  --url "https://management.azure.com${SCOPE}/billingRoleDefinitions?api-version=${API}" -o json \
  | ROLE_NAME="$ROLE_NAME" python3 -c "
import sys, json, os
want = os.environ['ROLE_NAME'].strip().lower()
data = json.load(sys.stdin).get('value', [])
for r in data:
    if (r.get('properties', {}).get('roleName', '') or '').strip().lower() == want:
        print(r.get('id') or r.get('name')); break
")

if [[ -z "${ROLE_DEF_ID:-}" ]]; then
  echo "Could not find a billing role named '${ROLE_NAME}' at this scope." >&2
  echo "List available roles with:" >&2
  echo "  az rest --method get --url \"https://management.azure.com${SCOPE}/billingRoleDefinitions?api-version=${API}\" --query \"value[].properties.roleName\"" >&2
  exit 1
fi
echo "roleDefinitionId: ${ROLE_DEF_ID}"

ASSIGNMENT_NAME=$(uuidgen 2>/dev/null || python3 -c "import uuid;print(uuid.uuid4())")
ASSIGN_URL="https://management.azure.com${SCOPE}/billingRoleAssignments/${ASSIGNMENT_NAME}?api-version=${API}"
BODY=$(PRINCIPAL_ID="$PRINCIPAL_ID" ROLE_DEF_ID="$ROLE_DEF_ID" PRINCIPAL_TENANT_ID="$PRINCIPAL_TENANT_ID" python3 -c "
import os, json
props = {'principalId': os.environ['PRINCIPAL_ID'], 'roleDefinitionId': os.environ['ROLE_DEF_ID']}
if os.environ.get('PRINCIPAL_TENANT_ID'):
    props['principalTenantId'] = os.environ['PRINCIPAL_TENANT_ID']
print(json.dumps({'properties': props}, indent=2))
")
echo "Request body:"; echo "${BODY}"

if [[ "$APPLY" != "true" ]]; then
  echo; echo "[dry-run] Pass --apply to create this billing role assignment."
  exit 0
fi

echo; echo "Creating billing role assignment..."
az rest --method put --url "${ASSIGN_URL}" \
  --headers "Content-Type=application/json" --body "${BODY}" -o json >/dev/null
echo "Done. '${ROLE_NAME}' granted to ${PRINCIPAL_ID} at the scope above."
