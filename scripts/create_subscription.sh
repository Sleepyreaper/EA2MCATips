#!/usr/bin/env bash
# Create an Azure subscription under an MCA invoice section via the
# Microsoft.Subscription/aliases REST API. Parameterized; no secrets in the file.
#
# Auth: run `az login` first (user or service principal). The principal needs
# "Azure subscription creator" on the target invoice section (least privilege).
#
# Usage:
#   scripts/create_subscription.sh \
#     --billing-account "<BA_NAME>" \
#     --billing-profile "<BP_NAME>" \
#     --invoice-section "<IS_NAME>" \
#     --alias "ea2mca-test-sub-001" \
#     --display-name "EA2MCA Test Subscription 01" \
#     --workload DevTest
#
# Values can also come from env: BILLING_ACCOUNT, BILLING_PROFILE,
# INVOICE_SECTION, ALIAS, DISPLAY_NAME, WORKLOAD.
#
# Flags:
#   --dry-run   Print the request body and exit without calling Azure.
#   -h|--help   Show this help.
set -euo pipefail

API_VERSION="2021-10-01"
WORKLOAD="${WORKLOAD:-Production}"
DRY_RUN="false"

usage() { sed -n '2,30p' "$0"; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --billing-account) BILLING_ACCOUNT="$2"; shift 2;;
    --billing-profile) BILLING_PROFILE="$2"; shift 2;;
    --invoice-section) INVOICE_SECTION="$2"; shift 2;;
    --alias)           ALIAS="$2"; shift 2;;
    --display-name)    DISPLAY_NAME="$2"; shift 2;;
    --workload)        WORKLOAD="$2"; shift 2;;
    --dry-run)         DRY_RUN="true"; shift;;
    -h|--help)         usage 0;;
    *) echo "Unknown argument: $1" >&2; usage 1;;
  esac
done

: "${BILLING_ACCOUNT:?--billing-account or BILLING_ACCOUNT required}"
: "${BILLING_PROFILE:?--billing-profile or BILLING_PROFILE required}"
: "${INVOICE_SECTION:?--invoice-section or INVOICE_SECTION required}"
: "${ALIAS:?--alias or ALIAS required}"
: "${DISPLAY_NAME:?--display-name or DISPLAY_NAME required}"

case "$WORKLOAD" in Production|DevTest) ;; *) echo "workload must be Production or DevTest" >&2; exit 1;; esac
command -v az >/dev/null || { echo "Azure CLI (az) not found. Install it and run 'az login'." >&2; exit 1; }

BILLING_SCOPE="/providers/Microsoft.Billing/billingAccounts/${BILLING_ACCOUNT}/billingProfiles/${BILLING_PROFILE}/invoiceSections/${INVOICE_SECTION}"
ALIAS_URL="https://management.azure.com/providers/Microsoft.Subscription/aliases/${ALIAS}?api-version=${API_VERSION}"

BODY=$(cat <<JSON
{
  "properties": {
    "displayName": "${DISPLAY_NAME}",
    "workload": "${WORKLOAD}",
    "billingScope": "${BILLING_SCOPE}"
  }
}
JSON
)

echo "Billing scope : ${BILLING_SCOPE}"
echo "Alias         : ${ALIAS}"
echo "Display name  : ${DISPLAY_NAME}"
echo "Workload      : ${WORKLOAD}"
echo "Request body  :"; echo "${BODY}"

if [[ "$DRY_RUN" == "true" ]]; then
  echo; echo "[dry-run] No request sent."
  exit 0
fi

echo; echo "Submitting subscription alias (PUT)..."
az rest --method put --url "${ALIAS_URL}" \
  --headers "Content-Type=application/json" \
  --body "${BODY}" >/dev/null

echo "Polling for provisioning to complete (up to ~5 min)..."
for i in $(seq 1 30); do
  RESP=$(az rest --method get --url "${ALIAS_URL}" -o json)
  STATE=$(printf '%s' "$RESP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('properties',{}).get('provisioningState',''))")
  SUB_ID=$(printf '%s' "$RESP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('properties',{}).get('subscriptionId','') or '')")
  echo "  [$i] provisioningState=${STATE:-unknown}"
  case "$STATE" in
    Succeeded) echo; echo "Subscription created."; echo "subscriptionId: ${SUB_ID}"; exit 0;;
    Failed)    echo "Subscription creation FAILED. Full response:" >&2; printf '%s\n' "$RESP" >&2; exit 1;;
  esac
  sleep 10
done

echo "Timed out waiting for provisioning. Check the alias status later:" >&2
echo "  az rest --method get --url \"${ALIAS_URL}\"" >&2
exit 1
