# CSA Setup Runbook — EA → MCA, with least privilege

A step-by-step walkthrough for a **Cloud Solution Architect (CSA)** to stand up an
EA→MCA test, **using elevated rights only for setup**, then handing the customer a
set of **least-privilege accounts** to test with.

The guiding rule: the CSA may hold powerful roles (Global Administrator, billing
account owner) **temporarily, to do setup** — but every account handed to the
customer for testing gets the **narrowest role at the smallest scope** that the
test needs. Nothing the customer tests with should be Owner or Global Admin.

---

## 0. Two different kinds of "admin" (read this first)

Setup touches **two separate permission systems**. Holding one does not grant the
other:

| Permission system | What it controls | Role used for setup |
|---|---|---|
| **Microsoft Entra ID** (directory) | Users, groups, service principals (the *identities*) | **Global Administrator** |
| **MCA billing** (Cost Management + Billing) | Billing accounts, profiles, invoice sections, **billing role assignments** | **Billing account owner** |
| **Azure RBAC** (resources) | Subscriptions, resource groups, resources | Owner / User Access Administrator |

> **Global Administrator is NOT automatically a billing administrator.** To assign
> the MCA billing roles in this runbook you must hold a **billing role** that can
> manage access — typically **billing account owner** (or owner/contributor at the
> target scope) ([billing roles](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles),
> [manage billing access](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/manage-billing-access)).
> A Global Admin *can* "elevate access" to get **User Access Administrator at the
> root scope** for Azure RBAC, but that still does not grant billing roles
> ([elevate access](https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin)).

So before you start, confirm you hold **both**: Global Administrator (for identities)
**and** billing account owner on the MCA billing account (for billing roles). If you
only have Global Admin, ask the customer's billing account owner to grant you a
billing role, or to run the billing-role steps for you.

---

## 1. Prerequisites

> Full per-workflow tool/role/input list: [readiness-checklist.md](./readiness-checklist.md).

- [ ] CSA has **Global Administrator** in the test tenant (prefer **just-in-time** via
      Privileged Identity Management, time-boxed — not standing).
- [ ] CSA holds **billing account owner** on the MCA billing account (or has a billing
      account owner available to assign roles).
- [ ] Azure CLI installed and `az login` completed.
- [ ] This repo cloned; scripts are executable (`chmod +x scripts/*.sh`).

---

## 2. Setup & configuration (CSA uses elevated rights — temporary)

### 2.1 Discover the billing hierarchy

Find the billing account / profile / invoice section names you'll scope roles to:

```bash
az login
scripts/discover_billing_scopes.sh --account "<BILLING_ACCOUNT_NAME>"
```

Record the `billing_account_name`, `billing_profile_name`, and `invoice_section_name`
for each area the customer will test. (Hierarchy background:
[MCA overview](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/mca-overview).)

### 2.2 Create the customer's test identities

Using your Global Admin rights, create dedicated **test identities** — one per role
you want to validate, so each proves a single least-privilege boundary. Do **not**
reuse high-privilege admin accounts for testing.

```bash
# Example: a finance test user (interactive sign-in)
az ad user create --display-name "EA2MCA Finance Tester" \
  --user-principal-name finance-tester@<tenant-domain> \
  --password '<set-a-strong-temp-password>' --force-change-password-next-sign-in true

# Example: a service principal for the subscription-creation automation test
az ad sp create-for-rbac --name "ea2mca-sub-creator-sp" --skip-assignment
# capture the appId and run: az ad sp show --id <appId> --query id -o tsv  (object ID)
```

> **Automating subscription creation with a service principal?** The full
> walkthrough — creating the SP, granting it the role with its **object ID**,
> authenticating, and running it in CI — is in
> [service-principal-automation-101.md](./service-principal-automation-101.md).

> Keep these identities clearly named (e.g. prefix `ea2mca-`) and time-boxed so they
> are easy to find and remove after testing. Do not embed their secrets in this repo.

### 2.3 (Only if Azure RBAC at root is needed) elevate access

If a test also needs Azure **resource** visibility across all subscriptions, a Global
Admin can temporarily elevate to **User Access Administrator at root**
([how-to](https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin)).
**Remove this elevation as soon as setup is done** (Section 5). Most MCA billing tests
do **not** need this.

---

## 3. Configure least-privilege accounts for the customer to test with

This is the core of the runbook: for each test scenario, grant the **narrowest** MCA
billing role at the **smallest** scope. Use the general helper
`scripts/assign_billing_role.sh` (dry-run by default — add `--apply` to commit), or the
portal path under **Cost Management + Billing → (scope) → Access control (IAM)**
([manage billing access](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/manage-billing-access)).

