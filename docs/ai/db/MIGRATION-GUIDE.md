# MIGRATION-GUIDE

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
