# EA2MCAWork — EA → MCA Migration Enablement

A practical, Microsoft Learn-grounded package for helping enterprise customers move
from an Azure **Enterprise Agreement (EA)** to a **Microsoft Customer Agreement
(MCA)**. Built for Cloud Solution Architects (CSAs) and their customers.

It covers the things teams actually have to test and rebuild during the move:
least-privilege **RBAC roles** against billing profiles, invoices, and reports; the
**EA→MCA API and dashboard** changes; the **costing / invoice-structure** flow and
how to download invoices; and **Terraform + script automation** for creating
subscriptions under the new MCA subscription-creator role — documented, built, and
testable.

> Everything is **parameterized and least-privilege**. No tenant IDs, billing IDs,
> or secrets are committed. Nothing touches Azure until you supply your test
> environment values (see [`docs/what-i-need-from-you.md`](docs/what-i-need-from-you.md)).

## What's here

```
docs/            Microsoft Learn-grounded guides (research, RBAC matrix, API map,
                 billing/invoice flow, subscription automation, testing, sources)
dashboard/       Static HTML/CSS/JS dashboard visualizing the RBAC matrix,
                 EA→MCA API mapping, billing hierarchy, and automation status
infra/terraform/ Parameterized Terraform to create an MCA subscription (AzAPI alias)
scripts/         Runnable wrappers: discover billing scopes, grant least-privilege
                 role, create a subscription, serve the dashboard
src/ea2mca/      Python package scaffold (for future Python tooling)
```

## Quickstart

**Read the guide** — start at [`docs/overview.md`](docs/overview.md), then the
[deep dive](docs/ea-to-mca-deep-dive.md) and [RBAC matrix](docs/rbac-role-task-matrix.md).

**View the dashboard** (must be served over HTTP, not `file://`):

```bash
scripts/serve_dashboard.sh 8080   # then open http://localhost:8080
```

**Create a subscription** (after `az login`; preview first):

```bash
# 1. find your billing scope IDs
scripts/discover_billing_scopes.sh --account "<BILLING_ACCOUNT_NAME>"

# 2. Terraform path
cd infra/terraform && cp terraform.tfvars.example terraform.tfvars   # edit IDs
terraform init && terraform validate && terraform apply

# …or the script path
scripts/create_subscription.sh --billing-account "<BA>" --billing-profile "<BP>" \
  --invoice-section "<IS>" --alias "ea2mca-test-sub-001" \
  --display-name "EA2MCA Test Sub 01" --workload DevTest --dry-run
```

See [`docs/subscription-automation.md`](docs/subscription-automation.md) for the full flow
and [`docs/testing-strategy.md`](docs/testing-strategy.md) to test RBAC against billing
profiles, invoices, and reports.

## Key facts (all cited in `docs/`)

- MCA hierarchy: **billing account → billing profile → invoice section → subscription**.
- Subscriptions are billed to an **invoice section**; one invoice per **billing profile**.
- Least privilege to **create subscriptions** = **Azure subscription creator** on the
  target invoice section (not Owner/Contributor at the billing account).
- Subscription creation uses the **`Microsoft.Subscription/aliases`** API.
- Billing-scope roles are **separate** from Azure RBAC.

## Provenance

The research and dashboard design were produced by the Springfield agent team
(Marge orchestration: Troy = research, Hank = architecture/dashboard, Snake = run
guidance, Lisa = handoff, Bob = security). The Terraform, scripts, and docs were
completed and validated here. Source research is preserved in the session artifacts.

## Status

- ✅ Docs, dashboard, Terraform, and scripts are complete and validated offline.
- ⏳ Pending: real test-environment wiring — provide the values in
  [`docs/what-i-need-from-you.md`](docs/what-i-need-from-you.md).
- ⚠️ Items marked `pending_validation` (e.g. exact invoice-download role, Power BI
  connector permission) should be confirmed in your tenant — see
  [`docs/uncertainty-register.md`](docs/uncertainty-register.md).
