# Authentication is resolved from the environment — never hardcoded here.
# Use ONE of:
#   - Azure CLI:        az login   (developer / interactive)
#   - Service principal: ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID
#   - OIDC / federated:  ARM_CLIENT_ID / ARM_TENANT_ID / ARM_USE_OIDC=true
#
# The principal must hold a billing role that can create subscriptions on the
# target invoice section — least privilege is "Azure subscription creator" on
# that invoice section. See docs/subscription-automation.md.
provider "azapi" {
  tenant_id = var.tenant_id != "" ? var.tenant_id : null
}
