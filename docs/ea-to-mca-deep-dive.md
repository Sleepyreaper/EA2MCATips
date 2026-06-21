# EA to MCA Deep Dive

## Executive summary

- MCA replaces the EA enrollment, department, and account model with **billing account → billing profile → invoice section → subscription**. Billing profiles map most closely to invoice/payment grouping; invoice sections map most closely to cost segmentation such as departments, projects, or environments ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).
- Most EA-era cost and billing automations require redesign because scopes change. EA enrollment-based endpoints and concepts do not carry forward as-is; under MCA, automation typically targets billing account, billing profile, and invoice section scopes plus current ARM-based Billing and Cost Management APIs ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).
- Least privilege under MCA is more granular than EA, but some tasks require careful interpretation. For invoice viewing/downloading, the narrowest documented invoice-focused role is generally **Invoice manager** at the billing profile. For subscription creation, the least-privilege delegated role is **Azure subscription creator** on the invoice section ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)).
- Power BI still supports direct MCA and EA connections, but for MCA it uses billing account or billing profile scope IDs and currently requires **Contributor or greater** on those MCA scopes. Treat that as a migration consideration when customers expect reader-only BI access ([Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)).
- Terraform wording should stay conservative. Microsoft Learn clearly supports the subscription alias API and ARM/AzAPI schema path for `Microsoft.Subscription/aliases`; AzureRM-specific behavior should be validated against the target provider version before customer commitment ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/templates/microsoft.subscription/aliases)).

## MCA billing hierarchy

Under MCA:

- A **billing account** is the top billing container for the agreement. It manages invoices, payments, and overall cost tracking ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).
- A billing account contains one or more **billing profiles**. A billing profile manages the invoice and payment methods, and a monthly invoice is generated for each billing profile ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).
- Each billing profile contains one or more **invoice sections**. Invoice sections organize costs on the billing profile invoice, for example by department, project, or environment ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).
- **Subscriptions are billed to an invoice section**, and their charges roll up into the parent billing profile invoice. Learn states the billing profile invoice contains charges for Azure subscriptions from the previous month, and invoice sections appear on that invoice with their respective charges ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).

## EA to MCA conceptual mapping

| EA concept | Closest MCA operational equivalent | Notes |
|---|---|---|
| EA Enrollment | Billing profile | Closest operational equivalent for invoice management ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-enterprise-operations)). |
| EA Department | Invoice section | Closest MCA equivalent for organizing costs ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-enterprise-operations)). |
| EA Account / account-owner-like subscription creation delegation | Azure subscription creator on an invoice section | Closest MCA delegated creation capability ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-enterprise-operations)). |

## MCA billing roles and semantics

Current Microsoft Learn lists these MCA billing roles ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)):

- Billing account owner
- Billing account contributor
- Billing account reader
- Billing profile owner
- Billing profile contributor
- Billing profile reader
- Invoice manager
- Invoice section owner
- Invoice section contributor
- Invoice section reader
- Azure subscription creator

Learn also states that permissions at the billing account level inherit to child billing profiles and invoice sections, and inherited permissions cannot be removed lower down ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)).

High-level role semantics from Learn:

| Role pattern | Semantics |
|---|---|
| Owner | Manage everything at that scope. |
| Contributor | Manage everything except permissions at that scope. |
| Reader | Read-only at that scope. |
| Invoice manager | View and pay invoices for the billing profile. |
| Azure subscription creator | Create Azure subscriptions. |

These semantics are summarized from the MCA role documentation ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)).

## Authentication and scope differences

Microsoft Learn says migration from EA to MCA requires extra effort because of changes in the underlying billing subsystem, affecting cost-related APIs and integration patterns ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).

EA automation often targeted:

- enrollment-level constructs and APIs;
- department/account concepts;
- enrollment-scoped identifiers for billing and cost operations ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).

MCA automation targets ARM/Billing scopes such as:

```text
/providers/Microsoft.Billing/billingAccounts/{billingAccountName}
/providers/Microsoft.Billing/billingAccounts/{billingAccountName}/billingProfiles/{billingProfileName}
/providers/Microsoft.Billing/billingAccounts/{billingAccountName}/billingProfiles/{billingProfileName}/invoiceSections/{invoiceSectionName}
```

These shapes align with the MCA programmatic subscription-creation guidance ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)).

Important implication: for MCA, many operations are surfaced under Azure Resource Manager / `Microsoft.Billing` / `Microsoft.Subscription` APIs rather than older EA-specific surfaces ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)). The service principal or user must hold billing roles on billing scopes, not just Azure RBAC on subscriptions, for billing-scope operations such as invoice access and subscription creation ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)).

## Cost Management APIs under MCA

The migration article says MCA provides complete API availability through native Azure APIs, cost visibility across billing profiles, APIs for thresholds/notifications/exports, and combined views including Azure usage and Marketplace usage/purchases ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).

Relevant API families include:

- **Microsoft.Billing REST APIs** for billing accounts, billing profiles, invoice sections, invoices, billing permissions, and billing role assignments ([Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/billing/billing-accounts?view=rest-billing-2024-04-01)).
- **Cost Management APIs** for cost queries, exports, budgets, and related automation. Microsoft Learn positions these as the successor surface for cost operations under MCA ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).
- **Microsoft.Subscription/aliases** for programmatic subscription creation ([Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/subscription/alias/create?view=rest-subscription-2021-10-01)).

## Customer dashboard and portal changes

Microsoft Learn says moving from EA to MCA changes the billing experience in the Azure portal:

- Customers manage billing through **Cost Management + Billing** in the Azure portal.
- Instead of EA departments/accounts, customers use **billing profiles** and **invoice sections**.
- Invoices are digital and viewable/analyzable from Cost Management + Billing ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-setup-account)).

### Cost analysis and Cost Management

MCA users can view costs in Cost Management at billing account, billing profile, invoice section, and resource-management scopes where permitted ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/understand-work-scopes)).

The Power BI documentation supports both EA and direct MCA, but MCA uses manual scope selection with billing account ID and billing profile ID instead of an enrollment-number-style workflow ([Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)).

### Exports and reports

MCA customers can use Cost Management exports for recurring export of cost datasets to storage ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports)). For reporting pipelines that used older EA-specific extraction patterns, modernization usually means rebuilding around MCA billing scopes and current Cost Management APIs; that is an inference from the migration and exports documentation, not a single explicit migration sentence ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).

### Power BI connector implication

The connector supports direct MCA and EA. For MCA, current Learn says the user needs Contributor or greater on an MCA billing account or billing profile to connect. If unsupported agreement types are involved, Learn recommends Exports as an alternative data source ([Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)). This is operationally important because many customers expect a reader-level billing role to be enough for BI.

## Bottom-line CSA guidance

- Rebuild the customer mental model from **EA enrollment/department/account** to **MCA billing account/billing profile/invoice section/subscription** ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).
- Put finance users on billing profile invoice roles, not billing account roles, unless they truly need global visibility ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)).
- Put cost viewers on the smallest billing-scope reader role that meets the use case ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)).
- Put automation service principals for new subscriptions on **Azure subscription creator** at the invoice section, not owner/contributor at billing account ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)).
- Expect scope rewrites, permission rewrites, invoice-flow changes, and likely BI/reporting refactors ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).
