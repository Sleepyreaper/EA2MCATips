#!/usr/bin/env bash
# Grant LEAST-PRIVILEGE "Azure subscription creator" on a specific MCA invoice
# section to a principal (service principal or user object ID). This is the
# narrowest billing role that can create subscriptions under that section.
#
# Auth: run `az login` as someone who can manage billing role assignments on the
# invoice section (e.g. invoice section owner / billing profile owner).
#
# Mutating: defaults to --dry-run. Pass --apply to actually create the assignment.
#
# Usage:
#   scripts/assign_subscription_creator_role.sh \
#     --billing-account "<BA>" --billing-profile "<BP>" --invoice-section "<IS>" \
#     --principal-id "<OBJECT_ID>" [--apply]
set -euo pipefail

API="${BILLING_API_VERSION:-2024-04-01}"
# Well-known billing role definition GUID for "Azure subscription creator".
# Verified at runtime against the scope's billingRoleDefinitions list.
SUB_CREATOR_ROLE_GUID="a0bcee42-bf30-4d1b-926a-48d21664ef71"
APPLY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --billing-account) BILLING_ACCOUNT="$2"; shift 2;;
    --billing-profile) BILLING_PROFILE="$2"; shift 2;;
    --invoice-section) INVOICE_SECTION="$2"; shift 2;;
    --principal-id)    PRINCIPAL_ID="$2"; shift 2;;
    --apply)           APPLY="true"; shift;;
    -h|--help)         sed -n '2,18p' "$0"; exit 0;;
    *) echo "Unknown argument: $1" >&2; exit 1;;
  esac
done

: "${BILLING_ACCOUNT:?--billing-account required}"
: "${BILLING_PROFILE:?--billing-profile required}"
: "${INVOICE_SECTION:?--invoice-section required}"
: "${PRINCIPAL_ID:?--principal-id (object ID) required}"
command -v az >/dev/null || { echo "Azure CLI (az) not found. Run 'az login'." >&2; exit 1; }

SCOPE="/providers/Microsoft.Billing/billingAccounts/${BILLING_ACCOUNT}/billingProfiles/${BILLING_PROFILE}/invoiceSections/${INVOICE_SECTION}"
ROLE_DEF_ID="${SCOPE}/billingRoleDefinitions/${SUB_CREATOR_ROLE_GUID}"
ASSIGNMENT_NAME=$(uuidgen 2>/dev/null || python3 -c "import uuid;print(uuid.uuid4())")
ASSIGN_URL="https://management.azure.com${SCOPE}/billingRoleAssignments/${ASSIGNMENT_NAME}?api-version=${API}"

BODY=$(cat <<JSON
{
  "properties": {
    "principalId": "${PRINCIPAL_ID}",
    "roleDefinitionId": "${ROLE_DEF_ID}"
  }
}
JSON
)

echo "Scope        : ${SCOPE}"
echo "Role         : Azure subscription creator (${SUB_CREATOR_ROLE_GUID})"
echo "Principal    : ${PRINCIPAL_ID}"
echo "Request body :"; echo "${BODY}"

if [[ "$APPLY" != "true" ]]; then
  echo; echo "[dry-run] Pass --apply to create this billing role assignment."
  exit 0
fi

echo; echo "Creating billing role assignment..."
az rest --method put --url "${ASSIGN_URL}" \
  --headers "Content-Type=application/json" --body "${BODY}" -o json >/dev/null
echo "Done. ${PRINCIPAL_ID} now has Azure subscription creator on the invoice section."
