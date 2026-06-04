# DATABASE-ARCHITECTURE

## Purpose

The database strategy: engine, bootstrap vs migrations, seeds, multi-tenancy.

## When to read

Before any schema or data change.

## Keep updated

When schema strategy, tenancy model, or bootstrap/migration approach changes.

## Engine & extensions

- PostgreSQL 16 (alpine). The `scheduling` schema holds availability/scheduling functions; application tables in the default schema.

## Schema lifecycle

- **`init/`** (first boot, mounted into `/docker-entrypoint-initdb.d`):
  - `000-create-database.sql` — database creation.
  - `001-enums.sql` — ~36 enum types (`*_enum`).
  - `002-tables.sql` — ~53 tables.
  - `003-scheduling-functions.sql` — `scheduling.*` functions.
- **`seeds/`** — reference + sample data (`001`→`005`), loaded after init.
- **`migrations/`** — incremental changes after the schema is deployed. **New files only; never edit init/applied SQL.**

## Multi-tenancy

- Tenant root is **business**; many entities are further scoped by **branch**. Isolation is modeled via tenant key columns + FKs and enforced by the backend (membership + permissions). Join tables (`worker_branches`, `branch_services`, `client_branches`, etc.) keep relationships tenant-consistent.

## Conventions

- `snake_case` tables/columns; enums suffixed `_enum`; numeric-prefixed file ordering.
- UUID/identity PKs, timestamps, and status enums per entity (see TABLES-GUIDE).

> Must reflect the real current database, not assumptions.
