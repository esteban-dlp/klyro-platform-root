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

## Platform configuration

| Table | Business meaning |
| --- | --- |
| `platform_settings` | The single source of truth for every platform-wide **commercial number** an operator may change without a deploy: the share of a plan's price that funds each AI pool, the coverage target and rounding block behind a plan's published conversation limit, the assumed messages per conversation, the remaining-conversation warning thresholds, the day boundary for daily budgets, the Owner AI free-tier grants, and the business-creation caps. One row per knob, `value` as JSONB so a knob can be a number, a string or an ordered list. **Not for secrets, kill switches or emergency hard caps** — those stay in ENV, because a kill switch that depends on a database read is not a kill switch. `version`/`updated_at` are maintained by a trigger, so an update cannot forget to bump them. Added by migration `2026-07-30-01`. |
| `platform_settings_audit` | Append-only history of every commercial number that changed, its before/after value, and who changed it — the record that answers "why is this plan priced this way" months later. Written by a **trigger**, so an edit made straight from `psql` is captured too; the actor comes from the `klyro.actor_id` session variable and is NULL for a manual edit (itself a useful signal). `changed_by` is deliberately **not** a foreign key: history must survive the actor's deletion, and an unresolvable actor must never be able to block a legitimate configuration change. |

## Plans, versions & entitlements

| Table | Business meaning |
| --- | --- |
| `plan_versions` | A plan's numbers as an **immutable published version**. `plans` was mutated in place — five successive data-migrations rewrote prices and limits, so what a business was sold could only be reconstructed by reading migrations in order. Carries every limit plus `has_link_assistant` (whether the public booking LINK offers its chat assistant at all), `max_link_bookings_monthly`, `max_ai_conversations_monthly`, and the commercial presentation fields (`display_order`, `is_recommended`, `is_publicly_listed`) so the frontend holds no heuristic of its own. `computed_from_run_id` points at the cost run that produced the conversation limit. Added by migration `2026-07-30-04`. |
| `subscription_entitlements` | What a business was **promised for one cycle**, frozen when the cycle opened. THE runtime source of truth for every limit: enforcement never reads `plan_versions`, so republishing a recalculated conversation limit cannot retroactively shrink what a customer already bought. Stored as a JSONB copy rather than a join, so a later schema change cannot rewrite history either. |
| `conversation_limit_runs` | The cost calculation behind a published conversation limit — model, price, contribution %, coverage target, sample size and source. `includes_multimodal` records whether the sample covered transcription/images/retries; the launch runs are **text-only**, so the limits they produced are an upper bound. |

> Also added by `2026-07-30-04`: `appointments.booking_surface` (`booking_surface_enum`). `source` conflates the public booking FORM and the public link ASSISTANT into `web`, leaving them indistinguishable — which makes a plan's "100 link bookings" unmeasurable and hides whether the assistant is used at all. It is always set by the backend at the creation path, derived from the actor; never inferred, and never asked of the LLM, whose opinion about its own provenance is not evidence.

## AI budget pools

| Table | Business meaning |
| --- | --- |
| `ai_budget_pools` | One row per pool per **calendar month (UTC)**. Two pools, deliberately separate: `ai_runtime` (28% of every plan that includes the WhatsApp receptionist) and `owner_ai` (2% of every paid plan, plus a platform grant that funds Free, whose 2% of $0 is $0). Kept apart so Owner AI can never consume budget reserved for answering customers. **A calendar month, not a subscription cycle** — a pool is an aggregate, and an aggregate whose members each have a different window is incomparable and irreconcilable; every ledger event records both periods precisely so neither side has to guess. Unused money is Klyro's operating margin by construction: there is deliberately no per-business balance column anywhere. Added by migration `2026-07-30-07`. |
| `ai_budget_pool_contributions` | Append-only record of who put what into which pool and why. `contribution_pct` is stored **per row**, not looked up at read time, so changing the percentage mid-month cannot silently restate contributions already made. `UNIQUE (pool_id, source_event_id)` makes a webhook delivered three times contribute once. |

> The pools are an **accounting and monitoring** instrument, not an execution gate. A business is stopped by its own conversation limit; the aggregate pool running low never silences anyone, because one heavy business must not be able to cut off every other customer.

## AI usage ledger

