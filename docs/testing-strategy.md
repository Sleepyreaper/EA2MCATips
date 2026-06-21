# Testing Strategy

Use this checklist to validate the handoff safely. Start offline with documentation and static artifacts. Treat real Azure execution as a separate customer-approved activity using least privilege, sanitized evidence capture, and human review before create/write actions.

## Stage 1 — Offline and demo validation

- [ ] Review the MCA hierarchy and role model in the docs before touching a tenant.
- [ ] Confirm all customer-specific values are represented as blanks/placeholders, not committed real IDs or secrets.
- [ ] If reviewing the dashboard, serve it through local HTTP rather than opening `index.html` directly from `file://` so browser fetch behavior is realistic.
- [ ] Verify sample/demo data is clearly marked offline/demo and contains no real tenant IDs, billing IDs, invoice numbers, subscription IDs, tokens, or secrets.
- [ ] If Terraform exists in the repo, run only formatting and validation first; do not deploy during offline review.

## Stage 2 — RBAC role tests for billing profiles, invoices, and reports

For each test persona, assign only the target least-privilege role at the smallest scope, then verify both allowed and denied surfaces.

### Finance / invoice consumer

- [ ] Assign **Invoice manager** on the target billing profile.
- [ ] Verify the user can view billing information and retrieve/download invoices for that billing profile ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/download-azure-invoice-daily-usage-date)).
- [ ] Verify the user cannot administer unrelated billing profiles or invoice sections.
- [ ] Record whether Billing profile reader is required in the customer tenant for any invoice surface; keep this evidence tied to the uncertainty register.

### Billing profile reader

- [ ] Assign **Billing profile reader** on the target billing profile.
- [ ] Verify read-only access to the billing profile context and costs/invoices in that profile ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)).
- [ ] Verify the user cannot manage permissions or create subscriptions.

### Department/project cost viewer

- [ ] Assign **Invoice section reader** on the target invoice section.
- [ ] Verify cost visibility for the assigned invoice section.
- [ ] Verify no visibility into unrelated invoice sections unless inherited roles apply.
- [ ] Remember that Cost Management access can involve both billing scopes and Azure scopes ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/assign-access-acm-data)).

### Central FinOps

- [ ] Assign **Billing profile reader** if cross-section visibility within one billing profile is required.
- [ ] Assign **Billing account reader** only if cross-profile visibility is required.
- [ ] Confirm inherited billing account permissions are acceptable, because inherited permissions cannot be removed lower down ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)).

### Automation service principal

- [ ] Use a dedicated test service principal; do not reuse broad admin identities.
- [ ] Assign **Azure subscription creator** on only the approved invoice section for subscription creation testing ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)).
- [ ] Grant only the Azure RBAC needed to read verification outputs, if required.
- [ ] Verify the service principal cannot create subscriptions under unapproved invoice sections.

## Stage 3 — API and dashboard tests

### Billing scope discovery

- [ ] List billing accounts available to the test principal.
- [ ] Enumerate billing profiles and invoice sections the principal can access.
- [ ] Confirm scope ID shapes match expected ARM forms:

```text
/providers/Microsoft.Billing/billingAccounts/{billingAccountName}
/providers/Microsoft.Billing/billingAccounts/{billingAccountName}/billingProfiles/{billingProfileName}
/providers/Microsoft.Billing/billingAccounts/{billingAccountName}/billingProfiles/{billingProfileName}/invoiceSections/{invoiceSectionName}
```

These are the MCA billing-scope patterns used in subscription-creation guidance ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)).

### Cost Management queries and exports

- [ ] Run Cost Management queries only against approved billing account/profile/invoice section scopes.
- [ ] Verify old EA enrollment/department/account query assumptions are removed ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).
- [ ] If exports are tested, use a customer-approved test storage account and ensure export output is not committed to the repo ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports)).

### Power BI connector

- [ ] Confirm whether Power BI direct connector testing is in scope.
- [ ] If in scope, test with the documented MCA billing account or billing profile ID workflow.
- [ ] Verify the user has **Contributor or greater** on the MCA billing account/profile, as current Learn requires ([Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)).
- [ ] If direct connector testing is not approved or permissions are too broad, validate an export-based reporting path instead.

### Dashboard status evidence

- [ ] Update any dashboard status artifact only with sanitized results: success/failure, timestamp, sanitized scope label, sanitized alias/display label, error class/message with secrets removed, and remediation step.
- [ ] Do not paste raw tokens, request payloads, full customer identifiers, invoice numbers, or production subscription IDs into repo files.

## Stage 4 — Controlled real-tenant validation

- [ ] Confirm the customer approved the test tenant, billing account, billing profile, and invoice section.
- [ ] Confirm live values are supplied externally through environment variables, a secure local variable file excluded from git, or an approved secret store.
- [ ] Confirm no shell tracing is enabled during secret handling.
- [ ] Run static checks first, such as formatting and validation, before any live action.
- [ ] Authenticate deliberately with the dedicated automation identity.
- [ ] Require human review of target scope, subscription display name/alias, principal, expected charge destination, and cleanup plan.
- [ ] Only then run the live create step.
- [ ] Confirm the billing scope is accepted, alias/subscription creation succeeds, and the resulting subscription lands under the expected billing hierarchy ([Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/subscription/alias/create?view=rest-subscription-2021-10-01)).
- [ ] Follow the customer-approved cleanup/rollback plan for disposable test subscriptions.
