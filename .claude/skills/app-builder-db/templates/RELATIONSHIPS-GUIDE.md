# RELATIONSHIPS-GUIDE

> **Template.** Copy to `docs/ai/db/RELATIONSHIPS-GUIDE.md` and fill with real content. Delete this banner.

## Purpose

How tables relate: foreign keys, cardinality, and the tenant ownership chain. Helps avoid orphan data and broken isolation.

## When to read

Before adding FKs, joins, or cascade rules.

## Keep updated

- When relationships, foreign keys, or cascade behavior change.

## Relationship table

| From (FK) | To (PK) | Cardinality | On delete | Meaning |
| --- | --- | --- | --- | --- |

## Ownership / tenancy chain

<!-- How rows trace back to a business/branch (e.g. appointment → branch → business). -->

## ERD

<!-- Link to database/docs/database-der.mmd or embed a summary. -->

> Must reflect the real current relationships, not assumptions.
