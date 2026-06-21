locals {
  # MCA billing scope for subscription creation = the invoice section resource ID.
  billing_scope_id = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_name}/billingProfiles/${var.billing_profile_name}/invoiceSections/${var.invoice_section_name}"

  # additionalProperties is only sent when at least one optional field is set.
  additional_properties = merge(
    var.management_group_id != "" ? { managementGroupId = var.management_group_id } : {},
    var.subscription_owner_id != "" ? { subscriptionOwnerId = var.subscription_owner_id } : {},
    length(var.tags) > 0 ? { tags = var.tags } : {},
  )
}
