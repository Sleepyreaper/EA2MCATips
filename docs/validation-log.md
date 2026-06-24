# Validation Log

Sanitized evidence of live-tenant tests. No real tenant IDs, subscription IDs,
billing account IDs, SP credentials, object IDs, or invoice numbers are recorded here.
All identifiers are replaced with `<sanitized>` or a descriptive label.

---

## 2026-06-23 — End-to-end SP subscription creation (MCA-E)

**Environment:** MCA-E billing account (`agreementType=MicrosoftCustomerAgreement`,
`accountType=Enterprise`), single billing profile, single invoice section.

**Scope of test:** Create a service principal via the portal, confirm its billing role,
create a subscription via the REST API, verify provisioning, clean up.

### Steps completed

| # | Step | Result |
|---|---|---|
| 1 | Created app registration + SP via Entra portal | ✅ |
| 2 | Added client secret credential | ✅ |
| 3 | Verified SP object ID via **Enterprise applications** in portal | ✅ |
| 4 | Confirmed SP already held **Azure subscription creator** on target invoice section | ✅ |
| 5 | Discovered billing account API name via `az rest` (display name ≠ API name — see U7) | ✅ |
| 6 | Discovered invoice section GUID via profiles/invoiceSections API (display name ≠ GUID — see U7) | ✅ |
| 7 | Wired all IDs into `terraform.tfvars` (gitignored) | ✅ |
| 8 | `terraform plan` — validated clean, 1 resource to add | ✅ |
| 9 | REST API: `PUT /providers/Microsoft.Subscription/aliases/<alias>?api-version=2021-10-01` | ✅ `Accepted` |
| 10 | Polled alias — `provisioningState` reached `Succeeded` in ~5 seconds | ✅ |
| 11 | Alias deleted: `DELETE /providers/Microsoft.Subscription/aliases/<alias>` | ✅ |
| 12 | Assigned Owner RBAC on new subscription (required for cancel — see U8) | ✅ |
| 13 | Subscription cancelled: `POST /subscriptions/<id>/providers/Microsoft.Subscription/cancel` | ✅ |

### Key findings

1. **Invoice section display names are GUIDs at the API level.** The friendly name
   shown in the portal is `properties.displayName`; the value required in billing scope
   paths is `name` (a GUID). Using the display name produces a `404` or
   `InvalidBillingAccountName`. See [U7](./uncertainty-register.md#u7-invoice-section-display-names--api-names----confirmed).

2. **`discover_billing_scopes.sh` required billing account API name, not display
   name.** Fixed: the script now resolves display names to API names automatically when
   the `--account` argument contains spaces. Also upgraded default API version to
   `2024-04-01`.

3. **Subscription cancel is an Azure RBAC operation, not a billing operation.**
   A principal with only the billing role (`Azure subscription creator`) cannot cancel
   via the API — it receives `404`. Requires Owner RBAC on the subscription itself.
   See [U8](./uncertainty-register.md#u8-subscription-cancellation-requires-azure-rbac-owner-not-billing-role----confirmed).

4. **AzAPI Terraform path confirmed working** end-to-end against a real MCA-E
   billing account. `terraform plan` validates correctly; `terraform apply` path is
   ready (use the same billing scope as the validated API call).
   See [U5](./uncertainty-register.md#u5-terraform-support-needs-careful-wording----azapi-path-validated-).

5. **Subscription creator role definition GUID on MCA-E** is
   `30000000-aaaa-bbbb-cccc-100000000006` (not the `a0bcee42-...` GUID cited in some
   documentation). The `assign_billing_role.sh` script resolves by name, not GUID, so
   this is handled automatically.

### Billing role assignment approach (MCA-E)

Billing role was assigned via the **Azure portal** (Cost Management + Billing →
invoice section → Access control (IAM) → Add) rather than the CLI, because the
MCA-E `billingRoleAssignments/write` restriction described in the
[MCA-E note](./service-principal-automation-101.md#mca-e-ea-migrated-accounts-portal-vs-api)
applies. The portal path worked without issue.

---

*All sensitive values (tenant IDs, billing account IDs, subscription IDs, SP
credentials, object IDs) are stored only in gitignored local files and were not
committed to this repository.*
