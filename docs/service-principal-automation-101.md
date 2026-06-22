# Service Principal 101 — automate MCA subscription creation

A complete, detailed walkthrough: create a **service principal (SP)**, grant it the
**least‑privilege** billing role, and use it to **automate Azure subscription
creation** under a Microsoft Customer Agreement (MCA) — by hand, with this repo, and
in CI.

Grounded in Microsoft Learn:
[Programmatically create MCA subscriptions](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement).

---

## The model in one picture

```
Entra app registration ──has──▶ service principal (enterprise app)
        │ appId (client id)            │ OBJECT ID  ◀── the billing role is granted to THIS
        │ + credential                 │
        ▼                              ▼
   authenticates ──────▶ "Azure subscription creator"  (billing role, on ONE invoice section)
        │                              │
        ▼                              ▼
   Terraform / CLI ─────▶ Microsoft.Subscription/aliases ─────▶ new subscription
                                                                billed to that invoice section
```

Least privilege end state: the SP holds **one billing role on one invoice section**.
No Azure RBAC, no Entra directory roles, no billing‑account‑wide access.

---

## 0. Three things people get wrong (read first)

1. **App registration ≠ service principal, and they have different object IDs.**
   - The **app registration** has an `appId` (client ID) *and* its own object ID.
   - The **service principal** (a.k.a. enterprise application) has a **separate
     object ID**.
   - 👉 The **billing role assignment uses the *service principal* object ID** — not
     the `appId`, not the app registration's object ID. Get it with
     `az ad sp show --id <appId> --query id -o tsv`
     ([Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)).
2. **Billing roles ≠ Azure RBAC ≠ Entra roles.** Creating subscriptions needs a
   *billing* role on the invoice section. Owner on a subscription does nothing for
   billing‑scope creation, and vice‑versa.
3. **Latest vs legacy API permissions differ.** A role that works on the legacy API
   (`2018-03-01-preview`) may not be enough on the latest API (`2020-05-01`); a
   billing admin may need to delegate the role to your SP
   ([Learn](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)).

---

## 1. Prerequisites

| To do this... | You need... |
|---|---|
| Create the app + SP | Permission to register apps (Application Developer, or have an admin do it) |
| Grant the billing role | **Billing account owner** or **invoice section owner** (or billing profile owner) on the target scope |
| Run the automation | The SP itself, after the role is granted |

Tools: `az` (logged in), and Terraform ≥ 1.5 for the Terraform path.

---

## 2. Create the service principal

### 2a. App registration + service principal

```bash
APP_NAME="ea2mca-sub-automation"

# 1) Register the app
az ad app create --display-name "$APP_NAME"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

# 2) Create the service principal (enterprise app) for it
az ad sp create --id "$APP_ID"

# 3) Capture the IDs you'll need
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)   # <-- billing role uses THIS
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "appId (client id) : $APP_ID"
echo "SP object id      : $SP_OBJECT_ID"
echo "tenant id         : $TENANT_ID"
```

> `az ad sp create-for-rbac` is a shortcut, but it tries to assign **Azure RBAC**.
> For least privilege we do **not** want RBAC — only the billing role — so create the
> app + SP without any role assignment as above.

### 2b. Give the SP a credential — pick ONE

**Option A — federated credential / OIDC (recommended; no secret to store):**

```bash
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/<repo>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

**Option B — client secret (simplest; rotate and store securely):**

```bash
az ad app credential reset --id "$APP_ID" --display-name "terraform" --years 1
# Outputs "password" = the client secret. Put it in a secret store. NEVER commit it.
```

---

## 3. Grant the new role (least privilege)

Find the invoice section names, then grant **Azure subscription creator** to the
**SP object ID** on that invoice section only.

```bash
# Discover scope names
scripts/discover_billing_scopes.sh --account "<BILLING_ACCOUNT_NAME>"

# Grant (preview first, then add --apply). For an SP, pass --principal-tenant-id.
scripts/assign_billing_role.sh \
  --billing-account "<BA>" --billing-profile "<BP>" --invoice-section "<IS>" \
  --role "Azure subscription creator" \
  --principal-id "$SP_OBJECT_ID" --principal-tenant-id "$TENANT_ID" --apply
```

<details>
<summary>Equivalent raw REST (what the script sends)</summary>

```http
PUT https://management.azure.com/providers/Microsoft.Billing/billingAccounts/<BA>/billingProfiles/<BP>/invoiceSections/<IS>/billingRoleAssignments/<new-guid>?api-version=2024-04-01
{
  "properties": {
    "principalId": "<SP_OBJECT_ID>",
    "principalTenantId": "<TENANT_ID>",
    "roleDefinitionId": ".../invoiceSections/<IS>/billingRoleDefinitions/a0bcee42-bf30-4d1b-926a-48d21664ef71"
  }
}
```
`a0bcee42-bf30-4d1b-926a-48d21664ef71` is the **Azure subscription creator** billing
role. The script resolves it by name so you never hardcode the GUID.
</details>

**Portal alternative:** Cost Management + Billing → select the **invoice section** →
**Access control (IAM)** → **Add** → role *Azure subscription creator* → pick the app.

### Verify the assignment

```bash
IS_SCOPE="/providers/Microsoft.Billing/billingAccounts/<BA>/billingProfiles/<BP>/invoiceSections/<IS>"
az rest --method get \
  --url "https://management.azure.com${IS_SCOPE}/billingRoleAssignments?api-version=2024-04-01" \
  --query "value[?properties.principalId=='$SP_OBJECT_ID'].properties.roleDefinitionId"
