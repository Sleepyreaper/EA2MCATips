# infra/terraform — automate MCA subscription creation

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

## How it works

`main.tf` submits one `Microsoft.Subscription/aliases@2021-10-01` resource at the
tenant scope. Its `billingScope` is the **invoice section** resource ID that
`locals.tf` assembles from your three `*_name` variables. The alias `name` is an
**idempotency key**: re-running with the same name returns the existing
subscription instead of creating a new one. The new subscription's GUID is exported
as the `subscription_id` output.

## Variables

| Variable | Required | Default | Notes |
|----------|:--------:|---------|-------|
| `billing_account_name` | yes | — | Segment after `billingAccounts/` in the resource ID |
| `billing_profile_name` | yes | — | Segment after `billingProfiles/` |
| `invoice_section_name` | yes | — | Segment after `invoiceSections/`; where the sub is billed and where the SP needs the creator role |
| `subscription_alias_name` | yes | — | Stable idempotency key (1–63 chars: letters, digits, `.`, `_`, `-`) |
| `subscription_display_name` | yes | — | Friendly name shown in the portal |
| `workload` | no | `Production` | `Production` or `DevTest` |
| `tenant_id` | no | _(env)_ | Entra tenant GUID; inherited from `az login` / `ARM_TENANT_ID` when blank |
| `management_group_id` | no | — | Optional MG to place the subscription under |
| `subscription_owner_id` | no | — | Optional principal to grant subscription Owner |
| `tags` | no | `{}` | Optional tags on the new subscription |

Find the three billing `*_name` values with
`../../scripts/discover_billing_scopes.sh --account "<BA>"`.

## Prerequisites

1. **Terraform >= 1.5** and the **AzAPI provider** (`Azure/azapi ~> 2.0`, installed
   by `terraform init`).
2. **Least-privilege role:** the identity running Terraform needs the **Azure
   subscription creator** *billing* role on the target **invoice section** — not
   Owner/Contributor at the billing account, and not just Azure RBAC on a
   subscription. Grant it with
   `../../scripts/assign_billing_role.sh --role "Azure subscription creator" ...`
   (see `../../docs/csa-setup-runbook.md`).
3. **Authentication** (one of):
   - **Azure CLI** — `az login` (developer / interactive).
   - **Service principal** — export `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`,
     `ARM_TENANT_ID`.
   - **OIDC / federated** (CI) — `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_USE_OIDC=true`.

## Walkthrough (end to end)

```bash
cd infra/terraform

# 1. Provide your billing IDs
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars        # set billing_account_name, billing_profile_name,
                                # invoice_section_name, alias, display name, workload

# 2. Authenticate (developer)
az login
#    ...or service principal (CI):
# export ARM_CLIENT_ID=...  ARM_CLIENT_SECRET=...  ARM_TENANT_ID=...

# 3. Initialize providers
terraform init

# 4. Pre-flight - no Azure changes
terraform fmt -check
terraform validate
terraform plan                  # review the alias that will be created

# 5. Create the subscription
terraform apply                 # type 'yes' to confirm

# 6. Read the result
terraform output subscription_id
```

The `subscription_id` output is the new subscription GUID, ready to target with the
`azurerm` provider in downstream configurations.

## CI / review before a real tenant exists

These make **no** Azure API calls and create nothing — safe for PRs and demos:

```bash
terraform fmt -check && terraform init -backend=false && terraform validate
```

## Lifecycle & `terraform destroy` (read this)

**Destroying the alias resource removes only the *alias* — it does NOT delete or
cancel the subscription**, and the subscription keeps billing. This is Azure's
behavior, not a bug. To stop charges you must **cancel the subscription**
separately (portal: Subscriptions -> ... -> Cancel, or the Subscription REST API).
Treat `terraform destroy` here as "forget the alias," not "delete the subscription."

Because the alias is the idempotency key, keep `terraform.tfvars` (and your state)
if you want Terraform to keep managing that subscription.

## Idempotency

Re-running `apply` with the same `subscription_alias_name` returns the existing
subscription instead of creating a duplicate. Use a **new** alias name for each new
subscription.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `401`/`403` on apply | The identity lacks the billing role | Grant **Azure subscription creator** on the **invoice section** (`assign_billing_role.sh`) — Azure RBAC is not enough |
| `Resource ... not found` / empty `subscription_id` | Wrong `*_name` values or scope | Re-run `discover_billing_scopes.sh` and copy the exact segment names |
| `provider registry ... azapi` not found | `terraform init` not run | Run `terraform init` |
| Alias "already exists" / no change | Idempotency — alias already used | Use a new `subscription_alias_name` for a new subscription |
| Auth errors with a service principal | Missing/incorrect `ARM_*` env vars | Export `ARM_CLIENT_ID` / `ARM_CLIENT_SECRET` / `ARM_TENANT_ID` (or `ARM_USE_OIDC=true`) |

## AzureRM alternative

An `azurerm_subscription` version is included, inert, as `main.azurerm.tf.example`.
Microsoft Learn is less explicit about the exact `azurerm_subscription` shape for
MCA `billing_scope_id`, so validate it against your provider version before
switching. See `../../docs/uncertainty-register.md` (U5).
