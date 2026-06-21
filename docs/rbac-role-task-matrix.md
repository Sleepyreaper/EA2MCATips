# RBAC Role-Task Matrix for MCA Billing Operations

This matrix separates MCA billing roles from Azure RBAC. Use the smallest MCA billing scope and narrowest documented role that satisfies the task. Billing account permissions inherit down to billing profiles and invoice sections, and inherited permissions cannot be removed lower in the hierarchy ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)).

## Least-privilege findings by task

| Task | Smallest scope | Least-privilege role | Evidence state | Why + Learn link |
|---|---|---|---|---|
| View billing profile | Billing profile | **Billing profile reader** | documented | Reader is read-only for everything on the billing profile; billing profiles manage invoice/payment context ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)). |
| View invoice | Billing profile | **Invoice manager** or **Billing profile reader** | partially_documented | Learn says MCA users can be billing profile Owner, Contributor, Reader, or Invoice manager to view billing information. Invoice manager is invoice-specific; Billing profile reader is broader read-only ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/download-azure-invoice-daily-usage-date)). |
| Download invoice | Billing profile | **Invoice manager** | partially_documented | Learn groups invoice access on billing profile roles and names Invoice manager for invoice operations. Invoice manager is the narrowest invoice-focused role; broader billing profile roles also work ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/download-azure-invoice-daily-usage-date)). |
| View billing-scope cost analysis / reports for one invoice section | Invoice section | **Invoice section reader** | partially_documented | Cost visibility spans billing roles and Azure RBAC. For billing-scope reporting, reader at the smallest billing scope is the cleanest answer ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/assign-access-acm-data)). |
| View billing-scope cost analysis / reports for one billing profile | Billing profile | **Billing profile reader** | partially_documented | Use the smallest billing scope that covers the reporting need. Billing profile reader covers costs/invoices within that profile ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)). |
| View all billing data for the whole MCA account | Billing account | **Billing account reader** | documented | Read-only at billing account scope, but broad because billing account permissions inherit to children ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)). |
| View a billing profile’s properties/invoice/payment context | Billing profile | **Billing profile reader** | documented | Read-only access to the billing profile ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)). |
| View invoices for a billing profile | Billing profile | **Invoice manager** | partially_documented | Narrowest invoice-focused role current Learn names; exact per-action minimum is not presented as one formal permission matrix ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)). |
| Download invoice PDF | Billing profile | **Invoice manager** | partially_documented | Invoice-specific least privilege; broader roles also work ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)). |
| View costs for one invoice section | Invoice section | **Invoice section reader** | documented | Read-only access at the smallest billing scope ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)). |
| Manage invoice-section organization | Invoice section | **Invoice section contributor** | documented | Contributor manages everything except permissions at that scope ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)). |
| View costs across all sections within one billing profile | Billing profile | **Billing profile reader** | documented | Use billing profile scope when cross-section visibility is required ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)). |
| Create subscription under a specific invoice section | Invoice section | **Azure subscription creator** | documented | Explicit delegated creation role for the target invoice section ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)). |
| Create subscription anywhere under a billing profile | Billing profile | **Billing profile contributor** | documented | Broader than invoice-section creator, but sufficient at billing profile scope ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)). |
| Create subscription anywhere under billing account | Billing account | **Billing account contributor** | documented | Broadest billing-scope creation delegation ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)). |
| Power BI direct connector to MCA billing account/profile | Billing account or billing profile | **Contributor or greater** | pending_validation | Current Power BI Learn doc says Contributor or greater. Treat as source of truth, but validate in the customer tenant because it is stricter than many teams expect ([Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connect-azure-cost-management)). |

## Persona recommendations

| Persona | Recommended assignment | Rationale |
|---|---|---|
| Finance-only invoice consumers | **Invoice manager** at the billing profile | Invoice-focused access without granting billing account-wide visibility. |
| Cost viewers by department/project | **Invoice section reader** at the target invoice section | Smallest billing-scope reader role for segmented cost visibility. |
| Central FinOps over one invoice group | **Billing profile reader** | Enables cross-section visibility within a billing profile. |
| Automation service principal for subscription creation | **Azure subscription creator** on the target invoice section only | Narrow delegated role for subscription creation under an approved invoice section ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)). |

Avoid billing account roles unless cross-profile visibility or administration is actually required. Billing account inheritance is broad and cannot be removed at lower scopes ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)).

## Least-privilege cautions

- Do not blur Azure RBAC and MCA billing roles. Azure RBAC on subscriptions does not by itself grant billing-scope permissions for MCA billing operations.
- Do not grant tenant-wide Owner, Global Admin, or broad billing account roles just to make a test pass.
- Use dedicated automation identities for create actions, keep credentials out of repository files, and parameterize tenant and billing identifiers.
