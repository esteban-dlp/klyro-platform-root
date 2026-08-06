# TABLES-GUIDE

## Automated-response billing and controls (2026-08-06)

| Table | Business meaning |
| --- | --- |
| `automated_response_events` | Immutable evidence for one customer-visible automated outbound message, funded by included, prepaid or trial capacity. |
| `topup_orders` | Idempotently reconciled purchases of prepaid automated responses. |
| `automated_response_credit_batches` | FIFO-ready grants of prepaid responses with their own lifecycle and expiry. |
| `business_ai_credit_wallets` | Fast, nonnegative cached prepaid balance per business. |
| `automated_response_credit_ledger` | Append-only audit trail for every prepaid grant, debit, expiry, reversal or adjustment. |
| `business_client_ai_limits` | Optional per-client monthly response cap and manual hard-block policy within a tenant. |
| `automated_response_blocks` | Durable explanation of why a client/conversation cannot receive AI and what event can release it. |
| `business_ai_trials` | One controlled AI trial lifecycle per business. |
| `whatsapp_trial_claims` | Hashed global phone claims that prevent repeated WhatsApp trials without storing the phone number. |
| `billing_webhook_events` | Provider event inbox that makes payment handling replay-safe and observable. |

## Messaging reliability tables (2026-08-04)

| Table | Business meaning |
| --- | --- |
| `messaging_operational_issues` | One current or resolved messaging incident normalized across Meta, a managed provider and Klyro; scoped to a tenant and optionally an account/conversation/message. |
| `message_delivery_holds` | One intentional retention of an outbound message until policy, health or capacity permits a safe send. Active holds are unique per message. |
| `messaging_delivery_capacity_buckets` | Shared token-bucket capacity for a WhatsApp account or recipient scope; determines the earliest safe outbound attempt across workers. |

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

## Public AI budgets

| Table | Business meaning |
| --- | --- |
| `public_ai_budgets` | Config for the two **platform-funded** public surfaces. `onboarding`: $0.10/day global, 10 turns and $0.015 per **user** per day. `demo`: $0.10/day global, 20 messages and $0.015 per **device** per day. Whichever limit is hit first blocks. Added by migration `2026-07-30-08`. |
| `public_ai_budget_daily` | Global consumption per surface per day. Exhausting it affects everyone until the next day. |
| `public_ai_budget_identity_daily` | Per-identity consumption. `identity_key` is `user:<uuid>` or `device:<id>` — **the device is the identity for the demo**; `ip_last` is recorded only as an abuse signal, because making IP the identity would pool the quota of everyone behind one network. |
| `business_simulator_usage` | The simulator's monthly consumption per business. Unlike onboarding and the demo, the simulator belongs to a business, so its allowance comes from the **plan**: `plan_versions.simulator_monthly_usd` / `simulator_monthly_messages` are set for Free ($0.03/20) and Agenda ($0.04/30) and **NULL for WhatsApp/WhatsApp Pro/Business**, which pay for simulations out of their included conversations instead. The absence of a separate budget IS the rule, so a flag can never contradict it. |

> Denial never breaks a surface: onboarding falls back to the forms with progress intact (every step persists real entities and the wizard position lives in `business_setup_states`), and the demo becomes read-only with its dashboard and history still visible. Nothing here ever reaches Meta.
>
> Replaces `guest_ai_daily_spend` (global-only, no per-user limit) and `demo_message_rate_limits` (a sliding 24h counter on its own clock), both dropped in the same migration. Running two parallel rate limiters that can disagree is worse than one reset of ephemeral daily counters.

## AI budget pools

| Table | Business meaning |
| --- | --- |
| `ai_budget_pools` | One row per pool per **calendar month (UTC)**. Two pools, deliberately separate: `ai_runtime` (28% of every plan that includes the WhatsApp receptionist) and `owner_ai` (2% of every paid plan, plus a platform grant that funds Free, whose 2% of $0 is $0). Kept apart so Owner AI can never consume budget reserved for answering customers. **A calendar month, not a subscription cycle** — a pool is an aggregate, and an aggregate whose members each have a different window is incomparable and irreconcilable; every ledger event records both periods precisely so neither side has to guess. Unused money is Klyro's operating margin by construction: there is deliberately no per-business balance column anywhere. Added by migration `2026-07-30-07`. |
| `ai_budget_pool_contributions` | Append-only record of who put what into which pool and why. `contribution_pct` is stored **per row**, not looked up at read time, so changing the percentage mid-month cannot silently restate contributions already made. `UNIQUE (pool_id, source_event_id)` makes a webhook delivered three times contribute once. |

> The pools are an **accounting and monitoring** instrument, not an execution gate. A business is stopped by its own conversation limit; the aggregate pool running low never silences anyone, because one heavy business must not be able to cut off every other customer.

