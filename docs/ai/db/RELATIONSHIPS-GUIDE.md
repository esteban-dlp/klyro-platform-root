# RELATIONSHIPS-GUIDE

## Purpose

How tables relate: foreign keys, cardinality, tenant ownership chain.

## When to read

Before adding FKs, joins, or cascade rules.

## Keep updated

When relationships, foreign keys, or cascade behavior change. Source of truth: `database/init/002-tables.sql` + `database/docs/database-der.mmd`.

## Ownership / tenancy chain

```
business
 ├── branches
 │    ├── branch_opening_hours, branch_availability_overrides
 │    └── branch_services ── services
 ├── workers ── worker_schedules, worker_branches, worker_services
 ├── clients ── client_branches
 ├── conversations ── messages ── message_attachments
 ├── appointments ── appointment_events, reminders, appointment_calendar_events
 ├── business_members ── users (+ roles ── role_permissions ── permissions)
 ├── business_ai_settings, business_whatsapp_accounts, message_templates
 ├── business_subscriptions ── plans;  usage_counters
 └── notifications, outbox_events, audit_logs
```

Most rows trace back to a **business** (and frequently a **branch**) — this enforces multi-tenant isolation.

## Key many-to-many joins

| Join table | Connects |
| --- | --- |
| `business_members` | businesses ↔ users (with role) |
| `role_permissions` | roles ↔ permissions |
| `worker_branches` | workers ↔ branches |
| `worker_services` | workers ↔ services |
| `branch_services` | branches ↔ services |
| `client_branches` | clients ↔ branches |
| `*_availability_override_*` | overrides ↔ branches/workers |

## Relationship table

> Fill exact FK columns / `ON DELETE` rules from `002-tables.sql`.

| From (FK) | To (PK) | Cardinality | On delete | Meaning |
| --- | --- | --- | --- | --- |
| `branches.business_id` | `businesses.id` | N:1 | _verify_ | a business has many branches |
| `appointments.*` | clients/workers/services/branches | N:1 each | _verify_ | a booking references these |

## ERD

See `database/docs/database-der.mmd`.

> Must reflect the real current relationships, not assumptions.
