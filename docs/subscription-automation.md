# Subscription automation (MCA)

How this repo creates Azure subscriptions under a **Microsoft Customer Agreement
(MCA)**, using least privilege and parameterized inputs only. Two equivalent
paths are provided — Terraform and a shell script — both built on the same
`Microsoft.Subscription/aliases` API.

## The model

Under MCA, a subscription is created under an **invoice section**, and its
billing scope is that invoice section's resource ID:

```
/providers/Microsoft.Billing/billingAccounts/{billingAccount}/billingProfiles/{billingProfile}/invoiceSections/{invoiceSection}
```

The current, Microsoft Learn-documented creation pattern is the **subscription
alias** API ([Learn: aliases REST](https://learn.microsoft.com/en-us/rest/api/subscription/alias/create?view=rest-subscription-2021-10-01),
[Learn: ARM schema](https://learn.microsoft.com/en-us/azure/templates/microsoft.subscription/aliases)).
The alias name is an **idempotency key** — reusing it returns the existing
subscription instead of creating a duplicate.

## Least privilege

The principal that creates the subscription needs **Azure subscription creator**
on the **target invoice section** — not Owner/Contributor at the billing account
([Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)).
Billing-scope roles are separate from Azure RBAC; Azure RBAC on a subscription
does **not** grant billing-scope create rights.

Grant it (preview, then apply):

```bash
scripts/assign_subscription_creator_role.sh \
  --billing-account "<BA>" --billing-profile "<BP>" --invoice-section "<IS>" \
  --principal-id "<SP_OBJECT_ID>"          # add --apply to commit
```

## Step 1 — Discover billing scope IDs

```bash
az login
scripts/discover_billing_scopes.sh --account "<BILLING_ACCOUNT_NAME>"
```

This lists billing accounts → billing profiles → invoice sections so you can read
off the three `*_name` values.

## Step 2a — Create with Terraform (recommended)

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # fill in your IDs
terraform init
terraform validate          # no Azure calls
terraform plan              # review what will be created
terraform apply
terraform output subscription_id
```

Authenticate first with `az login`, or a service principal via `ARM_CLIENT_ID` /
`ARM_CLIENT_SECRET` / `ARM_TENANT_ID` (or `ARM_USE_OIDC=true` for CI). The SP needs
the **Azure subscription creator** billing role on the invoice section — Azure RBAC
alone is not enough.

> **Full Terraform walkthrough** — variable reference, service-principal/OIDC auth,
> CI validate-only, the `terraform destroy` gotcha (destroying the alias does **not**
> cancel the subscription), and troubleshooting — is in
> [`infra/terraform/README.md`](../infra/terraform/README.md).

The active resource is `azapi_resource.subscription_alias` (AzAPI). An AzureRM
alternative (`azurerm_subscription`) is included as
`infra/terraform/main.azurerm.tf.example` — validate it against your provider
version before switching, per [uncertainty register U5](./uncertainty-register.md).

## Step 2b — Create with the script (equivalent)

```bash
scripts/create_subscription.sh \
  --billing-account "<BA>" --billing-profile "<BP>" --invoice-section "<IS>" \
  --alias "ea2mca-test-sub-001" --display-name "EA2MCA Test Sub 01" \
  --workload DevTest --dry-run        # remove --dry-run to create
```

It PUTs the alias and polls `provisioningState` until `Succeeded`, then prints the
new `subscriptionId`.

## Why AzAPI over azurerm_subscription

Microsoft Learn documents the alias API + ARM schema explicitly, so AzAPI is the
lowest-risk path today. Learn is less explicit about the exact `azurerm_subscription`
argument shape for MCA `billing_scope_id`, so we keep AzureRM as a documented,
validate-first alternative rather than the default. See
[uncertainty-register.md](./uncertainty-register.md) (U5).

## Safe-before-tenant workflow

Everything here is inert until you supply real IDs and authenticate:

- Terraform: `terraform init -backend=false && terraform validate` makes no Azure calls.
- Scripts: `--dry-run` (create) and dry-run-by-default (role assignment) print the
  exact request without sending it.

When you're ready, provide the values in
[what-i-need-from-you.md](./what-i-need-from-you.md) and we wire it to your test
environment.
