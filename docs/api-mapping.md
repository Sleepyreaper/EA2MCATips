# API Mapping: EA Patterns to MCA Current Patterns

EA to MCA migration changes billing scopes, role expectations, and API surfaces. Existing automations should be assessed for enrollment, department, account, and invoice assumptions before cutover.

## EA to MCA / current-pattern mapping

| EA-era concept / pattern | MCA / current replacement pattern | Notes / migration impact |
|---|---|---|
| EA enrollment scope | MCA **billing account** and/or **billing profile** scope | Scope model changes materially ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)). |
| EA department | MCA **invoice section** | Invoice sections organize costs on the invoice ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-enterprise-operations)). |
| EA account / delegated subscription creation | **Azure subscription creator** on invoice section | Closest functional replacement ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-enterprise-operations)). |
| EA cost/balance integrations | **Cost Management + Microsoft.Billing APIs** | Learn says EA APIs are replaced by MCA-native APIs/integration ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)). |
| Enrollment-number-based BI connection | Power BI with **billing account ID / billing profile ID** | Scope and permission model changes ([Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)). |
| EA-style subscription create flows | **Microsoft.Subscription/aliases** + MCA billing scope | Alias API is the current ARM pattern ([Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/subscription/alias/create?view=rest-subscription-2021-10-01)). |
| EA invoice retrieval model | MCA **billing profile invoice** + Billing API invoice endpoints | Invoices are per billing profile and downloadable through Billing API ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-section-invoice)). |
| EA department/account reporting logic | Cost Management scopes at billing account / billing profile / invoice section | Queries and dashboards must be re-scoped ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/understand-work-scopes)). |

## Breaking changes for existing automations

### 1. Scope identifiers change

Existing scripts that assume enrollment number, department ID, or enrollment-account-style IDs need redesign around billing account ID, billing profile ID, and invoice section ID ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).

### 2. Permission model changes

Automation that previously relied on EA admin, EA account owner, or Azure subscription RBAC alone may fail because MCA billing operations require billing roles on billing scopes. Subscription creation especially needs **Azure subscription creator** on the invoice section or broader billing contributor/owner roles ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)).

### 3. Invoice grouping changes

Invoices are no longer treated purely in EA enrollment terms. MCA invoices are per billing profile, and invoice sections appear within those invoices. Reconciliation logic that assumes one invoice per enrollment or department-specific invoice behavior must be revisited ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).

### 4. Cost dashboards must be re-scoped

Dashboards, saved queries, or exports keyed to EA concepts must be rebuilt for MCA scopes. Cost Management supports MCA, but access and reporting dimensions differ ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).

### 5. Power BI connector permissions may surprise customers

Power BI’s direct MCA connector currently requires **Contributor or greater** on an MCA billing account/profile according to Learn. That can break least-privilege assumptions if teams expected reader access to be sufficient ([Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)).

### 6. Partial first invoice after migration

Finance automation must expect final EA invoicing until the migration date, the first MCA invoice on the fifth day of the following month, and possible partial first-period charges ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-understand-your-invoice)).

### 7. Legacy preview API assumptions may fail

Learn notes that permissions differ between the legacy API and the latest API for MCA subscription creation. A principal that worked with older preview flows may need updated delegation ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)).

## Current API surfaces to assess

- **Microsoft.Billing** for billing accounts, billing profiles, invoice sections, invoices, permissions, and role assignments ([Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/billing/billing-accounts?view=rest-billing-2024-04-01)).
- **Cost Management** for cost queries, exports, budgets, and reporting pipelines ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).
- **Microsoft.Subscription/aliases** for programmatic subscription creation ([Microsoft Learn](https://learn.microsoft.com/en-us/rest/api/subscription/alias/create?view=rest-subscription-2021-10-01)).
