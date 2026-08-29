# MIGRATION-GUIDE

## Dated AI price corrections

Price corrections must append a new `ai_model_prices` fact by closing the
currently open row and inserting a new effective row. Never update an applied
price amount in place, because usage events retain the applied `model_price_id`
for historical reconciliation. `2026-08-29-01-correct-ai-cache-prices.sql`
follows this rule for cached-input rates.

## Public appointment action audit constraint (2026-08-14)

`2026-08-14-01-appointment-event-client-creator-constraint.sql` replaces the original `appointment_events` creator check with the same authenticated-user rule plus support for `client` actors with a NULL dashboard user id. It is transaction-safe, runner-only and safe for existing rows; no Compose mount is needed.

## Current dashboard analytics indexes (2026-08-10)

`2026-08-10-01-dashboard-message-analytics-indexes.sql` is an idempotent runner-only migration. It creates partial active-record indexes for the tenant/date message aggregation and non-simulated conversation recency used by Home Activity. It does not alter tables, relationships or historical migrations, and does not need a Compose mount.

## Latest migration (2026-08-06)

`2026-08-06-12-map-plan-lemonsqueezy-ids.sql` maps the operator-approved
Lemon Squeezy product and purchasable variant ids to the existing `plans`
rows by stable plan code. It verifies all four target plans before updating
and verifies the complete mapping afterward. It is runner-only; the
`migrations` service discovers the folder directly.

`2026-08-06-13-conversation-simulation-mode.sql` adds the explicit
conversation transport mode and `2026-08-06-14-backfill-simulated-conversations.sql`
backfills legacy public-demo and simulator rows before real WhatsApp delivery
is enabled for demo businesses.

## Latest migration (2026-08-04)

`2026-08-04-01-messaging-operational-issues.sql` adds `messaging_operational_issues` and `message_delivery_holds`, their tenant/account/release indexes, validation checks and `updated_at` triggers. It is runner-only; the migrations service discovers the folder directly.

`2026-08-04-02-messaging-delivery-capacity.sql` adds persistent token buckets for distributed account and recipient throughput scheduling.

`2026-08-04-03-whatsapp-operational-notification.sql` idempotently seeds `whatsapp.operational_issue` and restores it if soft-deleted.

## Purpose

How to change the schema safely.

## When to read

Before any schema change.

## Keep updated

After adding a migration; when the process changes.

## Rules

- **Never edit `init/` or applied migrations** unless explicitly instructed — deployed databases must not diverge from history.
- **Prefer a new migration file** for every schema change.
- Preserve ordering (enums before use; FK dependencies) and tenant isolation in new keys/constraints.
- Document every new table/column/enum/index/function/trigger/constraint in the db guides.

## Current state

- **2026-08-17:** `2026-08-17-01-ai-simulator-single-session.sql` plus `2026-08-17-02-purge-retired-ai-simulator-sessions.sql` are runner-only migrations. Together they retire, then permanently purge, explicitly marked historical Test Agent sessions and synthetic dependencies, and create the partial unique index that permits one active simulator session per business. They do not modify real conversations or require a Compose mount.

- Latest migration: `backend/database/migrations/2026-07-30-08-public-ai-budgets.sql`. Adds `public_ai_budgets`, `public_ai_budget_daily`, `public_ai_budget_identity_daily`, `business_simulator_usage`, the simulator columns on `plan_versions`, and the atomic consume/settle functions. **Drops `guest_ai_daily_spend` and `demo_message_rate_limits`** — both held ephemeral daily state only. Verified functionally: exactly 20 of 25 attempts allowed for one device, another device unaffected, the money cap blocking before the message count, and a request denied for global exhaustion NOT consuming the identity's own quota.

- Previous: `backend/database/migrations/2026-07-30-07-ai-budget-pools.sql`. Adds `ai_budget_pools`, `ai_budget_pool_contributions` and `ensure_ai_budget_pool` / `record_pool_contribution` / `increment_pool_spend`. Runner-only, verified idempotent, and verified functionally: a replayed webhook contributes once (`record_pool_contribution` returns false), the platform grant accrues separately from contributions, and spend lands on the calendar month regardless of the date within it.

- Previous: `backend/database/migrations/2026-07-30-06-multimodal-limits-and-business-plan.sql`. Publishes version 2 of WhatsApp/WhatsApp Pro (650/1,650 after correcting the text-only cost sample for multimodal usage), adds the `whatsapp_business` plan ($99, 3,400 conversations, 3 WhatsApp numbers), `plan_versions.max_audio_minutes_monthly`, and the four audio/uplift settings. Version 1 is retired rather than edited. Runner-only, verified idempotent.

- Previous: `backend/database/migrations/2026-07-30-05-launch-plan-catalog.sql`, preceded by `2026-07-30-04-plan-versions-and-entitlements.sql`. `04` adds `plan_versions`, `subscription_entitlements`, `conversation_limit_runs` and `appointments.booking_surface`; `05` rewrites the catalog to the four launch plans and publishes version 1 of each. Both runner-only and verified idempotent. **Version 1 is deliberately backdated to epoch**: a version only needs a real effective date to protect a cycle already in flight from a limit that changed underneath it, and version 1 has nothing to protect against — dating it `now()` left every already-started cycle with no version in force, silently dropping every business to the Free floor (found by live verification).

- Previous: `backend/database/migrations/2026-07-30-03-ai-usage-ledger.sql`. Adds `ai_cost_kind_enum`/`ai_model_source_enum`/`pool_kind_enum`, `ai_usage_events`, `ai_conversation_windows`, `business_ai_usage_periods`, and the three SQL mutators. Runner-only, verified idempotent, and verified functionally in SQL: 20 concurrent opens produce exactly one window, a 25h gap opens a second, the fully-loaded cost splits correctly by `cost_kind`, `attempt_id` UNIQUE rejects a duplicate charge, and `3 x 0.00000001` sums to exactly `0.00000003` with no float drift.

