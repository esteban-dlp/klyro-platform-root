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

- Schema is currently bootstrapped via `database/init/`. `database/migrations/` has only a README.
- Once the database is deployed, **all** schema changes must move to `migrations/` (do not keep editing `init/`).

## Naming & order

- Numeric-prefixed, kebab-case: `NNN-description.sql`, monotonically increasing.

## How migrations run

- _Document the real runner_ (e.g. manual `psql`, a script in `scripts/`, or container init). Until then, init SQL runs on first postgres boot via the compose mounts.

## Adding a migration — checklist

- [ ] Read current schema (`init/002-tables.sql` + existing migrations) first.
- [ ] Created a new, correctly-ordered, descriptively-named file in `database/migrations/`.
- [ ] Did NOT modify `init/` or existing migrations.
- [ ] Preserved tenant isolation.
- [ ] Updated TABLES/RELATIONSHIPS/FUNCTIONS-TRIGGERS/DB-MAP as relevant.
- [ ] Considered backend TypeORM entity impact (flag to backend).

> Must reflect the real current migration process, not assumptions.
