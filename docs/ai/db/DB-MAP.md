# DB-MAP

## Purpose

Locate database files fast.

## When to read

Whenever finding a SQL file or DB folder.

## Keep updated

When SQL files or folders are added/moved/removed.

## Folders

| Path | What lives here |
| --- | --- |
| `database/init/` | First-boot scripts (enums, tables, functions) |
| `database/migrations/` | Incremental, idempotent schema changes for deployed/existing databases |
| `database/seeds/` | Reference & sample data |
| `database/docs/` | `database-der.mmd` (ERD) |

## Init scripts (in order)

| File | Purpose |
| --- | --- |
| `000-create-database.sql` | Create database |
| `001-enums.sql` | ~36 enum types |
| `002-tables.sql` | ~53 tables |
| `003-scheduling-functions.sql` | `scheduling.*` availability/conflict functions |

## Migrations (in order)

| File | Purpose | Applied? |
| --- | --- | --- |
| `2026-06-13-14-appointment-blocked-intervals.sql` | Adds appointment/hold blocked intervals and updates scheduling conflict functions (compose `060`) | New volumes automatically; existing volumes manually |
| `2026-06-15-05-message-channel-instagram-enum.sql` | Adds `message_channel_enum` value `instagram` + `channel_account_status_enum` + `channel_onboarding_status_enum` (compose `070`; not transaction-wrapped) | New volumes automatically; existing volumes manually |
| `2026-06-15-06-business-channel-accounts.sql` | Canonical channel-agnostic `business_channel_accounts` table (compose `071`) | New volumes automatically; existing volumes manually |
| `2026-06-15-07-business-whatsapp-channel-accounts.sql` | WhatsApp DETAIL table `business_whatsapp_channel_accounts` (1:1 FK to parent; composite FK `business_phone_number_id` → `business_phone_numbers`) (compose `072`) | New volumes automatically; existing volumes manually |
| `2026-06-15-08-channel-onboarding-sessions.sql` | Channel-generic `channel_onboarding_sessions` table (compose `073`) | New volumes automatically; existing volumes manually |
| `2026-06-15-09-client-channel-identities.sql` | `client_channel_identities` participant→client mapping (compose `074`) | New volumes automatically; existing volumes manually |
| `2026-06-15-10-conversations-channel-fields.sql` | Adds `conversations.business_channel_account_id`/`external_participant_id`/`participant_username`/`last_inbound_at` + `notifications.channel` (compose `075`) | New volumes automatically; existing volumes manually |
| `2026-06-15-11-source-instagram-enum.sql` | Adds `source_enum` value `instagram` + `entity_type_enum` value `channel_account` (compose `076`; not transaction-wrapped) | New volumes automatically; existing volumes manually |
| `2026-06-15-12-instagram-message-send-outbox-type.sql` | Seeds the `instagram.message.send` row in `outbox_event_types` (compose `077`) | New volumes automatically; existing volumes manually |
| `2026-06-15-13-channel-notification-types.sql` | Seeds the `channel.account_unhealthy` notification type (compose `078`) | New volumes automatically; existing volumes manually |
| `2026-06-15-14-backfill-whatsapp-channel-accounts.sql` | Backfills WhatsApp accounts into the parent `business_channel_accounts` + detail `business_whatsapp_channel_accounts` (id-preserving), binds conversations, seeds `last_inbound_at` (compose `079`; **runs LAST**) | New volumes automatically; existing volumes manually |
| `2026-06-16-01-ai-response-length.sql` | Adds `ai_response_length_enum` + `business_ai_settings.response_length` (default `normal`; controls AI client-message verbosity short/normal/detailed). Runner-only — not compose-mounted (folder picked up directly) | New volumes via runner; existing volumes via runner/manual |
| `2026-06-16-02-ai-regional-style.sql` | Adds `business_ai_settings.regional_style` (`varchar(20)` + CHECK `chk_business_ai_settings_regional_style`, allowed `auto`/`neutral`/`gt`/`mx`/`co`/`ar`/`cl`/`es`, default `auto`; subtle regional Spanish register, behavior-neutral). Runner-only — not compose-mounted (folder picked up directly) | New volumes via runner; existing volumes via runner/manual |

## Seeds (in order)

| File | Purpose |
| --- | --- |
| `001-seed-general-catalogs.sql` | General catalogs (currencies, countries, languages, ...) |
| `002-seed-security.sql` | Roles, permissions, role_permissions |
| `003-seed-operational-types.sql` | Operational reference types |
| `004-seed-message-templates.sql` | Message templates |
| `005-seed-plans.sql` | Billing plans |

> Must reflect the real current database files, not assumptions.
