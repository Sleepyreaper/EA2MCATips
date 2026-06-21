variable "tenant_id" {
  type        = string
  default     = ""
  description = "Entra ID tenant GUID. Optional — inherited from az login / ARM_TENANT_ID when blank."
}

variable "billing_account_name" {
  type        = string
  description = "MCA billing account name (the segment after billingAccounts/ in the resource ID, e.g. 'abcd1234-....:xxxx-...._2019-05-31')."
}

variable "billing_profile_name" {
  type        = string
  description = "MCA billing profile name (the segment after billingProfiles/ in the resource ID)."
}

variable "invoice_section_name" {
  type        = string
  description = "MCA invoice section name (the segment after invoiceSections/). The subscription is billed here and the SP needs 'Azure subscription creator' on this scope."
}

variable "subscription_alias_name" {
  type        = string
  description = "Stable alias name for the subscription request (idempotency key). Reusing the same alias will not create a duplicate subscription."

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]{1,63}$", var.subscription_alias_name))
    error_message = "subscription_alias_name must be 1-63 chars: letters, numbers, '.', '_' or '-'."
  }
}

variable "subscription_display_name" {
  type        = string
  description = "Friendly display name for the new subscription as it appears in the portal."
}

variable "workload" {
  type        = string
  default     = "Production"
  description = "Subscription workload type: 'Production' or 'DevTest'."

  validation {
    condition     = contains(["Production", "DevTest"], var.workload)
    error_message = "workload must be either 'Production' or 'DevTest'."
  }
}

variable "management_group_id" {
  type        = string
  default     = ""
  description = "Optional management group ID to place the new subscription under (e.g. '/providers/Microsoft.Management/managementGroups/mg-landingzones')."
}

variable "subscription_owner_id" {
  type        = string
  default     = ""
  description = "Optional principal (object) ID to grant subscription Owner on the new subscription."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Optional tags to apply to the new subscription."
}
