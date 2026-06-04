# ARCHITECTURE — Root / Infrastructure

## Purpose

How the root/infrastructure area is structured and why.

## When to read

At the start of any DB or infra task.

## Keep updated

When the stack topology, schema strategy, or orchestration changes.

## Tech stack

- **Database:** PostgreSQL 16 (alpine image).
- **Orchestration:** Docker Compose (`docker-compose.yml`) — services `postgres`, `backend`, `frontend` on a shared `klyro-network`.
- **Schema management:** raw SQL under `database/` — `init/` (first-boot), `seeds/` (reference + sample), `migrations/` (incremental changes).
- **Scripts:** `scripts/` for helper tasks.

## High-level structure

```
root/
  docker-compose.yml   postgres + backend + frontend
  database/
    init/              000-create-database, 001-enums, 002-tables, 003-scheduling-functions
    seeds/             001..005 reference + sample data
    migrations/        incremental schema changes (new files only)
    docs/              database-der.mmd (ERD)
  scripts/
  README.md
```

## Key patterns & boundaries

- **DB is schema source of truth.** Init SQL builds enums → tables → functions; backend entities map onto this. Changes go in NEW migration files; never edit applied ones.
- **First-boot ordering:** Compose mounts init + seed files into `/docker-entrypoint-initdb.d` in numeric order (enums before tables before functions, then seeds).
- **Multi-tenant isolation:** business/branch scoping is modeled in keys/constraints; preserve it in any change.
- **The `scheduling` schema** holds availability/conflict functions used by appointment logic.

## External dependencies & integrations

- Backend connects to `postgres` over `klyro-network`; frontend and backend are built from sibling folders.
- Environment via `.env.database`, `.env.backend`, `.env.frontend` (see ENVIRONMENT.md).

## Non-goals / constraints

- Don't edit historical migrations/init in ways that diverge from deployed DBs.
- Don't commit real secrets.

> Must reflect the real current infrastructure, not assumptions.
