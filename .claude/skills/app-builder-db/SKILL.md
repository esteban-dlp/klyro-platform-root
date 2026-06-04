---
name: app-builder-db
description: Use for any database or root-level infrastructure work in the Klyro platform (PostgreSQL schema, .sql files, migrations, seeds, functions/triggers, Docker, env). Run AFTER the general app-builder skill. Enforces inspecting existing SQL first, never editing old migrations, business-focused documentation, tenant isolation, and updating the db + ENVIRONMENT docs.
---

# app-builder-db

Specialized skill for the **Klyro database and root-level infrastructure** (PostgreSQL under `database/` with `init/`, `migrations/`, `seeds/`; plus `docker-compose.yml` and `scripts/`).

**Prerequisite:** Run the general `app-builder` skill first (read `docs/ai/INDEX.md`, `ARCHITECTURE.md`, `CURRENT-STATE.md`, `MAP.md`, `CHANGES.md`). This skill adds DB/infra-specific rules.

## Step 1 — Read the general docs first

Complete the general `app-builder` workflow before DB/infra work.

## Step 2 — Read the db-specific docs

In `docs/ai/db/`:

1. [DATABASE-ARCHITECTURE.md](../../../docs/ai/db/DATABASE-ARCHITECTURE.md) — schema strategy, init vs migrations, tenancy.
2. [DB-MAP.md](../../../docs/ai/db/DB-MAP.md) — where SQL files and DB folders live.
3. [TABLES-GUIDE.md](../../../docs/ai/db/TABLES-GUIDE.md) — every table, in business terms.
4. [RELATIONSHIPS-GUIDE.md](../../../docs/ai/db/RELATIONSHIPS-GUIDE.md) — foreign keys and cardinality.
5. [MIGRATION-GUIDE.md](../../../docs/ai/db/MIGRATION-GUIDE.md) — how to add migrations safely.
6. [FUNCTIONS-TRIGGERS-GUIDE.md](../../../docs/ai/db/FUNCTIONS-TRIGGERS-GUIDE.md) — functions, triggers, constraints.
7. [SEEDING-GUIDE.md](../../../docs/ai/db/SEEDING-GUIDE.md) — seed files and order.

Also read `docs/ai/ENVIRONMENT.md` for Docker/env context.

## Step 3 — Database & infra rules

1. **Inspect existing `.sql` first.** Read the relevant files in `database/init/`, `database/migrations/`, and `database/seeds/` before proposing any schema change. Understand the current schema before adding to it.
2. **Never modify old migrations** unless explicitly instructed. Applied migrations are immutable history.
3. **Prefer new migration files** for schema changes. Add a new, ordered, clearly-named migration rather than editing init or past migrations.
4. **Document everything new.** Every new table, column, enum, index, function, trigger, constraint, or seed file must be documented in the db docs.
5. **Keep table descriptions business-focused.** Explain what a table means for the business (e.g. "an appointment a client books at a branch"), not only its columns.
6. **Preserve tenant/business isolation.** Maintain the multi-tenant boundary (business/branch scoping) in keys, constraints, and seeds when relevant.

## Step 4 — Update docs after changes

- `TABLES-GUIDE.md`, `RELATIONSHIPS-GUIDE.md`, `MIGRATION-GUIDE.md` — after any database change.
- `FUNCTIONS-TRIGGERS-GUIDE.md` — when functions/triggers/constraints change.
- `SEEDING-GUIDE.md` — when seed files change.
- `DB-MAP.md` — when SQL files or DB folders are added/moved/removed.
- `ENVIRONMENT.md` — when Docker, env vars, local setup, or deployment files change.
- Plus the general docs (`CHANGES.md`, `TASKS-LOG.md`, `CURRENT-STATE.md`, `DECISIONS.md`, `MAP.md`).

## Step 5 — Report

Per the general skill: files changed, decisions, risks, next steps. Flag any change that affects the backend's entities or the running stack.

## Checklist

- [ ] General app-builder workflow completed.
- [ ] Read db-specific docs + ENVIRONMENT.
- [ ] Inspected existing `.sql` before proposing changes.
- [ ] Did NOT edit old migrations; added a new migration if changing schema.
- [ ] Documented every new table/column/enum/index/function/trigger/constraint/seed (business-focused).
- [ ] Preserved tenant isolation.
- [ ] Updated TABLES/RELATIONSHIPS/MIGRATION/FUNCTIONS-TRIGGERS/SEEDING/DB-MAP/ENVIRONMENT + general docs.
