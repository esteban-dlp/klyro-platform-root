# CURRENT-STATE — Root / Infrastructure

**2026-08-17 AI Simulator session migration:** the database now supports one reusable active Test Agent conversation per business. The runner-only migration pair performs the one-time scoped cleanup/purge and creates the partial unique index; no init or Compose change is needed.

**2026-08-14 appointment-action audit constraint:** migration `2026-08-14-01-appointment-event-client-creator-constraint.sql` aligns `appointment_events` with the already-deployed `client` creator enum value. Public client mutations can now record audit history without a dashboard user id; normal `user` events remain required to reference a user.

**2026-08-13 effective response capacity:** the runner now includes a compatibility migration that converts stale trial rows when an active plan owns monthly response capacity and updates the atomic consumption function to honor that precedence. No table shape or Compose mount changed.

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

The automated-response program is implemented through the public catalog, runtime enforcement, prepaid packs, client limits, trials, notifications, reconciliation, dashboard and landing. Production data mutation remains deliberately pending the owner-reviewed dry run: migration `10` backfills approved historical facts and migration `11` maps operator-created Lemon Squeezy variants. See `AUTOMATED-RESPONSES-ROLLOUT.md`.

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
