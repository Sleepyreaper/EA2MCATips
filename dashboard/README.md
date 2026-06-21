# Dashboard

Static HTML/CSS/JS dashboard for EA to MCA migration handoff.

## Purpose

This dashboard visualizes the four required views for the CSA/customer deliverable set:

1. RBAC least-privilege matrix
2. EA to MCA API mapping
3. Billing hierarchy and invoice flow
4. Subscription-creation automation status

## Design rules

- No framework
- No package manager
- No bundler
- No backend
- No secrets required for offline review
- No unsupported certainty in UI claims

## Truthfulness model

Every RBAC/API/billing item should carry:

- `evidence_status`
- `source_ref_key`
- optional `docs_link_key`
- optional `uncertainty`

RBAC rows also separate:

- `recommended_role`
- `recommendation_status`

This prevents the UI from presenting a recommendation as a fully verified minimum when tenant validation is still pending.

## Run locally

Because the dashboard loads JSON files with `fetch()`, do **not** rely on opening `index.html` via `file://` in browsers that block local fetch access.

Use a trivial local HTTP server instead.

### Python example
