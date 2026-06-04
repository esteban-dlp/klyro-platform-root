# DATABASE-ARCHITECTURE

> **Template.** Copy to `docs/ai/db/DATABASE-ARCHITECTURE.md` and fill with real content. Delete this banner.

## Purpose

The database strategy: engine, how the schema is bootstrapped (`init/`) vs evolved (`migrations/`), how seeds work, and how multi-tenancy is enforced.

## When to read

Before any schema or data change.

## Keep updated

- When the schema strategy, tenancy model, or bootstrap/migration approach changes.

## Engine & extensions

<!-- PostgreSQL version, extensions used. -->

## Schema lifecycle

<!-- init/ (first-time setup: enums, tables, functions) vs migrations/ (incremental changes) vs seeds/ (reference + sample data). When each runs. -->

## Multi-tenancy

<!-- How business/branch isolation is modeled (tenant key columns, FKs, constraints). -->

## Conventions

<!-- Naming (tables, columns, enums, indexes, constraints), primary keys (uuid?), timestamps, soft deletes. -->

> Must reflect the real current database, not assumptions.
