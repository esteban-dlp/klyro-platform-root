# CURRENT-STATE — Root / Infrastructure

## Purpose

Snapshot of the infra/DB area right now.

## When to read

At the start of any task, after ARCHITECTURE.

## Keep updated

When schema, seeds, compose, or env setup changes.

## Status legend

✅ Done/stable · 🚧 In progress · 🧪 Experimental/partial · ❌ Broken · 📐 Planned

## State

| Item | Status | Notes |
| --- | --- | --- |
| Docker Compose (postgres/backend/frontend) | 🚧 | postgres healthcheck; backend `start:dev`; volumes mounted |
| DB init scripts | ✅ (present) | `000`→`003`; ~53 tables, ~36 enums, scheduling functions |
| Seeds | ✅ (present) | `001`→`005` (catalogs, security, operational types, templates, plans) |
| Migrations | ✅ (active) | Incremental SQL migrations are mounted after init/seeds; current compose order reaches `079-backfill-whatsapp-channel-accounts.sql` for legacy bootstrap, then the `migrations` service applies newer runner-only files directly from `backend/database/migrations`. Latest runner-only file: `2026-06-29-01-worker-free-windows-exclude-appointment.sql`, which lets `scheduling.worker_free_windows` ignore the appointment being rescheduled. |
| ERD | ✅ | `database/docs/database-der.mmd` |

## Known issues & debt

- Compose-mounted migration files run only on a fresh Postgres volume; apply new migrations manually to existing volumes.
- Confirm `.env.database` / `.env.backend` / `.env.frontend` are documented in ENVIRONMENT.md and not committed with secrets.

> Must reflect the real current infrastructure, not assumptions.
