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

## 0. Four things people get wrong (read first)

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
4. **You can only delegate a role you can administer — and you can't self‑bootstrap
   it.** Granting the SP the role is a `billingRoleAssignments/write`, which requires
   **effective owner/manage‑access** at that scope (Invoice section owner, or Billing
   profile/account owner). Being able to *create* subscriptions (Azure subscription
   creator) is **not** enough to *delegate*. And a non‑owner can't grant themselves
   ownership — someone who is already an effective owner must do it. See
   [§3.0](#30-before-you-grant-confirm-you-can-assign-roles) and the
   [MCA‑E note](#mca-e-ea-migrated-accounts-portal-vs-api).
5. **Invoice section *display names* ≠ API names.** In the portal you see friendly
   names like "Accenture1" but the API (and Terraform `invoice_section_name`) requires
   the **GUID** (e.g. `eaed06d4-...`). Always use `scripts/discover_billing_scopes.sh`
   or the invoice sections list API to get the real name before wiring it into config.
   Using the display name will produce a `404` or `InvalidBillingAccountName` error.
6. **Cancelling a test subscription requires Azure RBAC Owner — not just a billing
   role.** The `POST .../providers/Microsoft.Subscription/cancel` API call is an
   Azure RBAC operation on the subscription, not a billing operation. If the SP (or
   your user) only holds "Azure subscription creator" (a billing role), the cancel will
   return `404` or `AuthorizationFailed`. Assign **Owner** on the subscription first:
   `az role assignment create --role Owner --assignee-object-id <OID> --scope /subscriptions/<id>`

---

## 1. Prerequisites

| To do this... | You need... |
|---|---|
| Create the app + SP | Permission to register apps (Application Developer, or have an admin do it) |
| **Grant the SP its billing role** | An **effective** owner at the scope: **Invoice section owner** (or Billing profile / Billing account owner) **with manage‑access**. Verify first with `scripts/check_billing_access.sh` — a "Billing account owner" *record* is not always effective (see [MCA‑E note](#mca-e-ea-migrated-accounts-portal-vs-api)). |
| Run the automation | The SP itself, after the role is granted |

Tools: `az` (logged in), and Terraform ≥ 1.5 for the Terraform path.

---

## 2. Create the service principal

### 2a. Portal path (recommended for first-time setup)

1. Go to **portal.azure.com** → switch to the correct tenant (top-right corner)
2. Search **"App registrations"** → **+ New registration**
   - Name: `ea2mca-sub-automation` · Supported account types: Single tenant → **Register**
3. On the app page, copy: **Application (client) ID** and **Directory (tenant) ID**
4. Left menu → **Certificates & secrets** → **+ New client secret** → Add → **copy the Value immediately**
5. Now get the **SP object ID** (this is what the billing role needs — not the app ID):
   - Search **"Enterprise applications"** → find `ea2mca-sub-automation` → copy **Object ID**

### 2b. CLI path

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

### 3.0 Before you grant: confirm YOU can assign roles

The grant only works if **you** are an *effective* owner at the scope. Check first —
this is read‑only and saves you from a confusing `403` loop:

```bash
scripts/check_billing_access.sh \
  --billing-account "<BA>" --billing-profile "<BP>" --invoice-section "<IS>"
```

- **Q1 (create)** lists the invoice sections you can create subscriptions under.
- **Q2 (delegate)** is the one that matters here: if you are not an effective owner,
  the grant below will fail with `AuthorizationFailed` on
  `billingRoleAssignments/write` — and **retrying or re‑logging in will not fix it**.
  A billing **owner** must either grant the SP the role, or grant **you** *Invoice
  section owner* first (see the [MCA‑E note](#mca-e-ea-migrated-accounts-portal-vs-api)).

### 3.1 Grant

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
role in many tenants — **but the GUID is not universal** (e.g. on the MCA‑E account we
tested it was `30000000-aaaa-bbbb-cccc-100000000006`). That's exactly why the script
resolves the role **by name** against the scope's `billingRoleDefinitions` instead of
hardcoding a GUID.
</details>

**Portal alternative:** Cost Management + Billing → select the **invoice section** →
**Access control (IAM)** → **Add** → role *Azure subscription creator*. Note: the
billing IAM portal reliably supports adding **users/groups**; adding a **service
principal/app** to a billing role is best done via the CLI/API above. So a common,
reliable pattern is: in the portal, add **yourself** as *Invoice section owner*, then
run the CLI grant for the SP.

### MCA-E (EA-migrated) accounts: portal vs API

On **MCA‑E** accounts (an EA migrated to MCA — `accountType=Enterprise`,
`agreementType=MicrosoftCustomerAgreement`), a **"Billing account owner" record may not
be effective** for `billingRoleAssignments/write` through the ARM Billing API, even
though billing admin works in the portal/EA experience. Symptoms we confirmed on a live
MCA‑E account:

- `listInvoiceSectionsWithCreateSubscriptionPermission` → you **can create** subscriptions.
- `assign_billing_role.sh ... --apply` → **403** `AuthorizationFailed` on
  `billingRoleAssignments/write`, on both `2024-04-01` and `2019-10-01-preview`, with a
  brand‑new token (so it is **not** a stale‑token issue).

**Resolution:** have an **effective** billing owner add the assignment **in the Azure
portal** (where EA/MCA‑E billing admin rights apply) — either grant the SP the role, or
grant **you** *Invoice section owner*. Once you hold effective ownership, refresh your
`az login` and the CLI grant works.

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
| `403 AuthorizationFailed` on **`billingRoleAssignments/write`** when **you** grant the SP | **You** are not an effective owner at that scope (a non‑effective "Billing account owner" record on MCA‑E, or only subscription‑creator). Re‑login does **not** fix it | Run `check_billing_access.sh`; have an effective billing owner grant the SP (portal/API), or grant **you** *Invoice section owner* first. See the [MCA‑E note](#mca-e-ea-migrated-accounts-portal-vs-api) |
| Role assignment for the SP fails | Missing `principalTenantId` | Re‑run with `--principal-tenant-id "$TENANT_ID"` |
| Works on old API, fails on latest | Latest‑API permission delegation | Have a billing admin delegate the role for the latest API |
| `az login` says "no subscriptions" | The SP only has a billing role (expected) | Add `--allow-no-subscriptions` |
| Alias returns existing sub / no change | Idempotency — alias reused | Use a new `subscription_alias_name` |

---

## Where this maps in the repo

- **Check your access first:** [`scripts/check_billing_access.sh`](../scripts/check_billing_access.sh)
- Grant role: [`scripts/assign_billing_role.sh`](../scripts/assign_billing_role.sh)
- Create (script): [`scripts/create_subscription.sh`](../scripts/create_subscription.sh)
- Create (Terraform): [`infra/terraform/`](../infra/terraform/README.md)
- CI template: [`.github/workflows/create-mca-subscription.yml`](../.github/workflows/create-mca-subscription.yml)
- Setup sequence + cleanup: [`csa-setup-runbook.md`](./csa-setup-runbook.md)
