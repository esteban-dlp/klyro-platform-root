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
| `branches` | Business locations. `type` (2026-07-03): `physical` (default, counted against the plan's `max_branches`) or `online` (singleton/exempt). Online appointments/holds remain branchless publicly, while this typed Online row owns their operational opening hours, timezone, and worker schedules. `services.service_location_mode` determines whether each service can use that channel. |
| `branch_opening_hours` | Regular opening hours per branch |
| `branch_availability_overrides`, `branch_availability_override_branches` | Exceptional branch availability |
| `workers`, `worker_aliases` | Staff who perform services |
| `worker_schedules` | Regular worker availability |
| `worker_availability_overrides`, `worker_availability_override_workers` | Exceptional worker availability |
| `worker_branches`, `worker_services` | Worker ↔ branch / service assignments |

## Catalog of offerings

| Table | Business meaning |
| --- | --- |
| `services`, `service_aliases` | Bookable services. `services.service_location_mode` (`BRANCH_ONLY`/`ONLINE_ONLY`/`HYBRID`, migration `2026-07-08-01-service-location-mode.sql`) defines whether a service is in-person, online-only, or both. |
| `branch_services` | Which physical branches offer a service. This table is explicit physical branch eligibility only; `ONLINE_ONLY` services should have no physical branch rows, and `HYBRID` services combine physical rows with the synthetic online channel. |
| `resources`, `resource_branches`, `service_resources`, `resource_unavailabilities`, `resource_unavailability_branches` | Capacity-limiting assets such as rooms, bays, or machines. `resources.name` must be at least 2 trimmed characters and `resources.icon_key` must use the same lowercase key format as the backend/UI (`^[a-z0-9_-]+$`) as of migration `2026-07-07-01-resource-validation-constraints.sql`. |

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
| `appointment_holds`, `appointment_hold_extras` | Short-lived, one-active-per-conversation scheduling holds. Holds store the same visible and blocked intervals used by final appointments. `branch_id` is nullable as of `2026-07-08-01-service-location-mode.sql` so online holds can be branchless. |
| `appointment_events` | State-change history of an appointment |
| `reminders` | Scheduled reminders for appointments |
| `business_reminder_settings` | Per-business email/WhatsApp reminder enablement and lead-hour preferences. |
| `business_public_booking_settings` | Per-business public "Booking by Link" page: whether it is enabled, its public URL slug (`booking_slug`, unique, separate from the dashboard slug), an optional brand theme color, optional email CTA button color/text-color overrides (else WCAG-derived from the theme color), and the "Powered by Klyro" footer toggle. Lets anyone book without logging in at `/book/<booking_slug>`; the theme + button colors also brand the confirmation/reminder emails sent to that business's clients. |
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
| `plans` | Pricing tiers. Credits model (2026-06-22): `profit_pct` + `infra_fixed_cents` derive `monthly_llm_credits` for paid tiers (1 credit = $0.001 cost); resource caps `max_workers`/`max_branches`/`max_services` (null = unlimited). Current packaging after 2026-07-02 recalibration: Free has 500 complimentary credits and WhatsApp enabled; Pro is $29 with 5,000 credits and 20 workers/3 branches/20 services; Max is $99 with 50,000 credits and unlimited resource caps. Dropped the old token/message/conversation limit columns. |
| `business_subscriptions` | A business's active plan + billing period (drives the usage period). |
| `usage_counters` | Metered usage per business per billing period: `llm_credits_used` (credits consumed), input/output tokens, `ai_requests_count`, `credits_alert_level` (80/95/100 one-shot owner alerts). Mutated ONLY via the `increment_usage_counter` function. |
| `model_cost_profiles` | Rolling empirical average credits/message per AI model (from `ai_token_usage`), for the "≈ N messages" plan estimate. |
| `ai_model_catalog` | Per-model informative USD pricing **per 1M tokens** (`input/output_cost_per_1m_usd`) plus optional `context_window_tokens`; includes DeepInfra's exact `google/gemma-4-26B-A4B-it` row at $0.07/$0.34 and the Google `gemini-3.1-flash-lite` / `gemini-3.6-flash` rows at their catalog prices. |
| `audit_logs` | Audit trail of significant actions |
| `error_logs` | Standalone production failure records from HTTP and outbox processing. Use `created_at` for direct incident queries; ids are soft references so logging survives rollbacks/deletions. |

Incident query:

```sql
SELECT created_at, level, source, operation, error_code,
       http_status, message, stack, request_id,
       business_id, conversation_id, outbox_event_id, context
FROM error_logs
ORDER BY created_at DESC;
```

> Keep descriptions business-focused. Verify columns against `002-tables.sql`. Must reflect the real current schema.
