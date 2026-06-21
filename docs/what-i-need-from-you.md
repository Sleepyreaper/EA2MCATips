# What I Need From You

Use this intake checklist before wiring any real test environment. Do not commit filled-in secrets, tenant-specific billing identifiers, `.tfvars`, state, or plan files to the repository.

> This form captures the **customer-supplied values**. For the **tools, roles, and
> access *you* need to run each workflow**, see the
> [readiness checklist](./readiness-checklist.md).

## Customer and tenant

- [ ] **Tenant ID:** `________________________________________`
- [ ] **MCA billing account ID/name:** `________________________________________`
- [ ] **Billing profile ID/name:** `________________________________________`
- [ ] **Invoice section ID/name:** `________________________________________`

## Subscription creation target

- [ ] **Target region:** `________________________________________`
- [ ] **Subscription display-name convention:** `________________________________________`
- [ ] **Approved test billing scope:** `________________________________________`
- [ ] **Cleanup / rollback plan for disposable subscriptions:** `________________________________________`

## Automation identity

- [ ] **Service principal app ID:** `________________________________________`
- [ ] **Service principal object ID for billing role assignment:** `________________________________________`
- [ ] **Credential approach:**
  - [ ] Secret
  - [ ] Certificate
  - [ ] Federated credential
  - [ ] Other approved method: `________________________________________`
- [ ] **Where credentials will be supplied from:** `________________________________________`

## Implementation preference

- [ ] **Terraform provider preference:**
  - [ ] AzureRM only
  - [ ] AzAPI acceptable
  - [ ] Decide after provider validation
- [ ] **AzureRM provider version to validate, if applicable:** `________________________________________`

## Reporting and exports

- [ ] **Test storage account target for Cost Management exports:** `________________________________________`
- [ ] **Is Power BI direct connector testing in scope?**
  - [ ] Yes
  - [ ] No
  - [ ] Not yet decided
- [ ] **Approved Power BI test user/persona:** `________________________________________`

## Existing automation assessment

List existing EA automations/scripts that must be assessed for breakage:

| Automation/script | Owner | EA dependency suspected | MCA replacement candidate | Notes |
|---|---|---|---|---|
| `________________________________` | `________________________________` | `________________________________` | `________________________________` | `________________________________` |
| `________________________________` | `________________________________` | `________________________________` | `________________________________` | `________________________________` |
| `________________________________` | `________________________________` | `________________________________` | `________________________________` | `________________________________` |

## Approval checkpoints

- [ ] Customer approved the test tenant and non-production billing scope.
- [ ] Customer approved least-privilege role assignments.
- [ ] Human approval is required before any subscription create action.
- [ ] Sanitized evidence format is agreed before testing.
