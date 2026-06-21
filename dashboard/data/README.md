# Dashboard data contract

This directory contains the JSON payloads used by the static dashboard.

## Files

- `dashboard-data.sample.json` — sample content for RBAC, API mapping, and billing views
- `status.offline.json` — required offline/demo-safe automation status payload
- `status.real.sample.json` — optional sanitized sample of real-environment status data

## Loader behavior

`app.js` loads status in this order:

1. `status.real.sample.json`
2. `status.offline.json`

If the real-environment sample is absent or fails to load, the dashboard falls back to offline mode.

## Truthfulness requirements

Do not store unsupported certainty in these files.

Each RBAC, API, or billing item should include:

- `evidence_status`: one of
 - `documented`
 - `partially_documented`
 - `inferred`
 - `pending_validation`
- `source_ref_key`: short internal source identifier such as `docs.api_migration_01`
- `docs_link_key`: optional short link alias
- `uncertainty`: optional explanatory note

## RBAC item schema
