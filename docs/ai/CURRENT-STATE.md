# CURRENT-STATE — Root / Infrastructure

## Purpose

Snapshot of the infra/DB area right now.

## When to read

At the start of any task, after ARCHITECTURE.

## Keep updated

When schema, seeds, compose, or env setup changes.

## Status legend

**Database:** Pending migration `2026-07-15-02-auth-provider-identity-unique.sql` adds active external identity uniqueness. Existing global lowercased email uniqueness remains the cross-provider boundary.

✅ Done/stable · 🚧 In progress · 🧪 Experimental/partial · ❌ Broken · 📐 Planned

## State

The response-billing foundation (migrations `2026-08-06-01` through `06`) is additive and runner-only: immutable response evidence, prepaid credit accounting, client controls, trials, webhook idempotency and operator economics now have database contracts. Application enforcement is intentionally deferred to later implementation phases.

| Item | Status | Notes |
| --- | --- | --- |
| Docker Compose (postgres/backend/frontend) | 🚧 | postgres healthcheck; backend `start:dev`; volumes mounted. **2026-07-12:** backend no longer overrides `DATABASE_URL` with an invalid empty value, so its valid URL or documented discrete DB credentials can boot the service. |
| DB init scripts | ✅ (present) | `000`→`003`; ~53 tables, ~36 enums, scheduling functions |
| Seeds | ✅ (present) | `001`→`005` (catalogs, security, operational types, templates, plans) |
| Migrations | ✅ (active) | Incremental SQL migrations are mounted after init/seeds; current compose order reaches `094-ai-model-catalog-deepinfra-gemini-flash-models.sql`, while the `migrations` service applies newer files directly from `backend/database/migrations`. The catalog includes Google Gemini rows plus DeepInfra's exact `google/...` model mappings and current per-1M-token prices. |
| ERD | ✅ | `database/docs/database-der.mmd` |

## Known issues & debt

- Compose-mounted migration files run only on a fresh Postgres volume; apply new migrations manually to existing volumes.
- Confirm `.env.database` / `.env.backend` / `.env.frontend` are documented in ENVIRONMENT.md and not committed with secrets.

> Must reflect the real current infrastructure, not assumptions.
