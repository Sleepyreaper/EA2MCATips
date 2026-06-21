# EA to MCA Migration Enablement Overview

This repository is a CSA handoff package for helping enterprise customers move from Azure Enterprise Agreement (EA) billing assumptions to Microsoft Customer Agreement (MCA) billing scopes, roles, invoices, reporting, and automation patterns. It is written for Microsoft Cloud Solution Architects, customer platform teams, FinOps teams, finance stakeholders, and implementation engineers.

Under MCA, customers should rebuild their operating model from EA enrollment, department, and account constructs to **billing account → billing profile → invoice section → subscription**. Billing profiles manage invoice and payment grouping, invoice sections organize charges, and subscriptions are billed to invoice sections that roll up to billing profile invoices ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview)). Existing EA cost, invoice, reporting, and subscription-creation automations often need scope, permission, and API changes because MCA uses different billing scopes and current ARM-based Billing, Subscription, and Cost Management APIs ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/migrate-cost-management-api)).

## Documentation map

| Document | Purpose |
|---|---|
| [CSA setup runbook](./csa-setup-runbook.md) | **Start here to *do* it.** Step-by-step: CSA uses elevated rights for setup, then provisions least-privilege accounts for the customer to test with. |
| [EA to MCA deep dive](./ea-to-mca-deep-dive.md) | Full Microsoft Learn-grounded narrative for hierarchy, roles, APIs, portal changes, and CSA guidance. |
| [RBAC role-task matrix](./rbac-role-task-matrix.md) | Least-privilege role recommendations by task, persona, and evidence state. |
| [API mapping](./api-mapping.md) | EA-era pattern to MCA/current API mapping and automation breaking changes. |
| [Billing hierarchy and invoice flow](./billing-hierarchy-invoice-flow.md) | MCA hierarchy, charge rollup, and operational billing flow. |
| [Invoice management](./invoice-management.md) | Invoice structure, timing, portal/API download, and invoice role guidance. |
| [Testing strategy](./testing-strategy.md) | CSA checklist for offline validation, RBAC tests, API/report tests, and controlled live validation. |
| [Uncertainty register](./uncertainty-register.md) | Known evidence gaps and recommended conservative stances. |
| [Sources](./sources.md) | Numbered Microsoft Learn reference list with dashboard link keys. |
| [What I need from you](./what-i-need-from-you.md) | Customer/environment intake checklist for real test wiring. |

## Repo areas

- `docs/` contains this written customer handoff package.
- `dashboard/` is intended as a static visual review surface for this content.
- `infra/terraform/` and `scripts/` are intended to automate controlled MCA subscription-creation testing after customer-specific values and approvals are supplied.
