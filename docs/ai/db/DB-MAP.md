# DB-MAP

## AI model cache pricing correction (2026-08-29)

`backend/database/migrations/2026-08-29-01-correct-ai-cache-prices.sql` closes
the current zero-cache-rate facts and appends provider-standard cached-input
rates for GPT-5.6 Luna, GPT-5 mini and Gemini 2.5 Flash-Lite. It is a
runner-only, data-only migration; historical usage events are not rewritten.

## Conversation-state hard cutover (2026-08-26)

`backend/database/migrations/2026-08-26-06-reset-conversation-state.sql` is a one-time, data-only cutover: resets `conversations.state.conversation` on every row to the current version-5 shape, releases any `appointment_holds` left `status = 'active'` by a pre-cutover draft, and normalizes historical `ai_conversation_turns.runtime_version` to `'conversation'`. No schema/table/ER change. Runner-only (not a Compose mount). Applied and verified against a fresh local Postgres volume; not yet applied to Railway/production.

## AI Simulator single-session migration (2026-08-17)

`backend/database/migrations/2026-08-17-01-ai-simulator-single-session.sql` retires historical `state.simulator = true` conversations and adds `conversations_one_active_simulator_per_business_idx`; `2026-08-17-02-purge-retired-ai-simulator-sessions.sql` permanently purges those retired synthetic rows and dependencies. Both are runner-only; no init script or Compose mount changes.

## Latest appointment-action audit migration (2026-08-14)

`backend/database/migrations/2026-08-14-01-appointment-event-client-creator-constraint.sql` updates the existing `appointment_events` creator check so public client cancel/reschedule actions can persist `created_by_type = 'client'` with no dashboard user id. It is runner-only and does not change relationships, tables or Compose mounts.

## Latest messaging migration

`2026-08-10-01-dashboard-message-analytics-indexes.sql` adds two idempotent partial indexes backing the Home Activity aggregated read: active messages by tenant/time and non-simulated conversations by tenant/latest message. Runner-only; no table shape or ER relationship changes.

`2026-08-06-13-conversation-simulation-mode.sql` adds `conversations.is_simulated` and separates the open-conversation uniqueness guard by simulation mode, so a demo thread and a real WhatsApp thread cannot be mixed. Runner-only.

`2026-08-06-14-backfill-simulated-conversations.sql` marks legacy simulator/demo conversations using their persisted simulator state or demo-generated client without a bound WhatsApp account. Runner-only.

## Automated-response billing migrations (2026-08-06)

| Files | Purpose |
| --- | --- |
| `backend/database/migrations/2026-08-06-01..06-*.sql` | Immutable response events; prepaid orders/batches/wallet/ledger; client limits and durable blocks; trials and WhatsApp claim hashes; billing webhook idempotency; response-economics platform settings. Runner-only, no Compose mount. |
| `backend/database/migrations/2026-08-06-07-launch-plan-catalog-v3.sql` | Versioned automated-response/trial/pack/client-limit fields plus five immutable published plan versions and their cost-run evidence. Runner-only. |
| `backend/database/migrations/2026-08-06-08-consume-automated-response.sql` | Atomic per-message consumption: trial/included first, FIFO prepaid second, exactly-once event and non-negative exhaustion. Runner-only. |
| `backend/database/migrations/2026-08-13-02-effective-plan-response-capacity.sql` | Converts stale trial rows superseded by active monthly plans and replaces `consume_automated_response` so SQL consumption follows effective plan/trial precedence. Runner-only; no table shape change. |

`backend/database/migrations/2026-08-04-01-messaging-operational-issues.sql` creates normalized operational incidents and durable message delivery holds. `2026-08-04-02-messaging-delivery-capacity.sql` adds distributed account/recipient token buckets.

`backend/database/migrations/2026-08-04-03-whatsapp-operational-notification.sql` seeds the normalized operational-issue notification type.

## Purpose

Locate database files fast.

## When to read

Whenever finding a SQL file or DB folder.

## Keep updated

When SQL files or folders are added/moved/removed.

## Folders

| `backend/database/migrations/2026-07-15-02-auth-provider-identity-unique.sql` | Partial unique index preventing duplicate active external auth identities |
| `backend/database/migrations/2026-07-30-01-platform-settings.sql` | `platform_settings` + `platform_settings_audit`: the one place platform-wide commercial numbers live and are audited |
| `backend/database/migrations/2026-07-30-02-ai-model-prices-and-runtime-assignments.sql` | `ai_model_prices` (dated prices) + `ai_runtime_assignments` (central model choice per AI surface); `business_ai_settings` model columns become nullable overrides |
| `backend/database/migrations/2026-07-30-04-plan-versions-and-entitlements.sql` | `plan_versions` + `subscription_entitlements` + `conversation_limit_runs`, and `appointments.booking_surface` |
| `backend/database/migrations/2026-07-30-05-launch-plan-catalog.sql` | The four launch plans (free/agenda/whatsapp/whatsapp_pro) published as version 1, with the cost runs behind 750/2,000 |
| `backend/database/migrations/2026-07-30-06-multimodal-limits-and-business-plan.sql` | Multimodal-corrected limits (650/1,650), the Klyro WhatsApp Business plan, and the audio caps |
| `backend/database/migrations/2026-07-30-07-ai-budget-pools.sql` | `ai_budget_pools` + `ai_budget_pool_contributions` and the three pool mutators |
| `backend/database/migrations/2026-07-30-08-public-ai-budgets.sql` | The three public budgets (onboarding, demo, simulator); drops `guest_ai_daily_spend` and `demo_message_rate_limits` |
| `backend/database/migrations/2026-07-30-03-ai-usage-ledger.sql` | `ai_usage_events` (one durable USD row per LLM attempt) + `ai_conversation_windows` + `business_ai_usage_periods`, and the three SQL mutators that keep all money arithmetic out of TypeScript |

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

