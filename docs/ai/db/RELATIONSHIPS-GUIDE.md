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
 ├── clients ── client_branches, client_channel_identities
 ├── conversations ── messages ── message_attachments
 │    └── business_channel_account_id ── business_channel_accounts
 ├── appointments ── appointment_events, reminders, appointment_calendar_events
 ├── business_members ── users (+ roles ── role_permissions ── permissions)
 ├── business_ai_settings, business_whatsapp_accounts, message_templates
 ├── business_channel_accounts ── business_whatsapp_channel_accounts (1:1 detail), channel_onboarding_sessions, client_channel_identities
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
| `business_channel_accounts.(branch_id, business_id)` | `branches.(id, business_id)` | N:1 | no action | optional branch scoping (NULL = business-wide) |
| `conversations.business_channel_account_id` | `business_channel_accounts.id` | N:1 | no action | the channel account that received the conversation |
| `channel_onboarding_sessions.business_channel_account_id` | `business_channel_accounts.id` | N:1 | no action | the account provisioned by the onboarding attempt |
| `client_channel_identities.(client_id, business_id)` | `clients.(id, business_id)` | N:1 | no action | the client a channel participant resolves to |
| `client_channel_identities.business_channel_account_id` | `business_channel_accounts.id` | N:1 | no action | account that observed the participant (scopes the identity) |
| `business_whatsapp_channel_accounts.(channel_account_id, business_id)` | `business_channel_accounts.(id, business_id)` | 1:1 | no action | WhatsApp detail row of a parent channel account (UNIQUE `channel_account_id`) |
| `business_whatsapp_channel_accounts.(business_phone_number_id, business_id)` | `business_phone_numbers.(id, business_id)` | N:1 | no action | the WhatsApp business phone number (real composite FK; integrity preserved, not JSONB) |

## ERD

See `database/docs/database-der.mmd`.

> Must reflect the real current relationships, not assumptions.
