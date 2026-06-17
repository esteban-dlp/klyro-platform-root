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
| `client_channel_identities` | Maps a channel participant (e.g. an Instagram user id) to a Klyro client, account-scoped, so contact resolution is deterministic for channels without a phone number |
| `conversations`, `messages`, `message_attachments` | Multi-channel (WhatsApp/Instagram/...)/AI chat threads, messages, files. `conversations` bind to `business_channel_accounts` via `business_channel_account_id`; `last_inbound_at` anchors the Instagram 24h window; `external_participant_id`/`participant_username` address parties on channels without a phone |
| `message_templates` | Templated outbound messages |

## Scheduling

| Table | Business meaning |
| --- | --- |
| `appointments` | A booking. `start_at`/`end_at` are customer-visible; `blocked_start_at`/`blocked_end_at` reserve worker capacity including service buffers. |
| `appointment_holds`, `appointment_hold_extras` | Short-lived, one-active-per-conversation scheduling holds. Holds store the same visible and blocked intervals used by final appointments. |
| `appointment_events` | State-change history of an appointment |
| `reminders` | Scheduled reminders for appointments |
| `calendar_connections`, `appointment_calendar_events` | External calendar sync |

## AI, WhatsApp, notifications

| Table | Business meaning |
| --- | --- |
| `business_ai_settings` | AI receptionist configuration per business. Includes owner-tunable voice settings such as `response_length` (`short`/`normal`/`detailed`, default `normal`) — how verbose the AI's client-facing messages are: `short` gives just the answer plus the one decision needed, `normal` adds key booking facts (service, worker) and is today's behavior, `detailed` adds full useful context (service, worker, duration, price, next step). Also `regional_style` (`varchar(20)`, CHECK `auto`/`neutral`/`gt`/`mx`/`co`/`ar`/`cl`/`es`, default `auto`) — a subtle regional Spanish register injected into the prompt, subordinate to the client's detected language (applies only when replying in Spanish; never slang/stereotype). `auto` derives the register from the business country when reachable, else neutral; `neutral`/`auto` reproduce prior behavior |
| `business_whatsapp_accounts` | Legacy WhatsApp accounts table. Kept during the multi-channel transition; superseded by `business_channel_accounts` and dropped only by a later contract migration. Secrets (`access_token_encrypted`, `webhook_secret_encrypted`, BYOA-ready `app_secret_encrypted`/`verify_token_encrypted`) are AES-256-GCM at rest and never returned; `access_token_last4`/`app_secret_last4` are non-secret masking hints |
| `business_channel_accounts` | Canonical, channel-agnostic messaging accounts a business connects (WhatsApp number, Instagram DM account, future channels) — the **parent** of the parent/detail model. One row per connected account, scoped by `(channel, inbound_routing_key)`. Encrypted-at-rest credentials + masking hints mirror the WhatsApp table; WhatsApp rows are backfilled (id-preserving). Common fields only — channel-specific relational fields live in detail tables, not in JSONB |
| `business_whatsapp_channel_accounts` | WhatsApp-only **detail** of a channel account (one-to-one with `business_channel_accounts` via UNIQUE `channel_account_id`). Holds the WhatsApp relational fields that keep real FKs — notably `business_phone_number_id` (composite FK to `business_phone_numbers`, integrity preserved, never JSONB) — plus `waba_id`, `meta_phone_number_id`, `display_phone_number` and a `metadata` JSONB for non-relational extras. Instagram uses the parent table only in Phase 1 (no detail table) |
| `channel_onboarding_sessions` | One row per "Connect <channel>" attempt; `state_nonce` is the single-use CSRF token; links to the provisioned `business_channel_accounts` row. Channel-generic mirror of `whatsapp_onboarding_sessions` |
| `notifications`, `notification_preferences` | User notifications & prefs. `notifications.channel` tags the messaging channel a notification relates to (nullable) |
| `outbox_events` | Pending async events to dispatch |

## Billing & audit

| Table | Business meaning |
| --- | --- |
| `plans`, `business_subscriptions`, `usage_counters` | Pricing tiers, active subscriptions, metered usage |
| `audit_logs` | Audit trail of significant actions |

> Keep descriptions business-focused. Verify columns against `002-tables.sql`. Must reflect the real current schema.
