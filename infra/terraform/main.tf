# Creates an Azure subscription under an MCA invoice section using the
# Microsoft.Subscription/aliases ARM API (the current, Learn-documented pattern).
#
# Why AzAPI and not azurerm_subscription?
#   Microsoft Learn documents the alias API + ARM schema explicitly, so AzAPI is
#   the lowest-risk path. An AzureRM alternative is provided, fully written, in
#   main.azurerm.tf.example — switch only after validating it against your
#   provider version. See docs/uncertainty-register.md (U5).
#
# The alias is tenant-scoped (parent_id = "/"). Reusing the same alias name is
# idempotent: it will not create a second subscription.
resource "azapi_resource" "subscription_alias" {
  type      = "Microsoft.Subscription/aliases@2021-10-01"
  name      = var.subscription_alias_name
  parent_id = "/"

  body = {
    properties = merge(
      {
        displayName  = var.subscription_display_name
        workload     = var.workload
        billingScope = local.billing_scope_id
      },
      length(local.additional_properties) > 0 ? { additionalProperties = local.additional_properties } : {}
    )
  }

  # Surface the created subscription GUID as an output.
  response_export_values = ["properties.subscriptionId"]
}
