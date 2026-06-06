# SEEDING-GUIDE

## Purpose

What the seed files populate, in what order, and which is reference vs sample data.

## When to read

Before adding/changing seed data or setting up a fresh environment.

## Keep updated

When seed files are added/changed/removed or their order changes.

## Seed files (in order)

| File | Populates | Type | Notes |
| --- | --- | --- | --- |
| `001-seed-general-catalogs.sql` | Currencies, countries, languages, phone prefixes, business types, etc. | reference | required global data |
| `002-seed-security.sql` | Roles, permissions, role_permissions | reference | permission codes referenced by tenant route guards |
| `003-seed-operational-types.sql` | Operational type catalogs (override/notification/outbox types) | reference | required for enums-as-rows |
| `004-seed-message-templates.sql` | Message templates | reference | default templates |
| `005-seed-plans.sql` | Billing plans | reference | subscription tiers |

## Ordering & dependencies

- Run after `init/` (enums + tables must exist).
- Catalogs and security come first; templates and plans depend on earlier reference data.

## Reference vs sample data

- The current seeds are **reference data** required for the app to function (catalogs, security, types, templates, plans).
- Any future **sample/demo** business data must respect tenant isolation (scoped to a demo business/branch) and be clearly separated from reference seeds.

> Must reflect the real current seed files, not assumptions.