> **Prerequisite — confirm you can actually assign roles.** Run
> `scripts/check_billing_access.sh --billing-account <BA> --billing-profile <BP> --invoice-section <IS>`
> first. To *assign* billing roles you must be an **effective owner** (Invoice section
> owner / Billing profile / Billing account owner *with* manage-access). On **MCA‑E**
> (EA‑migrated) accounts a "Billing account owner" record may **not** be effective via
> the ARM API — if `--apply` returns `403` on `billingRoleAssignments/write`, add the
> assignment **in the Azure portal** (where EA/MCA‑E admin rights apply), or have an
> effective owner grant it. See [service-principal-automation-101 → MCA‑E note](./service-principal-automation-101.md#mca-e-ea-migrated-accounts-portal-vs-api).

| Customer test scenario | Test identity | Least-privilege role | Scope | Why |
|---|---|---|---|---|
| View / download invoices | finance-tester | **Invoice manager** | billing profile | Narrowest invoice-focused role ([billing roles](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)) |
| View a billing profile | profile-reader | **Billing profile reader** | billing profile | Read-only on the profile |
| View costs / reports for a department | cost-viewer | **Invoice section reader** | invoice section | Smallest billing scope for cost visibility |
| View costs across a profile's sections | finops-reader | **Billing profile reader** | billing profile | Cross-section read without account-wide reach |
| Create subscriptions (automation) | sub-creator-sp | **Azure subscription creator** | invoice section | Explicit delegated create role ([create sub](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement)) |

### 3.1 Assign with the script

```bash
# Invoice manager on a billing profile (preview, then --apply)
scripts/assign_billing_role.sh \
  --billing-account "<BA>" --billing-profile "<BP>" \
  --role "Invoice manager" --principal-id "<FINANCE_TESTER_OBJECT_ID>"

# Invoice section reader on an invoice section
scripts/assign_billing_role.sh \
  --billing-account "<BA>" --billing-profile "<BP>" --invoice-section "<IS>" \
  --role "Invoice section reader" --principal-id "<COST_VIEWER_OBJECT_ID>"

# Azure subscription creator on an invoice section (automation SP)
scripts/assign_billing_role.sh \
  --billing-account "<BA>" --billing-profile "<BP>" --invoice-section "<IS>" \
  --role "Azure subscription creator" --principal-id "<SP_OBJECT_ID>" --apply
```

(`scripts/assign_subscription_creator_role.sh` is a convenience shortcut for the last
one.) The script resolves the role **by name** against the scope's billing role
definitions ([billing role assignments REST](https://learn.microsoft.com/en-us/rest/api/billing/billing-role-assignments?view=rest-billing-2024-04-01)),
so there are no hardcoded role GUIDs.

### 3.2 Least-privilege guardrails

- Assign at the **smallest** scope that satisfies the test (invoice section before
  billing profile before billing account). Billing **account** roles inherit
  downward and cannot be removed lower — avoid them unless cross-profile reach is
  genuinely required ([billing roles](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)).
- Keep **billing roles** separate from **Azure RBAC** — granting a subscription Owner
  does not grant billing access, and vice-versa ([assign cost access](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/assign-access-acm-data)).
- One identity per boundary, so a failed/passed test maps to exactly one role.

---

## 4. Hand off to the customer and test

Give the customer the test identities (and the automation SP's credentials via a
secure channel — never via this repo). Have them run the per-surface checks in
[testing-strategy.md](./testing-strategy.md), confirming each identity **can** do its
intended task and **cannot** do anything broader. For the subscription-creation test,
use [subscription-automation.md](./subscription-automation.md) (Terraform or
`scripts/create_subscription.sh`).

---

## 5. Clean up — step back down to least privilege

When testing is done, remove the elevated standing access you used for setup:

- [ ] Remove any **root-scope User Access Administrator** elevation
      ([elevate access — remove](https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin)).
- [ ] Deactivate / remove **Global Administrator** (or let the PIM activation expire).
- [ ] Remove or disable the **test identities** and their billing role assignments
      once the customer has finished, unless they are intentionally kept for an
      ongoing pilot.
- [ ] Rotate or delete any service principal secrets created for the test.

> Standing Global Admin and billing account owner are setup tools, not an operating
> state. Leave the customer with only the least-privilege roles they validated.

---

## Quick reference — the flow

```
CSA (Global Admin + billing account owner, time-boxed)
  └─ discover billing scopes
  └─ create test identities (users + automation SP)
  └─ assign LEAST-PRIVILEGE billing role per test scenario  ← customer's test accounts
        ├─ Invoice manager            (billing profile)   → view/download invoices
        ├─ Billing profile reader     (billing profile)   → view profile + costs
        ├─ Invoice section reader     (invoice section)   → view department costs
        └─ Azure subscription creator (invoice section)   → create subscriptions
  └─ customer tests each surface (testing-strategy.md)
  └─ CSA removes elevation + cleans up
```