| `2026-06-22-01..05-*.sql` | AI credits billing batch: per-1M model pricing, plan credits, `usage_counters.llm_credits_used`, `increment_usage_counter`, model cost profiles, and credit notification types. Runner-only | New volumes via runner; existing volumes via runner/manual |
| `2026-06-29-01-worker-free-windows-exclude-appointment.sql` | Updates `scheduling.worker_free_windows` with optional `p_exclude_appointment_id` so reschedule availability can ignore the appointment being moved. Runner-only | New volumes via runner; existing volumes via runner/manual |
| `2026-07-02-02-plan-credit-recalibration.sql` | Data-only update to `plans`: Free 500 credits; Pro $29 / 5,000 credits / 20 workers / 3 branches / 20 services; Max $99 / 50,000 credits. Runner-only | New volumes via runner; existing volumes via runner/manual |
| `2026-07-02-03-free-plan-whatsapp.sql` | Data-only update to `plans`: enables WhatsApp on Free. Separate from `02` to avoid changing an applied migration checksum. Runner-only | New volumes via runner; existing volumes via runner/manual |
| `2026-07-03-01-branch-type.sql` | Adds `branch_type_enum` (`physical`/`online`) + `branches.type` (default `physical`) + partial index `idx_branches_business_type`. `online` is a singleton per business, exempt from the plan's `max_branches` limit (enforced in `CreateBranchUseCase`, not DB-level). Runner-only | New volumes via runner; existing volumes via runner/manual |
| `2026-07-08-01-service-location-mode.sql` | Adds `service_location_mode_enum` + `services.service_location_mode`, indexes service location mode, makes `appointment_holds.branch_id` nullable for online holds, and backfills legacy branch/online service state. Runner-only | New volumes via runner; existing volumes via runner/manual |
| `2026-07-08-02-business-reminder-settings.sql` | Adds one soft-deletable reminder-settings row per business with email/WhatsApp enable flags and constrained lead hours. Runner-only | New volumes via runner; existing volumes via runner/manual |
| `2026-07-15-01-error-logs.sql` | Adds standalone production HTTP/outbox failure records with time/business indexes (compose `091`) | New volumes automatically; existing volumes via runner/manual |
| `2026-07-21-05-ai-provider-gemma-enum.sql` | Immutable historical migration from the discarded standalone provider attempt; its enum value is no longer used by application code. | Historical migration |
| `2026-07-21-06-ai-model-catalog-gemma-4-26b.sql` | Immutable historical zero-price standalone row; disabled by the corrective migration. | Historical migration |
| `2026-07-21-07-ai-model-catalog-deepinfra-gemma-4-26b.sql` | Adds `context_window_tokens`, disables/backfills the historical standalone row, and registers enabled `deepinfra` / `google/gemma-4-26B-A4B-it` at $0.07/$0.34 per 1M tokens and 262144 context tokens. | Compose `092`; existing volumes via runner |
| `2026-07-21-08-ai-model-catalog-gemini-3-flash-models.sql` | Registers enabled Google models `gemini-3.1-flash-lite` at $0.25/$1.50 and `gemini-3.6-flash` at $1.50/$7.50 per 1M input/output tokens. | Compose `093`; existing volumes via runner |
| `2026-07-21-09-ai-model-catalog-deepinfra-gemini-flash-models.sql` | Registers enabled DeepInfra catalog IDs `deepinfra/google/gemini-3.1-flash-lite` at $0.25/$1.50 and `deepinfra/google/gemini-3.5-flash` at $1.50/$9.00 per 1M input/output tokens, with 1,000,000-token context metadata. | Compose `094`; existing volumes via runner |

## Seeds (in order)

| File | Purpose |
| --- | --- |
| `001-seed-general-catalogs.sql` | General catalogs (currencies, countries, languages, ...) |
| `002-seed-security.sql` | Roles, permissions, role_permissions |
| `003-seed-operational-types.sql` | Operational reference types |
| `004-seed-message-templates.sql` | Message templates |
| `005-seed-plans.sql` | Billing plans |

> Must reflect the real current database files, not assumptions.
