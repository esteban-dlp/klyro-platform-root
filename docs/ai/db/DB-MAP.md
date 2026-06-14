# DB-MAP

## Purpose

Locate database files fast.

## When to read

Whenever finding a SQL file or DB folder.

## Keep updated

When SQL files or folders are added/moved/removed.

## Folders

| Path | What lives here |
| --- | --- |
| `database/init/` | First-boot scripts (enums, tables, functions) |
| `database/migrations/` | Incremental, idempotent schema changes for deployed/existing databases |
| `database/seeds/` | Reference & sample data |
| `database/docs/` | `database-der.mmd` (ERD) |

## Init scripts (in order)

| File | Purpose |
| --- | --- |
| `000-create-database.sql` | Create database |
| `001-enums.sql` | ~36 enum types |
| `002-tables.sql` | ~53 tables |
| `003-scheduling-functions.sql` | `scheduling.*` availability/conflict functions |

## Migrations (in order)

| File | Purpose | Applied? |
| --- | --- | --- |
| `2026-06-13-appointment-blocked-intervals.sql` | Adds appointment/hold blocked intervals and updates scheduling conflict functions (compose `060`) | New volumes automatically; existing volumes manually |

## Seeds (in order)

| File | Purpose |
| --- | --- |
| `001-seed-general-catalogs.sql` | General catalogs (currencies, countries, languages, ...) |
| `002-seed-security.sql` | Roles, permissions, role_permissions |
| `003-seed-operational-types.sql` | Operational reference types |
| `004-seed-message-templates.sql` | Message templates |
| `005-seed-plans.sql` | Billing plans |

> Must reflect the real current database files, not assumptions.
