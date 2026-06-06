# TABLES-GUIDE

> **Template.** Copy to `docs/ai/db/TABLES-GUIDE.md` and fill with real content. Delete this banner.

## Purpose

Every table, described in **business terms** first, then key columns. So future sessions understand what data means, not just its shape.

## When to read

Before touching any table or writing a query.

## Keep updated

- When a table or column is added, changed, or removed.

## Tables

<!-- One block per table. Format: -->
<!--
### <table_name>
- **Business meaning:** what this represents for the business.
- **Tenant scope:** business/branch column(s), if any.
- **Key columns:** column — type — meaning.
- **Notable constraints/indexes:** ...
- **Defined in:** init/migration file.
-->

| Table | Business meaning | Tenant scope |
| --- | --- | --- |

> Keep descriptions business-focused. Must reflect the real current schema, not assumptions.
