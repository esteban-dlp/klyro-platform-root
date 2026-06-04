# DECISIONS — Root / Infrastructure

## Purpose

Lightweight decision log (ADR-style) for infra/DB.

## When to read

When a change touches an architectural choice, or you're tempted to "do it differently."

## Keep updated

Add an entry for every non-trivial technical decision; supersede rather than delete.

## Decisions

### 2026-06-02 — Database is the schema source of truth (raw SQL)
- **Context:** Need an authoritative schema independent of ORM specifics.
- **Decision:** Schema is defined in raw SQL under `database/` (`init/` for first boot, `migrations/` for changes); backend TypeORM entities map onto it.
- **Rationale:** Explicit, reviewable schema; portable; clear ordering.
- **Consequences:** Schema changes are SQL-first; keep entities in sync.
- **Status:** accepted (observed).

### 2026-06-02 — New migrations only; never edit applied SQL
- **Context:** Deployed databases must not diverge from history.
- **Decision:** All schema changes go in new, ordered migration files; `init/` and applied migrations are immutable.
- **Rationale:** Safe, reproducible evolution.
- **Consequences:** Even small tweaks become a new migration.
- **Status:** accepted.

### 2026-06-02 — Compose-driven local stack with ordered init mounts
- **Context:** One-command local environment.
- **Decision:** `docker-compose.yml` runs postgres/backend/frontend; init + seed SQL mounted into `/docker-entrypoint-initdb.d` in numeric order.
- **Rationale:** Deterministic first-boot schema + seed.
- **Consequences:** File ordering (enums → tables → functions → seeds) must be preserved.
- **Status:** accepted.

<!-- New decisions above this line. -->

> Must reflect real decisions, not assumptions.
