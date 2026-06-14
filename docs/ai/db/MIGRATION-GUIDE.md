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

- Fresh volumes bootstrap through `database/init/`, seeds, and compose-mounted migrations.
- Existing volumes do not replay `/docker-entrypoint-initdb.d`; apply each new migration manually with `psql`.
- All schema changes use new files under `database/migrations/`; do not edit `init/` or applied migrations.

## Naming & order

- Date-prefixed, descriptive SQL filenames are used in `database/migrations/`; compose assigns the monotonically increasing execution number.

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
