# infra/terraform — MCA subscription creation

Parameterized Terraform that creates an Azure subscription under a **Microsoft
Customer Agreement (MCA) invoice section**, using the
`Microsoft.Subscription/aliases` ARM API via the **AzAPI** provider.

Nothing here is hardcoded. All billing identifiers and credentials come from
variables / the environment, so this is safe to wire to your test environment.

## Files

| File | Purpose |
|------|---------|
| `versions.tf` | Terraform + AzAPI provider version constraints |
| `providers.tf` | Provider auth (env-based; no secrets in code) |
| `variables.tf` | All inputs (billing scope, subscription, optional MG/owner/tags) |
| `locals.tf` | Builds the invoice-section billing scope ID |
| `main.tf` | The `azapi_resource` subscription alias |
| `outputs.tf` | `subscription_id`, alias ID, billing scope |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` and fill in |
| `main.azurerm.tf.example` | Optional AzureRM alternative (inert by default) |

## Prerequisites

1. **Least-privilege role:** the principal running Terraform needs **Azure
   subscription creator** on the target **invoice section** (not Owner/Contributor
   at the billing account). See `../../docs/subscription-automation.md` and use
   `../../scripts/assign_subscription_creator_role.sh` to grant it.
2. **AzAPI provider** (`Azure/azapi ~> 2.0`) — installed by `terraform init`.
3. **Authentication** via one of: `az login`, a service principal
   (`ARM_CLIENT_ID` / `ARM_CLIENT_SECRET` / `ARM_TENANT_ID`), or OIDC.

## Usage

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # then edit with your IDs

terraform init
terraform fmt -check
terraform validate          # safe: no Azure calls
terraform plan              # shows what will be created
terraform apply             # creates the subscription
terraform output subscription_id
```

Discover `billing_account_name` / `billing_profile_name` / `invoice_section_name`
with `../../scripts/discover_billing_scopes.sh`.

## Safe-by-default workflow

For review / CI before a real tenant exists, run only:

```bash
terraform fmt -check && terraform init -backend=false && terraform validate
```

These make **no** Azure API calls and create nothing.

## Idempotency

The subscription **alias name** is the idempotency key. Re-running with the same
`subscription_alias_name` returns the existing subscription instead of creating a
duplicate. Use a new alias name for each new subscription.
