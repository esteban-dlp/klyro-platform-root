# TABLES-GUIDE

## Purpose

Every table, **business meaning** first. Source: `database/init/002-tables.sql`.

## When to read

Before touching any table or writing a query.

## Keep updated

When a table or column is added, changed, or removed. Add a detailed block per table over time.

## Reference / catalog tables

| Table | Business meaning |
| --- | --- |
| `currencies`, `countries`, `phone_prefixes`, `languages` | Global reference data |
| `business_types` | Categories of business |
| `payment_providers` | Supported payment providers |
| `availability_override_types`, `notification_types`, `outbox_event_types` | Operational type catalogs |

## Identity & tenancy

| Table | Business meaning |
| --- | --- |
| `users` | People who can log in |
| `businesses` | Tenants (companies on Klyro) |
| `business_phone_numbers` | Phone numbers owned by a business |
| `roles`, `permissions`, `role_permissions` | RBAC definitions |
| `business_members` | A user's membership + role in a business |
| `business_invitations`, `business_invite_links`, `business_invite_link_uses` | Inviting users into a business |

## Locations & staff

| Table | Business meaning |
| --- | --- |
| `branches` | Business locations |
| `branch_opening_hours` | Regular opening hours per branch |
| `branch_availability_overrides`, `branch_availability_override_branches` | Exceptional branch availability |
| `workers`, `worker_aliases` | Staff who perform services |
| `worker_schedules` | Regular worker availability |
| `worker_availability_overrides`, `worker_availability_override_workers` | Exceptional worker availability |
| `worker_branches`, `worker_services` | Worker ↔ branch / service assignments |

## Catalog of offerings

| Table | Business meaning |
| --- | --- |
| `services`, `service_aliases` | Bookable services |
| `branch_services` | Which services a branch offers |

## Clients & conversations

| Table | Business meaning |
| --- | --- |
| `clients`, `client_branches` | Customers and their branch links |
| `conversations`, `messages`, `message_attachments` | WhatsApp/AI chat threads, messages, files |
| `message_templates` | Templated outbound messages |

## Scheduling

| Table | Business meaning |
| --- | --- |
| `appointments` | A booking (client + service + worker + branch + time) |
| `appointment_events` | State-change history of an appointment |
| `reminders` | Scheduled reminders for appointments |
| `calendar_connections`, `appointment_calendar_events` | External calendar sync |

## AI, WhatsApp, notifications

| Table | Business meaning |
| --- | --- |
| `business_ai_settings` | AI receptionist configuration per business |
| `business_whatsapp_accounts` | Connected WhatsApp accounts |
| `notifications`, `notification_preferences` | User notifications & prefs |
| `outbox_events` | Pending async events to dispatch |

## Billing & audit

| Table | Business meaning |
| --- | --- |
| `plans`, `business_subscriptions`, `usage_counters` | Pricing tiers, active subscriptions, metered usage |
| `audit_logs` | Audit trail of significant actions |

> Keep descriptions business-focused. Verify columns against `002-tables.sql`. Must reflect the real current schema.
