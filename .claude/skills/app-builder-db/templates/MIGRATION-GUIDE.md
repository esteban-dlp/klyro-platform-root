# MIGRATION-GUIDE

> **Template.** Copy to `docs/ai/db/MIGRATION-GUIDE.md` and fill with real content. Delete this banner.

## Purpose

How to change the schema safely: create new migrations, never edit applied ones, naming/order, and how migrations run.

## When to read

Before any schema change.

## Keep updated

- After adding a migration; when the migration process changes.

## Rules

- **Never edit old/applied migrations** unless explicitly instructed.
- **Prefer a new migration file** for every schema change.
- Migrations are ordered and immutable once applied.
- Preserve tenant isolation in new keys/constraints.

## Naming & order

<!-- Convention, e.g. NNN-description.sql, monotonically increasing. -->

## How migrations run

<!-- How/when they execute (manual, on container start, via script). -->

## Adding a migration — checklist

- [ ] Inspected current schema (init + existing migrations).
- [ ] Created a new, correctly-ordered, descriptively-named file.
- [ ] Did not modify existing migrations.
- [ ] Updated TABLES/RELATIONSHIPS/FUNCTIONS-TRIGGERS/DB-MAP as relevant.
- [ ] Considered backend entity impact.

> Must reflect the real current migration process, not assumptions.