## AI usage ledger

| Table | Business meaning |
| --- | --- |
| `ai_usage_events` | One append-only row per **LLM attempt**, in USD. Replaces measuring the same response twice through two independent best-effort writers (the retired `CreditsService` for credits, `ai_token_usage` for tokens) that could silently diverge with nothing to reconcile against. Since `2026-07-31-01` it is also what AI Diagnostics reports its token totals from. Carries the runtime, the cost kind, the model that ACTUALLY answered (not always the one requested — a fallback is priced at its own, higher rate), the exact dated price applied, and **both** accounting periods. `attempt_id` is UNIQUE: a replayed HTTP request cannot double-charge, while a real retry to the provider is a new attempt and is charged. `is_billable` separates "the provider charged us" from "the customer's pool should pay". `applied_at IS NULL` marks an event whose derived aggregates have not been applied yet — **this is where the accounting guarantee lives**: the raw fact is durable the moment it lands and every aggregate is reproducible from it, so a failure while aggregating is recoverable rather than lost, without the ledger ever entering the turn's transaction. Added by migration `2026-07-30-03`. |
| `ai_conversation_windows` | A **billable AI conversation**: a 24h window per conversation in which the client-facing runtime made at least one LLM call. Deliberately not the `conversations` row (a long-lived thread that never resets) and not a message count — this is the unit a plan's published limit is actually sold in, and it aligns with Meta's own service window. `window_key` is the 24h bucket derived arithmetically, so a plain UNIQUE index serializes concurrent openers (a partial index on `now()` is not immutable in Postgres). Cost is split into text / multimodal / retry so drift can be attributed to a cause. |
| `business_ai_usage_periods` | What one business consumed during one **subscription cycle**, in USD. Replaces `usage_counters` (dropped by `2026-07-31-01`), and actually counts conversations — `usage_counters` had a `conversations_count` column from the beginning that nothing ever wrote. `conversation_alert_stage` (0 = none, 1 = 20% left, 2 = 10% left, 3 = exhausted) is monotonic within a cycle; written from phase 5. |

## AI model pricing & assignment

| Table | Business meaning |
| --- | --- |
| `ai_model_prices` | A model's price as a **dated fact**. `ai_model_catalog` used to hold one mutable price per model, so changing it rewrote the past — yesterday's spend would have been recomputed at today's rate (those columns were dropped by `2026-07-31-01`). Here a price change is a NEW row plus an `effective_to` on the old one, never an edit, so the cost of any call can be recomputed with the price that was actually in force when it happened. Adds `cached_input_cost_per_1m_usd`, which providers bill separately and the catalog never modelled. A partial unique index (`effective_to IS NULL`) enforces exactly one current price per model. Added by migration `2026-07-30-02`. |
| `ai_runtime_assignments` | Which model each Klyro AI surface (`ai_runtime`, `owner_ai`, `onboarding`, `simulator`, `demo`, `public_chat`) runs on, decided centrally instead of per business. The bottom-but-one layer of the model cascade: env overrides still win, this replaces the hardcoded code default. `allow_business_override` defaults to false — model choice is a platform decision until a plan explicitly sells it otherwise. Seeded from the env values in force on 2026-07-30. |

> Related change in the same migration: `business_ai_settings.provider` / `.model` / `.owner_assistant_provider` / `.owner_assistant_model` became **nullable**. They were NOT NULL in practice (every row backfilled by `2026-07-20-05`), so a central assignment could never take effect — the business row always shadowed it. Nullable turns them from "the source" into "an override, when one is set".

## Billing & audit

| Table | Business meaning |
| --- | --- |
| `plans` | The stable, commercial IDENTITY of a tier: `code`, `name`, `description`, `is_active` and the LemonSqueezy product/variant mapping. **Every number moved out.** The published limits, price and feature flags live in `plan_versions` (immutable once published, with `effective_from`), and what a given business is entitled to for a given cycle is the frozen snapshot in `subscription_entitlements` — so republishing a limit can never change what a customer already bought. `monthly_llm_credits`, `profit_pct` and `infra_fixed_cents` were dropped by `2026-07-31-01` with the credits currency; the pool contribution percentages that replaced them are in `platform_settings`. The legacy `max_workers`/`max_branches`/`max_services` columns are still written for the transition, but nothing reads them for enforcement. |
| `business_subscriptions` | A business's active plan + billing period (drives the usage period). |
| `ai_model_catalog` | The IDENTITY of a model: provider, model id, display name, `context_window_tokens`, `is_enabled`. It holds **no prices** — `2026-07-31-01` dropped `input_cost_per_1m_usd`, `output_cost_per_1m_usd` and `audio_cost_per_min_usd`, because a single mutable price column rewrites the past every time it is edited. Prices are dated facts in `ai_model_prices`. |
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
