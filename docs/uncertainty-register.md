# Uncertainty Register

This register preserves evidence gaps from the research. Treat these as explicit customer validation points rather than assumptions.

## U1. Exact per-role permission granularity is not fully enumerated in one clean Learn table

Microsoft Learn gives role names and high-level descriptions, but not always a single definitive permission-by-action matrix for every operation across portal, API, Cost Management, and invoice download. Least-privilege recommendations are supportable, but some are derived by combining role descriptions with task-specific docs ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)).

**Recommended stance:** Use the smallest role supported by the docs, then validate the exact task in the customer tenant before broad rollout.

## U2. Invoice viewer least privilege: Invoice manager vs Billing profile reader

For viewing/downloading invoice artifacts, Learn says MCA users can be billing profile Owner, Contributor, Reader, or Invoice manager to view billing information, while role docs describe Invoice manager specifically around invoices. Invoice manager is recommended as least privilege for invoice-only needs, but Learn does not present a formal “minimum exact role for invoice PDF download” statement in a single canonical sentence ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/download-azure-invoice-daily-usage-date)).

**Recommended stance:** Start with Invoice manager for invoice-only users; test portal and API download behavior in the customer tenant.

## U3. Reports / Cost Analysis permissions are split between billing roles and Azure RBAC docs

Learn spreads cost visibility across billing scopes, Azure scopes, and Cost Management access docs. This makes “exact least privilege for every report flavor” harder than it should be. For billing-scope reporting, reader at the smallest billing scope is the cleanest answer; for subscription/resource reporting, Azure RBAC can also matter ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/assign-access-acm-data)).

**Recommended stance:** Test each report surface separately and document whether the access path is billing-scope, Azure-scope, or both.

## U4. Power BI connector permission seems stricter than many teams expect

Current Learn says **Contributor or greater** is needed for MCA billing account/profile connection in Power BI Desktop. That may conflict with customer assumptions or older anecdotal behavior. Treat Learn as source of truth unless tested otherwise in a tenant ([Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)).

**Recommended stance:** Validate the connector with the customer’s intended persona. If Contributor is too broad, use Cost Management exports as the reporting data source.

## U5. Terraform support needs careful wording — **AzAPI path validated ✅**

Microsoft Learn clearly documents the ARM/AzAPI schema for `Microsoft.Subscription/aliases`, the REST alias creation pattern, and MCA billing-scope discovery. The **AzAPI path is live-validated**: `azapi_resource` targeting `Microsoft.Subscription/aliases@2021-10-01` with a correct `billingScope` reaches `provisioningState: Succeeded` against a real MCA-E billing account. The AzureRM-native path (`azurerm_subscription`) has not been separately tested — prefer the AzAPI-backed approach.

**Validated stance:** Use AzAPI / alias API path. Confirmed working end-to-end (Terraform plan + REST API) against MCA-E account type.

## U6. Billing REST API versions vary across Learn pages

Some newer Billing REST references use `2024-04-01`, while operational examples still cite `2020-05-01` or `2021-10-01`. This is normal in Learn, but it means the implementation should standardize on the latest supported stable examples documented for each specific operation, not mix-and-match casually ([Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/billing/billing-accounts?view=rest-billing-2024-04-01)).

**Recommended stance:** Choose API versions per operation from the operation's own Learn page and document the selected version in implementation code/comments. For billing account/profile/invoice section discovery, `2024-04-01` is confirmed working.

## U7. Invoice section display names ≠ API names — **confirmed**

Invoice sections have a friendly **display name** (e.g. "Accenture1") visible in the portal and in `properties.displayName`, and a separate **API name** (a GUID, e.g. `eaed06d4-ac9c-...`) used in all REST paths and Terraform config. Using the display name in a billing scope path produces a `404` or `InvalidBillingAccountName` error. Always retrieve the actual `name` field from the invoice sections API or from `scripts/discover_billing_scopes.sh` output.

**Validated stance:** Confirmed on MCA-E account. Always use the GUID `name` in `invoice_section_name`.

## U8. Subscription cancellation requires Azure RBAC Owner, not billing role — **confirmed**

`POST /subscriptions/{id}/providers/Microsoft.Subscription/cancel` is an **Azure RBAC** operation on the subscription itself, not a billing operation. A principal with only "Azure subscription creator" (a billing role) receives `404`/`AuthorizationFailed` when attempting to cancel. To cancel a test subscription, first grant **Owner** on the subscription (`az role assignment create --role Owner ...`) and then call the cancel endpoint.

**Validated stance:** Confirmed. Build cleanup scripts/runbooks to include an Owner assignment step before attempting subscription cancellation.
