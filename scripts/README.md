# scripts

Thin, runnable wrappers for the EA→MCA subscription-creation workflow. All are
parameterized — no billing IDs or secrets are baked in. Authenticate with
`az login` first.

| Script | What it does | Mutating? |
|--------|--------------|-----------|
| `check_billing_access.sh` | Diagnose whether **you** can create subscriptions and assign billing roles at a scope — run this **before** trying to grant the SP | No (read-only) |
| `discover_billing_scopes.sh` | List billing accounts → profiles → invoice sections to find the three names you need | No (read-only) |
| `assign_billing_role.sh` | Grant **any** MCA billing role (resolved by name) to a principal at the smallest scope — for provisioning least-privilege test accounts | Yes — `--dry-run` by default, needs `--apply` |
| `assign_subscription_creator_role.sh` | Convenience shortcut: grant **Azure subscription creator** on an invoice section | Yes — `--dry-run` by default, needs `--apply` |
| `create_subscription.sh` | Create a subscription under an invoice section via the alias API, then poll until done | Yes — `--dry-run` available |
| `serve_dashboard.sh` | Serve `dashboard/` over local HTTP | No |

## Typical flow

```bash
az login

# 1. Find your billing scope IDs
scripts/discover_billing_scopes.sh --account "<BILLING_ACCOUNT_NAME>"

# 2. Grant the automation SP least privilege (preview first, then apply)
scripts/assign_subscription_creator_role.sh \
  --billing-account "<BA>" --billing-profile "<BP>" --invoice-section "<IS>" \
  --principal-id "<SP_OBJECT_ID>"            # add --apply to commit

# 3. Create a subscription (preview the request first)
scripts/create_subscription.sh \
  --billing-account "<BA>" --billing-profile "<BP>" --invoice-section "<IS>" \
  --alias "ea2mca-test-sub-001" --display-name "EA2MCA Test Sub 01" \
  --workload DevTest --dry-run                # remove --dry-run to create

# 4. View the dashboard
scripts/serve_dashboard.sh 8080
```

`create_subscription.sh` and the Terraform in `infra/terraform/` are two paths to
the **same** result — use whichever fits your workflow. Both require **Azure
subscription creator** on the target invoice section. See
`../docs/subscription-automation.md`.
