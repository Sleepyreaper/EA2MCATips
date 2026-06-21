# Billing Hierarchy and Invoice Flow

## MCA hierarchy

MCA uses a billing hierarchy of **billing account → billing profile → invoice section → subscription** ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).

```text
Billing account
└── Billing profile
    ├── Invoice section
    │   ├── Subscription
    │   └── Subscription
    └── Invoice section
        └── Subscription
```

- A **billing account** is the top billing container for the agreement. It manages invoices, payments, and overall cost tracking ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).
- A **billing profile** manages invoice and payment methods. A monthly invoice is generated for each billing profile ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).
- An **invoice section** organizes costs on the billing profile invoice, often by department, project, or environment ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).
- **Subscriptions are billed to invoice sections**, and their charges roll up to the parent billing profile invoice ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).

## EA to MCA operating model

| EA concept | MCA equivalent | Source |
|---|---|---|
| EA Enrollment | Billing profile for invoice management | [Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-enterprise-operations) |
| EA Department | Invoice section | [Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-enterprise-operations) |
| EA Account / delegated subscription creation | Azure subscription creator on an invoice section | [Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-enterprise-operations) |

## How charges flow

A subscription is associated with an invoice section. Subscription usage and purchases accrue to that invoice section, then appear on the parent billing profile invoice segmented by invoice section. Microsoft Learn describes invoice sections as cost organizers on the invoice and billing profiles as the level where monthly invoices are generated ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-section-invoice), [Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).

## Operational billing flow under MCA

1. The **billing account** exists for the MCA agreement.
2. One or more **billing profiles** are created; each billing profile has its own monthly invoice and payment configuration ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)).
3. Each billing profile has one or more **invoice sections** used to organize charges ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-section-invoice)).
4. A subscription is associated with an **invoice section** ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)).
5. Subscription usage and purchases accrue to that invoice section ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-section-invoice)).
6. At invoice time, those charges appear on the parent **billing profile invoice**, segmented by invoice section ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/mca-section-invoice)).
7. Users with the right **billing profile roles** can view, pay, or download invoices ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/download-azure-invoice-daily-usage-date)).
8. Users with appropriate scope permissions can analyze costs in Cost Management and export/report from those scopes ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).
