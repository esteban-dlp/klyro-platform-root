# CONVENTIONS — Root / Infrastructure

## Purpose

Conventions for DB/infra so new SQL and config read like existing ones.

## When to read

Before writing SQL, migrations, seeds, or editing compose/env.

## Keep updated

When a convention is adopted, changed, or retired.

## SQL & file naming

- Numeric-prefixed, kebab-case SQL files for ordering (`001-enums.sql`, `002-tables.sql`, `004-message-templates.sql`).
- Enums named `*_enum`; the `scheduling` schema holds availability/scheduling functions.
- Tables, columns, constraints in `snake_case`.

## Schema changes

- New change → new migration file in `database/migrations/` (next number). **Never edit `init/` or applied migrations** unless explicitly instructed.
- Preserve enum-before-use and FK ordering.

## Seeds

- Reference data and sample data are seeded in order (`001`→`005`); enums/tables they depend on must exist first.

## Multi-tenancy

- Keep business/branch scoping in keys and constraints; sample data must respect tenant isolation.

## Docker / env

- Services on `klyro-network`; env via `.env.database` / `.env.backend` / `.env.frontend`. Never commit real secrets; document variables in ENVIRONMENT.md.

## Documentation

- Every new table/column/enum/index/function/trigger/constraint/seed must be documented in the `db/` guides, **business-focused** first.

> Must reflect how the real infra is actually built, not assumptions.