- Previous: `backend/database/migrations/2026-07-30-02-ai-model-prices-and-runtime-assignments.sql`. Adds the `ai_runtime_enum` type, `ai_model_prices` (dated prices, backfilled from `ai_model_catalog` using each row's own `created_at`) and `ai_runtime_assignments` (seeded from the env values in force), and makes the four `business_ai_settings` model columns nullable. `ai_model_catalog` KEEPS its price columns for now — the credits path is not retired until phase 9 — but nothing reads them any more, because the backend moved every price read to `ai_model_prices` in the same phase to avoid a dual-write hazard. Runner-only, verified idempotent.

- Previous: `backend/database/migrations/2026-07-30-01-platform-settings.sql`. Adds `platform_settings` + `platform_settings_audit`, two trigger functions (`platform_settings_bump_version`, `platform_settings_write_audit`) and seeds the 18 launch knobs. Runner-only (no compose mount), fully idempotent — verified by applying it twice against a populated local database with no drift. First migration of the plans/limits/budgets-in-USD programme.

- Previous latest: `backend/database/migrations/2026-07-21-09-ai-model-catalog-deepinfra-gemini-flash-models.sql`. It registers `deepinfra/google/gemini-3.1-flash-lite` at $0.25/$1.50 and `deepinfra/google/gemini-3.5-flash` at $1.50/$9.00 per 1M input/output tokens, with 1,000,000-token context metadata. It is mounted as Compose order `094`; existing volumes apply it through the migration runner. The preceding `08` migration contains the separate Google-provider rows.

- `backend/database/migrations/2026-07-15-02-auth-provider-identity-unique.sql` adds the active external auth identity unique index. It is runner-only and safe to apply without deleting volumes.

- `backend/database/migrations/2026-07-15-01-error-logs.sql` adds the standalone `error_logs` table plus time/business indexes. It is mounted as compose `091`; existing volumes must apply it through the migration runner or `psql`.

- Previous runner migration before the 2026-07-21 provider/catalog changes: `backend/database/migrations/2026-07-12-02-dashboard-appointment-indexes.sql` adds two partial indexes on `appointments` (`business_id, start_at` and `business_id, status, start_at`, both `WHERE deleted_at IS NULL AND is_simulated = false`) backing the aggregated dashboard endpoint's tenant-scoped, time-windowed reads. `CREATE INDEX IF NOT EXISTS`, no table rewrite, safe on a populated DB; not a compose mount (post-cutoff runner migration).
- `backend/database/migrations/2026-07-08-02-business-reminder-settings.sql` adds per-business appointment-reminder preferences.
- Latest service-location migration: `backend/database/migrations/2026-07-08-01-service-location-mode.sql` adds `services.service_location_mode`, allows `appointment_holds.branch_id` to be nullable for online holds, and backfills legacy branch/online service state. It is a normal runner migration; `root/docker-compose.yml` is not updated for it.
- Fresh volumes bootstrap through `database/init/`, seeds, and compose-mounted migrations. The compose mount order currently reaches `079-backfill-whatsapp-channel-accounts.sql` (the 2026-06-15 multi-channel batch uses the `NN` sequence prefix, backfill last).
- Existing volumes do not replay `/docker-entrypoint-initdb.d`; apply each new migration manually with `psql` (the local `migrations` service runs `migrate.js`, which reads the folder directly in filename order).
- All schema changes use new files under `database/migrations/`; do not edit `init/` or applied migrations.
- Enum `ADD VALUE` migrations (e.g. `2026-06-15-05-message-channel-instagram-enum.sql`) must NOT be transaction-wrapped, and the new value cannot be used in the same transaction that added it — keep such statements isolated in their own migration.

## Naming & order

- **MANDATORY filename format: `YYYY-MM-DD-NN-short-kebab-description.sql`** — `NN`
  is a two-digit sequence per date (`01`, `02`, …). Migrations apply in filename
  order both on Railway (`migrate.js` sorts by filename) and in local initdb, so
  the date alone is insufficient: same-day files otherwise sort alphabetically by
  description and a backfill can run before its table. **Order `NN` by dependency**
  (enums → tables → FK/detail tables → seeds → INSERT/backfill **last**).
- Never rename/renumber an applied migration (the runner tracks applied files by
  filename → a rename re-runs it). Pre-`NN` historical files are grandfathered.

## How migrations run

- Fresh volume: Docker runs ordered mounts in `/docker-entrypoint-initdb.d`.
- Existing volume: run the migration with `psql` against the `klyro` database; migrations are written to be idempotent.

## Adding a migration — checklist

- [ ] Read current schema (`init/002-tables.sql` + existing migrations) first.
- [ ] Created a new, correctly-ordered, descriptively-named file in `database/migrations/`.
- [ ] Did NOT modify `init/` or existing migrations.
- [ ] Preserved tenant isolation.
- [ ] Updated TABLES/RELATIONSHIPS/FUNCTIONS-TRIGGERS/DB-MAP as relevant.
- [ ] Considered backend TypeORM entity impact (flag to backend).

> Must reflect the real current migration process, not assumptions.

## Zernio WhatsApp migrations (2026-08-22)

- Apply `2026-08-22-01` through `04` in numeric order through the normal migration service. The enum value is isolated in its own file; later files may safely reference `zernio`.
- `business_whatsapp_accounts` accepts `credential_source = project_env` only for Kapso and Zernio. `conversations.provider_conversation_id` is nullable and is populated only by conversation-addressed transports.