```

That's the **only** grant needed to create subscriptions. (If the SP must also
*manage resources* inside the new subscription later, that's a separate Azure RBAC
grant — out of scope here.)

---

## 4. Authenticate as the SP

| Consumer | How |
|---|---|
| **Terraform (secret)** | `export ARM_CLIENT_ID=$APP_ID ARM_CLIENT_SECRET=<secret> ARM_TENANT_ID=$TENANT_ID` |
| **Terraform (OIDC)** | `export ARM_CLIENT_ID=$APP_ID ARM_TENANT_ID=$TENANT_ID ARM_USE_OIDC=true` (token supplied by CI) |
| **Azure CLI** | `az login --service-principal -u "$APP_ID" -p <secret> --tenant "$TENANT_ID"` |

> The SP has **no** subscription RBAC, so `az login` / `azure/login` should use
> **`--allow-no-subscriptions`** — authentication still succeeds for billing/alias
> operations.

---

## 5. Create the subscription (three equivalent ways)

**A. Terraform (this repo):**

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # fill in BA/BP/IS, alias, display name
terraform init && terraform apply
terraform output subscription_id
```

**B. This repo's script:**

```bash
scripts/create_subscription.sh \
  --billing-account "<BA>" --billing-profile "<BP>" --invoice-section "<IS>" \
  --alias "ea2mca-test-sub-001" --display-name "EA2MCA Test Sub 01" --workload DevTest
```

**C. Raw Azure CLI:**

```bash
az extension add --name account 2>/dev/null; az extension add --name alias 2>/dev/null
az account alias create --name "ea2mca-test-sub-001" \
  --billing-scope "/providers/Microsoft.Billing/billingAccounts/<BA>/billingProfiles/<BP>/invoiceSections/<IS>" \
  --display-name "EA2MCA Test Sub 01" --workload "DevTest"
```

All three call the same `Microsoft.Subscription/aliases@2021-10-01` API and return a
`subscriptionId` when `provisioningState` reaches `Succeeded`.

---

## 6. Automate in CI (GitHub Actions + OIDC)

A ready template lives at
[`.github/workflows/create-mca-subscription.yml`](../.github/workflows/create-mca-subscription.yml).
It uses the **federated credential** from step 2b (no secrets), so configure:

- **Repo secrets:** `AZURE_CLIENT_ID` (= `appId`), `AZURE_TENANT_ID`
- **Repo variables:** `BILLING_ACCOUNT`, `BILLING_PROFILE`, `INVOICE_SECTION`

Then run it from the Actions tab (manual `workflow_dispatch`) with an alias + display
name. Key bits:

```yaml
permissions:
  id-token: write      # required for OIDC
  contents: read
env:
  ARM_USE_OIDC: "true"
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
steps:
  - uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      allow-no-subscriptions: true          # SP has only a billing role
```

---

## 7. Security best practices

- **Prefer federated credentials (OIDC) over secrets.** No secret to leak or rotate.
- **Least privilege:** Azure subscription creator on the **one** invoice section the
  SP should use — never billing account owner "to make it work".
- **One SP per purpose**, clearly named (`ea2mca-sub-automation`), and time‑boxed for
  a test engagement.
- **Never commit** secrets, `appId`+secret pairs, `.tfvars`, or Terraform state.
- **Rotate / expire** secrets; remove the SP and its role assignment when the test is
  done (see the [CSA runbook](./csa-setup-runbook.md) cleanup section).

---

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `403 AuthorizationFailed` on create | SP lacks the billing role, or you granted it the **wrong** object ID (used `appId` or the app‑registration object ID) | Re‑check `SP_OBJECT_ID` via `az ad sp show --id <appId> --query id`; grant Azure subscription creator on the invoice section |
| Role assignment for the SP fails | Missing `principalTenantId` | Re‑run with `--principal-tenant-id "$TENANT_ID"` |
| Works on old API, fails on latest | Latest‑API permission delegation | Have a billing admin delegate the role for the latest API |
| `az login` says "no subscriptions" | The SP only has a billing role (expected) | Add `--allow-no-subscriptions` |
| Alias returns existing sub / no change | Idempotency — alias reused | Use a new `subscription_alias_name` |

---

## Where this maps in the repo

- Grant role: [`scripts/assign_billing_role.sh`](../scripts/assign_billing_role.sh)
- Create (script): [`scripts/create_subscription.sh`](../scripts/create_subscription.sh)
- Create (Terraform): [`infra/terraform/`](../infra/terraform/README.md)
- CI template: [`.github/workflows/create-mca-subscription.yml`](../.github/workflows/create-mca-subscription.yml)
- Setup sequence + cleanup: [`csa-setup-runbook.md`](./csa-setup-runbook.md)
