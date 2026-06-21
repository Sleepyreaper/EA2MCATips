output "subscription_id" {
  description = "GUID of the created (or existing) subscription."
  value       = try(azapi_resource.subscription_alias.output.properties.subscriptionId, null)
}

output "subscription_alias_id" {
  description = "Resource ID of the subscription alias request."
  value       = azapi_resource.subscription_alias.id
}

output "billing_scope_id" {
  description = "The MCA invoice section billing scope the subscription was billed to."
  value       = local.billing_scope_id
}
