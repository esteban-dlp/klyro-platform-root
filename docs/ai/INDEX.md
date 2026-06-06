# INDEX — Root / Infrastructure AI Documentation

## Purpose

Entry point for any Claude Code session working at the **root / infrastructure** level of the Klyro platform: the PostgreSQL database, Docker, environment, and orchestration scripts. Read first.

## When to read

**First, always**, before any DB or infra task. Pair with the `app-builder` and `app-builder-db` skills.

## What this area is

The root area owns the **PostgreSQL database** (`database/init`, `database/migrations`, `database/seeds`, `database/docs`), the **Docker Compose** stack (`docker-compose.yml` wiring postgres + backend + frontend), and **scripts/**. The database is the source of truth for the schema; the backend's TypeORM entities map to it. The platform is multi-tenant (business/branch isolation).

## Reading order

1. [ARCHITECTURE.md](./ARCHITECTURE.md)
2. [CURRENT-STATE.md](./CURRENT-STATE.md)
3. [MAP.md](./MAP.md)
4. [CHANGES.md](./CHANGES.md)
5. [ENVIRONMENT.md](./ENVIRONMENT.md)
6. [CONVENTIONS.md](./CONVENTIONS.md)
7. [DECISIONS.md](./DECISIONS.md)
8. [ROADMAP.md](./ROADMAP.md)
9. [TASKS-LOG.md](./TASKS-LOG.md)

## DB-specific docs (`db/`)

- [DATABASE-ARCHITECTURE.md](./db/DATABASE-ARCHITECTURE.md)
- [DB-MAP.md](./db/DB-MAP.md)
- [TABLES-GUIDE.md](./db/TABLES-GUIDE.md)
- [RELATIONSHIPS-GUIDE.md](./db/RELATIONSHIPS-GUIDE.md)
- [MIGRATION-GUIDE.md](./db/MIGRATION-GUIDE.md)
- [FUNCTIONS-TRIGGERS-GUIDE.md](./db/FUNCTIONS-TRIGGERS-GUIDE.md)
- [SEEDING-GUIDE.md](./db/SEEDING-GUIDE.md)

> These docs must reflect the real current codebase. If reality differs, fix the docs.