| Table | Business meaning |
| --- | --- |
| `ai_usage_events` | One append-only row per **LLM attempt**, in USD. Replaces measuring the same response twice through two independent best-effort writers (`CreditsService` for credits, `AiDiagnosticsService` for tokens) that could silently diverge with nothing to reconcile against. Carries the runtime, the cost kind, the model that ACTUALLY answered (not always the one requested — a fallback is priced at its own, higher rate), the exact dated price applied, and **both** accounting periods. `attempt_id` is UNIQUE: a replayed HTTP request cannot double-charge, while a real retry to the provider is a new attempt and is charged. `is_billable` separates "the provider charged us" from "the customer's pool should pay". `applied_at IS NULL` marks an event whose derived aggregates have not been applied yet — **this is where the accounting guarantee lives**: the raw fact is durable the moment it lands and every aggregate is reproducible from it, so a failure while aggregating is recoverable rather than lost, without the ledger ever entering the turn's transaction. Added by migration `2026-07-30-03`. |
| `ai_conversation_windows` | A **billable AI conversation**: a 24h window per conversation in which the client-facing runtime made at least one LLM call. Deliberately not the `conversations` row (a long-lived thread that never resets) and not a message count — this is the unit a plan's published limit is actually sold in, and it aligns with Meta's own service window. `window_key` is the 24h bucket derived arithmetically, so a plain UNIQUE index serializes concurrent openers (a partial index on `now()` is not immutable in Postgres). Cost is split into text / multimodal / retry so drift can be attributed to a cause. |
| `business_ai_usage_periods` | What one business consumed during one **subscription cycle**, in USD. Replaces `usage_counters` for everything except credits, and actually counts conversations — `usage_counters` has had a `conversations_count` column since the beginning that nothing ever wrote. `conversation_alert_stage` (0 = none, 1 = 20% left, 2 = 10% left, 3 = exhausted) is monotonic within a cycle; written from phase 5. |

## AI model pricing & assignment

| Table | Business meaning |
| --- | --- |
| `ai_model_prices` | A model's price as a **dated fact**. `ai_model_catalog` holds one mutable price per model, so changing it rewrites the past — yesterday's spend would be recomputed at today's rate. Here a price change is a NEW row plus an `effective_to` on the old one, never an edit, so the cost of any call can be recomputed with the price that was actually in force when it happened. Adds `cached_input_cost_per_1m_usd`, which providers bill separately and the catalog never modelled. A partial unique index (`effective_to IS NULL`) enforces exactly one current price per model. Added by migration `2026-07-30-02`. |
| `ai_runtime_assignments` | Which model each Klyro AI surface (`ai_runtime`, `owner_ai`, `onboarding`, `simulator`, `demo`, `public_chat`) runs on, decided centrally instead of per business. The bottom-but-one layer of the model cascade: env overrides still win, this replaces the hardcoded code default. `allow_business_override` defaults to false — model choice is a platform decision until a plan explicitly sells it otherwise. Seeded from the env values in force on 2026-07-30. |

> Related change in the same migration: `business_ai_settings.provider` / `.model` / `.owner_assistant_provider` / `.owner_assistant_model` became **nullable**. They were NOT NULL in practice (every row backfilled by `2026-07-20-05`), so a central assignment could never take effect — the business row always shadowed it. Nullable turns them from "the source" into "an override, when one is set".

## Billing & audit

| Table | Business meaning |
| --- | --- |
| `plans` | Pricing tiers. Credits model (2026-06-22): `profit_pct` + `infra_fixed_cents` derive `monthly_llm_credits` for paid tiers (1 credit = $0.001 cost); resource caps `max_workers`/`max_branches`/`max_services` (null = unlimited). Current packaging after 2026-07-02 recalibration: Free has 500 complimentary credits and WhatsApp enabled; Pro is $29 with 5,000 credits and 20 workers/3 branches/20 services; Max is $99 with 50,000 credits and unlimited resource caps. Dropped the old token/message/conversation limit columns. |
| `business_subscriptions` | A business's active plan + billing period (drives the usage period). |
| `usage_counters` | Metered usage per business per billing period: `llm_credits_used` (credits consumed), input/output tokens, `ai_requests_count`, `credits_alert_level` (80/95/100 one-shot owner alerts). Mutated ONLY via the `increment_usage_counter` function. |
| `model_cost_profiles` | Rolling empirical average credits/message per AI model (from `ai_token_usage`), for the "≈ N messages" plan estimate. |
| `ai_model_catalog` | Per-model informative USD pricing **per 1M tokens** (`input/output_cost_per_1m_usd`) plus optional `context_window_tokens`; includes DeepInfra's exact `google/gemma-4-26B-A4B-it` row at $0.07/$0.34, Google-provider Gemini rows, and DeepInfra's `deepinfra/google/gemini-3.1-flash-lite` / `deepinfra/google/gemini-3.5-flash` rows at $0.25/$1.50 and $1.50/$9.00 respectively. |
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
