# MAP — Root / Infrastructure

## Purpose

Fast lookup from "thing to change" to "where it lives." Use before searching randomly.

## When to read

Whenever locating infra/DB files.

## Keep updated

When files or folders are added/moved/removed. (Detailed SQL-file tables live in [db/DB-MAP.md](./db/DB-MAP.md).)

## Directory overview

| Path | What lives here |
| --- | --- |
| `docker-compose.yml` | postgres + backend + frontend services |
| `database/init/` | First-boot SQL: `000-create-database`, `001-enums`, `002-tables`, `003-scheduling-functions` |
| `database/seeds/` | `001`..`005` reference + sample data |
| `database/migrations/` | Incremental schema changes (add new files only) |
| `database/docs/database-der.mmd` | ERD (Mermaid) |
| `scripts/` | Helper scripts |
| `README.md` | Root readme |

## Common needs → location

| Need | Location |
| --- | --- |
| Add/change a table | new file in `database/migrations/` (read `init/002-tables.sql` first) |
| Add an enum | new migration (see `init/001-enums.sql`) |
| Scheduling/availability logic | `init/003-scheduling-functions.sql` (`scheduling` schema) |
| Seed/reference data | `database/seeds/` |
| Run the stack / env vars | `docker-compose.yml` + `.env.*` (see ENVIRONMENT.md) |

## Entry points

- Stack: `docker-compose.yml`. DB bootstrap: `database/init/` (numeric order). Diagram: `database/docs/database-der.mmd`.

> Must reflect the real current infrastructure. Fix wrong/missing entries when found.
