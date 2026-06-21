# Readiness Checklist — what you need to run every workflow

One place that answers "what do I need to *do* all of this?" Work top to bottom:
install the tools, confirm your access, gather the inputs, then use the per-workflow
matrix to see exactly what each task requires.

For the **customer-supplied values** (tenant ID, billing IDs, SP credentials,
approvals), use the intake form in [what-i-need-from-you.md](./what-i-need-from-you.md).
For the **sequence** (elevated setup → least-privilege accounts → cleanup), follow the
[CSA setup runbook](./csa-setup-runbook.md).

---

## 1. Tools

- [ ] **Azure CLI** (`az`) installed, and `az login` completed.
- [ ] **Terraform >= 1.5** (only for the Terraform path).
- [ ] **Python 3** (used by the scripts for JSON parsing and to serve the dashboard).
- [ ] **A web browser** (to view the dashboard / use the portal).
- [ ] This repo cloned, with `chmod +x scripts/*.sh`.

```bash
az version            # Azure CLI present
terraform -version    # >= 1.5
python3 --version     # 3.x
```

## 2. Access / roles you (the operator) need

These are **setup-time** roles — hold them temporarily (prefer PIM just-in-time),
then step back down (see the runbook's cleanup section).

- [ ] **Microsoft Entra Global Administrator** — to create the customer's test
      identities (users / service principals). *Not* a billing role.
- [ ] **MCA billing account owner** (or owner/contributor at the target scope) — to
      **assign billing roles**. Global Admin alone cannot do this.
- [ ] *(Only if a test needs Azure resource visibility across subscriptions)*
      ability to **elevate access** to User Access Administrator at root.

```bash
# Verify your Entra directory roles:
az rest --method get --url "https://graph.microsoft.com/v1.0/me/memberOf?\$select=displayName" \
  --query "value[].displayName"
# Verify your billing roles on the account:
az rest --method get \
  --url "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<BA>/billingRoleAssignments?api-version=2024-04-01" \
  --query "value[?properties.principalId=='<your-object-id>'].properties.roleDefinitionId"
```

## 3. Inputs to gather

- [ ] **Tenant ID**
- [ ] **Billing account name** (`billing_account_name`)
- [ ] **Billing profile name** (`billing_profile_name`)
- [ ] **Invoice section name** (`invoice_section_name`)
- [ ] **Object IDs** of each test identity you'll assign roles to
- [ ] **Subscription** alias + display name + workload (`Production`/`DevTest`)
- [ ] *(Reporting, optional)* storage account for Cost Management exports; Power BI test user

Get the three billing `*_name` values with:

```bash
scripts/discover_billing_scopes.sh --account "<BILLING_ACCOUNT_NAME>"
```

---

## 4. Per-workflow readiness matrix

| Workflow | Tools | Role / access needed | Inputs | Run with |
|----------|-------|----------------------|--------|----------|
| **Discover billing scopes** | az + login | Any billing **reader** on the account (or owner) | billing account name | `scripts/discover_billing_scopes.sh` |
| **Provision least-privilege test accounts** | az + login | **Global Admin** (create identities) + **billing account owner** (assign roles) | scope names, principal object IDs, role names | `scripts/assign_billing_role.sh` · [runbook](./csa-setup-runbook.md) |
| **Create subscription — Terraform** | Terraform >=1.5, AzAPI, az/SP/OIDC auth | **Azure subscription creator** on the invoice section | 3 scope names, alias, display name, workload | [`infra/terraform/`](../infra/terraform/README.md) |
| **Create subscription — script** | az + login | **Azure subscription creator** on the invoice section | same as above | `scripts/create_subscription.sh` |
| **Test RBAC (profiles / invoices / reports)** | browser/portal, az | the **test identities** with their assigned least-privilege roles | test identities + assignments | [testing-strategy.md](./testing-strategy.md) |
| **View the dashboard** | python3 (local HTTP) | none | none | `scripts/serve_dashboard.sh 8080` |
| **Cost exports** | portal / az | **reader** at the billing scope; a target storage account | storage account | [deep dive](./ea-to-mca-deep-dive.md) |
| **Power BI connector test** | Power BI Desktop | **Contributor or greater** on billing account/profile (stricter than reader — validate) | PBI test user | [testing-strategy.md](./testing-strategy.md) |

> Role facts above are the least-privilege answers from the
> [RBAC role-task matrix](./rbac-role-task-matrix.md); items like the Power BI
> permission are flagged `pending_validation` in the
> [uncertainty register](./uncertainty-register.md) — confirm in the customer tenant.

---

## 5. Safety gates (before any live create/write)

- [ ] Customer approved the **test tenant** and a **non-production billing scope**.
- [ ] Customer approved the **least-privilege role assignments**.
- [ ] **Human approval** obtained before any subscription **create** action.
- [ ] Everything ran **dry-run / `terraform validate`** clean first.
- [ ] No real IDs, secrets, `.tfvars`, or state committed to the repo.
- [ ] Cleanup plan agreed (remove elevation, deprovision test access, cancel test
      subscriptions — note `terraform destroy` does **not** cancel a subscription).
