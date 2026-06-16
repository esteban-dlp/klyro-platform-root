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
| Migrations | ✅ (active) | Incremental SQL migrations are mounted after init/seeds; current compose order reaches `079-backfill-whatsapp-channel-accounts.sql` (multi-channel messaging DB foundation: `business_channel_accounts`, `channel_onboarding_sessions`, `client_channel_identities`, `conversations` channel fields, `notifications.channel`, WhatsApp backfill). Existing volumes require manual `psql` application. Latest: runner-only (not compose-mounted) `2026-06-16-01-ai-response-length.sql` adds `ai_response_length_enum` + `business_ai_settings.response_length` (default `normal`). |
| ERD | ✅ | `database/docs/database-der.mmd` |

## Known issues & debt

- Compose-mounted migration files run only on a fresh Postgres volume; apply new migrations manually to existing volumes.
- Confirm `.env.database` / `.env.backend` / `.env.frontend` are documented in ENVIRONMENT.md and not committed with secrets.

> Must reflect the real current infrastructure, not assumptions.
