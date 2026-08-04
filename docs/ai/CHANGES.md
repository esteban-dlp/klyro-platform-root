# CHANGES — Root / Infrastructure

### 2026-08-04 — Messaging reliability state

- Added runner migration `2026-08-04-01-messaging-operational-issues.sql` with tenant-scoped operational incidents and durable message delivery holds.
- Active incident fingerprints and active message holds are unique; release-queue and account/business indexes support reconciliation without scanning message history.

### 2026-07-31 — Credits dropped from the schema

- Added `2026-07-31-01-retire-credits.sql`. **This is the first destructive migration of the USD work** — everything before it was additive, so reverting code left the new tables orphaned but inert. Verified idempotent by applying it twice against a populated local database.
- Drops `usage_counters` + `increment_usage_counter` (every signature, via a `pg_proc` sweep, since older deployments carry a different one), `plans.monthly_llm_credits` / `profit_pct` / `infra_fixed_cents`, `model_cost_profiles`, `ai_token_usage`, and the three price columns on `ai_model_catalog`.
- **`model_cost_profiles` never held a row.** Its own migration described a weekly job that would populate it; that job was never built. It has been schema-shaped dead weight since the day it was created.
- **`ai_token_usage` was a second copy of `ai_usage_events`** minus the cost, written by an independent best-effort path. Two writers of one fact that nothing reconciles will eventually disagree in silence, and the first symptom would have been a support conversation. AI Diagnostics now reports its token totals from the ledger the accounting is derived from.
- **Guard before the price drop:** the migration raises rather than proceeding if `ai_model_prices` is empty, so the only record of what a model cost can never disappear with the columns.
- **Notification types:** `business.ai_credits_low` / `_exhausted` are deleted (along with their preferences and delivered notifications) and replaced by `business.ai_conversations_low` / `_exhausted`. Deleting the delivered ones is deliberate — "you used 80% of your credits" has no translation into conversations, and leaving it in the owner's inbox would contradict the model that replaced it.
- No `root/docker-compose.yml` change: the `migrations` service reads the folder directly.

### 2026-07-30 — The three public AI budgets

- Added `2026-07-30-08-public-ai-budgets.sql`. Onboarding: $0.10/day global, 10 turns + $0.015 per user/day. Demo: $0.10/day global, 20 messages + $0.015 per device/day. Whichever limit is hit first blocks.
- **The simulator is deliberately different.** It belongs to a business, not the platform, so its allowance comes from the plan: Free $0.03/20 messages, Agenda $0.04/30, and **NULL for the WhatsApp plans**, which pay for simulations out of their included conversations — one simulated 24h window is one conversation, not one per message. Encoding it as a nullable allowance rather than a boolean means the budget and the rule can never contradict each other.
- **Reservation is atomic in SQL.** The mechanism this replaces read the total before a turn and wrote it after, so concurrent turns could all pass the same check. Here the guard and the increment are one statement, and the identity is charged BEFORE the global pot — verified that a request denied for global exhaustion does not consume the visitor's own quota.
- **The device is the demo's identity**; IP is recorded only as an abuse signal, since making it the identity would pool the quota of everyone behind one network.
- Drops `guest_ai_daily_spend` and `demo_message_rate_limits`: both held ephemeral daily state, and running two parallel limiters that can disagree is worse than one reset.

### 2026-07-30 — The two monthly AI budget pools

- Added `2026-07-30-07-ai-budget-pools.sql`: `ai_budget_pools`, `ai_budget_pool_contributions`, and `ensure_ai_budget_pool` / `record_pool_contribution` / `increment_pool_spend`.
- **Calendar month, not subscription cycle.** Entitlements and conversation counters run on each business's own cycle; pools do not. A pool is an aggregate, and an aggregate whose members each have a different window is incomparable and irreconcilable. Every ledger event already records both periods (from `2026-07-30-03`) precisely so neither side has to guess.
- **`contribution_pct` is stored per contribution row**, not read from settings later, so changing the percentage mid-month cannot restate contributions already made. `UNIQUE (pool_id, source_event_id)` makes a replayed webhook a no-op — verified: the second call returns false and the pool total does not move.
- **No per-business balance column exists anywhere**, deliberately: leftover budget is Klyro's operating margin by construction, not a credit anyone can claim.
- Runner-only; verified idempotent against a populated local database.

### 2026-07-30 — Multimodal-corrected limits, audio caps, and Klyro WhatsApp Business

- Added `2026-07-30-06-multimodal-limits-and-business-plan.sql`: `plan_versions.max_audio_minutes_monthly`, four new `platform_settings` keys, the `whatsapp_business` plan, three cost runs, and version 2 of WhatsApp / WhatsApp Pro.
- **Why the limits moved.** Version 1 published 750/2,000 from a TEXT-ONLY sample. Phase 2's ledger then measured the gap live: a 90-second voice note costs $0.0045, about 60% of an entire 10-message text conversation. At a third of conversations carrying one, the real cost is `$0.00752895 x 1.197 = $0.00901395`, which re-derives to **650 / 1,650** at the unchanged 28%.
- **Headroom is sold, not subsidised.** Klyro WhatsApp Business ($99, 3,400 conversations, 12 branches, 100 workers, 50 services, **3 WhatsApp numbers**) replaces the alternative of raising Pro's contribution to 33% — which would have charged margin on every Pro customer to solve a ceiling only some need, and would have forced the contribution to become a per-plan column instead of one global setting. The contribution stays **28% ai_runtime / 2% owner_ai for every plan**.
- **Audio caps, two layers.** Transcription is billed by duration, and duration is only known AFTER paying — so a byte cap (1 MB, checked on the downloaded bytes) is the only gate that can prevent rather than record a runaway cost. Minute caps per conversation (15) and per cycle bound the aggregate. The per-cycle cap is DERIVED (`conversations x 0.5 min`) so it cannot drift from the assumption that produced the conversation limit: 0.5 min is exactly 33% penetration at 90 seconds.
- **Version 1 is retired, not edited** — a published version stays immutable history even though it was never sold to anyone.
- Runner-only; verified idempotent against a populated local database.

### 2026-07-30 — Versioned plans, per-cycle entitlements, and the launch catalog

- Added `2026-07-30-04-plan-versions-and-entitlements.sql` (`plan_versions`, `subscription_entitlements`, `conversation_limit_runs`, `appointments.booking_surface`) and `2026-07-30-05-launch-plan-catalog.sql` (the four launch plans published as version 1).
- **Why entitlement snapshots:** nothing froze what a customer bought. A recalculated conversation limit would have silently applied to every active business mid-cycle. Runtime enforcement now reads the frozen snapshot, never the live catalog.
- **Why `booking_surface`:** the public booking FORM and the public link ASSISTANT both record `source = 'web'` today, so they are indistinguishable — making a plan's "100 link bookings" unmeasurable. It is set by the backend at the creation path, derived from the actor, never inferred.
- **Launch plans:** free ($0, 1/5/10, 100 link bookings), agenda ($10, 3/20/20, unlimited link), whatsapp ($19, 750 conversations, link assistant), whatsapp_pro ($49, 2,000 conversations, link assistant). Only the two WhatsApp plans include the link assistant; Free and Agenda are form-only by design, so no LLM call can originate from their link. `Klyro Business` deliberately not created.
- **Version 1 is backdated to epoch on purpose** — found by live verification: with `effective_from = now()`, every cycle already in flight had no version in force and every business silently fell to the Free floor. The effective-date rule protects a running cycle from a shrinking limit; version 1 has nothing to protect against.
- Runner-only; `root/docker-compose.yml` deliberately not updated. Both verified idempotent against a populated local database.

### 2026-07-30 — The USD usage ledger

- Added migration `backend/database/migrations/2026-07-30-03-ai-usage-ledger.sql` — `ai_usage_events`, `ai_conversation_windows`, `business_ai_usage_periods`, three enums and three SQL mutator functions.
- **Why a ledger:** the same LLM response was measured twice by two independent best-effort writers that both swallow every error, neither storing a USD cost or the runtime it belonged to. If one write failed the two diverged silently with nothing to reconcile against.
- **Where the accounting guarantee lives:** `applied_at`. The raw fact is durable the moment it is inserted and every derived aggregate is reproducible from it, so the ledger is non-best-effort WITHOUT ever entering the turn's transaction — a deliberate constraint, since an accounting problem must never be able to break a customer conversation.
- **Concurrency without a lock:** `window_key` is the 24h bucket derived arithmetically, so the plain UNIQUE on `(conversation_id, window_key)` serializes concurrent openers. A partial index on `now()` is not immutable in Postgres and could not do this.
- Verified in SQL against a populated local database: 20 concurrent opens produce exactly one window, a 25h gap opens a second, `was_created` distinguishes an open from a touch, the fully-loaded cost splits correctly by `cost_kind`, `attempt_id` UNIQUE rejects a duplicate charge, and `3 x 0.00000001` sums to exactly `0.00000003`. Runner-only; `root/docker-compose.yml` deliberately not updated.

### 2026-07-30 — Dated model prices + central runtime model assignment

- Added migration `backend/database/migrations/2026-07-30-02-ai-model-prices-and-runtime-assignments.sql` — type `ai_runtime_enum`, tables `ai_model_prices` and `ai_runtime_assignments`, and nullable model columns on `business_ai_settings`.
- **Why dated prices:** `ai_model_catalog` stores one mutable price per model, so a price change is an in-place UPDATE that rewrites the past — yesterday's spend would be recomputed at today's rate. `ai_model_prices` makes a price a dated fact; a change is a new row, never an edit. Also adds `cached_input_cost_per_1m_usd`, which providers bill separately and the catalog never modelled.
- **Why nullable business columns:** those four columns were NOT NULL in practice (every row backfilled by `2026-07-20-05`), so a central assignment could never have taken effect. Existing values are deliberately left in place — they are already fully shadowed by the env override and `allow_business_override` defaults to false, so they are inert either way.
- Assignments seeded from the env values in force in production on 2026-07-30 (`ai_runtime` → `google/gemma-4-26B-A4B-it`, `owner_ai`/`onboarding` → `deepinfra/deepseek-v4-flash`), with the provider derived from the catalog by model id rather than written by hand.
- Runner-only; `root/docker-compose.yml` deliberately not updated. Verified idempotent against a populated local database, and the resolved cascade verified live for both layers (central assignment with no env override, env override with the production values) with prices reading from the new table.

### 2026-07-30 — Platform settings: the one place commercial numbers live

- Added migration `backend/database/migrations/2026-07-30-01-platform-settings.sql` — `platform_settings` (one row per platform-wide commercial knob, `value` as JSONB) and `platform_settings_audit` (append-only history), plus the trigger functions `platform_settings_bump_version()` and `platform_settings_write_audit()`.
- Seeds 18 launch knobs: AI pool contribution percentages, coverage target, conversation rounding block, budgeted messages per conversation, remaining-conversation warning thresholds, daily-budget timezone, cost-sizing parameters, Owner AI free-tier grants, business-creation caps, and the mid-cycle proration policy.
- **Runner-only — `root/docker-compose.yml` is deliberately NOT updated.** This is a normal post-cutoff migration; the local `migrations` service reads the folder directly, so adding an initdb mount would be wrong.
- Verified by applying it twice against a populated local database: idempotent, no drift (18 settings / 18 audit rows / version 1 after both runs). Trigger behaviour verified directly in SQL — version bumps only on a real value change, description-only edits are not audited, and an edit with no `klyro.actor_id` is still recorded with a NULL actor rather than rejected.
- Scope note: secrets, kill switches and emergency hard caps deliberately stay in ENV. A kill switch that depends on a database read is not a kill switch. See `docs/ai/db/TABLES-GUIDE.md` and the backend `DECISIONS.md` entries of the same date.

### 2026-07-21 — Add Gemini Flash models through DeepInfra

- Added migration `2026-07-21-09-ai-model-catalog-deepinfra-gemini-flash-models.sql` and fresh-volume Compose mount `094-ai-model-catalog-deepinfra-gemini-flash-models.sql`.
- Registered DeepInfra's current rates: `gemini-3.1-flash-lite` at `$0.25/$1.50` and `gemini-3.5-flash` at `$1.50/$9.00` input/output per 1M tokens, with 1,000,000-token context metadata.

### 2026-07-21 — Add Gemini Flash models to the catalog

- Added migration `2026-07-21-08-ai-model-catalog-gemini-3-flash-models.sql` and fresh-volume Compose mount `093-ai-model-catalog-gemini-3-flash-models.sql`.
- Registered the exact Google model IDs `gemini-3.1-flash-lite` and `gemini-3.6-flash` at `$0.25/$1.50` and `$1.50/$7.50` input/output per 1M tokens.

### 2026-07-21 — Correct Gemma catalog registration through DeepInfra

- Added migration `2026-07-21-07-ai-model-catalog-deepinfra-gemma-4-26b.sql`.
- The enabled catalog row is `deepinfra` / `google/gemma-4-26B-A4B-it`, priced at `$0.07` input and `$0.34` output per 1M tokens, with `262144` context tokens.
- The corrective migration disables the historical standalone row and backfills existing business selections to DeepInfra. Immutable migrations `05`/`06` remain as history; the new migration is mounted as compose order `092`.

### 2026-07-16 — Backfill webhook_public_id for existing Meta WhatsApp accounts

- New runner migration `2026-07-16-03-backfill-meta-webhook-public-id.sql` (in `backend/database/migrations/`) mints a `business_whatsapp_accounts.webhook_public_id` for Meta rows connected before per-account webhook isolation shipped (non-secret id, safe via `pgcrypto`'s `gen_random_bytes`). New connections mint one at connect time; this only covers pre-existing rows.
- No compose mount added; the migration service reads new migration files directly, consistent with the current bootstrap cutoff.

### 2026-07-16 — Pro/Max plan AI credits raised

- New runner migration `2026-07-16-02-plan-credits-pro-max-increase.sql` (in `backend/database/migrations/`) sets `plans.monthly_llm_credits` to 5,000 for `pro` (was 3,000) and 15,000 for `max` (was 10,000).
- No compose mount added; the migration service reads new migration files directly, consistent with the current bootstrap cutoff.

## Purpose

Changelog of meaningful infra/DB changes, newest first.

## When to read

At the start of any task, after MAP — to know what just changed.

## Keep updated

After every meaningful change, append an entry at the top. Flag changes affecting backend entities or the running stack.

## Changelog

### 2026-07-15 — Unique external auth identities

- Added runner migration `2026-07-15-02-auth-provider-identity-unique.sql` with a partial unique index on active `(auth_provider, auth_provider_id)` values.
- No compose mount was added; the migration service reads new migration files directly, consistent with the current bootstrap cutoff.

### 2026-07-12 - Backend container environment validation fix

- Removed the explicit empty `DATABASE_URL` override from the backend service. Joi correctly rejects an empty URI,
  so the override prevented the backend from booting even when the backend env file contained a valid connection.
  Compose now lets either its valid `DATABASE_URL` or the documented discrete `DATABASE_HOST`, `DATABASE_PORT`,
  `DATABASE_USER`, `DATABASE_PASSWORD`, and `DATABASE_NAME` values drive the connection as intended.
- No database schema or migration changed. An existing local volume may still stop the migration runner if its
  recorded checksum differs from a migration file; resolve that volume/history mismatch separately rather than
  editing an applied migration.

### 2026-07-08 - Service location mode and branchless online holds
- **Migration (runner-only, `root/docker-compose.yml` NOT touched):**
  - `backend/database/migrations/2026-07-08-01-service-location-mode.sql` adds `service_location_mode_enum` (`BRANCH_ONLY`/`ONLINE_ONLY`/`HYBRID`) and `services.service_location_mode` (`NOT NULL DEFAULT 'BRANCH_ONLY'`), indexes `(business_id, service_location_mode)`, and makes `appointment_holds.branch_id` nullable for online holds.
  - Backfill derives service modes from existing active `branch_services` joined to `branches.type`; single-physical-branch legacy services get a physical `branch_services` row, branchless services in businesses with no physical branches become `ONLINE_ONLY`, and ambiguous branchless services in multi-physical-branch businesses are inactivated for explicit owner cleanup.
- **Why:** online services are a service capability, not a physical branch assignment. `branch_services` now represents physical branch eligibility only; `ONLINE_ONLY` services carry no physical branches and online holds can be branchless.
- **Apply to an existing volume:** run the normal migrations service or apply the file with `psql`; no compose mount change is needed because the migration runner reads `backend/database/migrations` directly.

### 2026-07-07 - Resource validation constraints
- **Migration (runner-only, `root/docker-compose.yml` NOT touched):**
  - `backend/database/migrations/2026-07-07-01-resource-validation-constraints.sql` adds idempotent CHECK constraints for `resources.name` trimmed length (`>= 2`) and `resources.icon_key` format (`^[a-z0-9_-]+$` when present).
- **Why:** align the database with the backend/UI resource validation rules so bad resource names/icons cannot be persisted through alternate paths.
- **Apply to an existing volume:** run the normal migrations service or apply the file with `psql`; fresh/current local runner reads the migrations folder directly in filename order.

### 2026-07-06 - Branch override "type of closure" optional
- **Migration (runner-only, `root/docker-compose.yml` NOT touched — normal migration):**
  - `2026-07-06-02-branch-override-type-optional.sql` drops `NOT NULL` on `branch_availability_overrides.branch_override_type_id` (idempotent). The FK to `branch_override_types` is retained; the column is simply nullable now.
- **Why:** owners asked to be able to record a branch override (special hours / closure for exact dates) without picking a "Type of closure" from the catalog. Applies to both the branch overrides CRUD form and the owner AI assistant.
- **Apply to an existing volume:** `docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < ../backend/database/migrations/2026-07-06-02-branch-override-type-optional.sql` (or just `docker compose up --build`, which runs the `migrations` service).

### 2026-07-03 - Branch type: physical vs online
- **Migration (runner-only, `root/docker-compose.yml` NOT touched):**
  - `2026-07-03-01-branch-type.sql` adds `branch_type_enum` (`physical`/`online`) and `branches.type` (`NOT NULL DEFAULT 'physical'`), plus a partial index `idx_branches_business_type` on `(business_id, type)` for the "does this business already have an online branch" check.
- **Why:** Selecting "online / mobile" during onboarding was creating an ordinary physical branch row, which incorrectly counted toward the plan's `max_branches` limit and had no way to render differently in the UI. The booking engine still needs a branch row (appointments/schedules/opening-hours all hang off a branch), so we typed the branch instead of going branch-less.
- **Impact:** Additive, backward-compatible (`physical` default backfills existing rows). `online` is enforced as a singleton per business and excluded from the plan branch-limit count in `CreateBranchUseCase` (application-level, not a DB constraint) — see `backend/src/modules/businesses/use-cases/create-branch.use-case.ts`.

### 2026-07-02 - Plan pricing and AI credit recalibration
- **Migrations (runner-only, `root/docker-compose.yml` NOT touched):**
  - `2026-07-02-02-plan-credit-recalibration.sql` updates the seeded plan rows:
    - `free`: keeps existing resource caps, grants 500 complimentary AI credits ($0.50).
    - `pro`: price $29, 5,000 AI credits ($5 budget), 20 workers, 3 branches, 20 services, `profit_pct=65.52`, `infra_fixed_cents=500`.
    - `max`: price $99, 50,000 AI credits ($50 budget), unlimited resource caps, `profit_pct=41.41`, `infra_fixed_cents=800`.
  - `2026-07-02-03-free-plan-whatsapp.sql` enables WhatsApp on the Free plan. Kept separate because `2026-07-02-02` may already be recorded in `schema_migrations` and migration files are checksum-pinned.
- **Why:** Align plan packaging with the new pricing/AI-budget strategy while preserving the credits model (`1 credit = $0.001` real internal AI cost).
- **Impact:** Data-only updates to `plans`; no schema/entity changes. Free credits are complimentary and not formula-derived because the plan price is $0. Paid-plan profit percentages are rounded to the `NUMERIC(5,2)` column precision.

### 2026-06-29 - WhatsApp YCloud provider: enum value + per-account webhook id
- **Migrations (runner-only, `root/docker-compose.yml` NOT touched — post-baseline convention):**
  - `2026-06-29-02-whatsapp-ycloud-provider-enum.sql` — `ALTER TYPE whatsapp_provider_enum ADD VALUE 'ycloud'`
    (own file so the value commits before any use).
  - `2026-06-29-03-whatsapp-ycloud-account-fields.sql` — adds `business_whatsapp_accounts.webhook_public_id`
    (unguessable per-account id embedded in the YCloud webhook URL) with a unique partial index, plus a partial
    unique index enforcing **one connected WhatsApp account per business** (`status='connected'`).
- **Why:** YCloud webhooks are configured per account and signed with a per-account secret, so the inbound URL must
  identify the account before signature verification; and the product rule is one connected number per business.
- **Impact:** Additive columns/indexes. ER model `backend/database/docs/database-der.mmd` updated
  (`webhook_public_id`; enum gains `ycloud`). Existing environments with >1 connected account per business must be
  cleaned up before the partial unique index applies.

### 2026-06-29 - Reschedule availability excludes the appointment being moved
- **Migration (runner-only, `root/docker-compose.yml` NOT touched):**
  - `2026-06-29-01-worker-free-windows-exclude-appointment.sql` updates
    `scheduling.worker_free_windows` to accept optional `p_exclude_appointment_id` and skip that appointment when
    subtracting active appointments from free ranges.
- **Why:** v2 reschedule availability can now auto-exclude the appointment being moved at the DB free-window layer,
  matching backend exact booking validation and avoiding false self-conflict `slot_taken` issues.
- **Impact:** Function signature is additive through a defaulted final argument. Backend availability code passes the
  new parameter when rescheduling; existing callers using five args continue to work.

### 2026-06-22 — AI credits billing schema (plans→credits, usage counters, per-1M pricing, cost profiles)
- **Migrations (runner-only, `root/docker-compose.yml` NOT touched):**
  - `2026-06-22-01-ai-model-catalog-per-1m-pricing.sql` — guarded rename of `ai_model_catalog.input/output_cost_per_1k_usd` → `*_per_1m_usd` + ×1000 (per-1M tokens, industry standard). Runs after seed 006 in every path, so it converts the seeded per-1K values in place. Seed 006 is intentionally left per-1K (immutable-era file matching its CREATE migration).
  - `2026-06-22-02-plans-credits-model.sql` — `plans`: DROP `max_conversations_per_month`/`max_ai_messages_per_month`/`max_input_tokens_per_month`/`max_output_tokens_per_month`; ADD `profit_pct`/`infra_fixed_cents`/`monthly_llm_credits`/`max_services` (+ CHECKs); recalibrated free/pro/max ($0/$30/$90). Credits derived by formula (profit_pct is the per-tier lever).
  - `2026-06-22-03-usage-counters-credits-and-increment-fn.sql` — `usage_counters`: ADD `llm_credits_used`(numeric 14,3)/`credits_alert_level`(smallint, CHECK 0/80/95/100); CREATE `increment_usage_counter(business,period_start,period_end,input,output,credits,ai_requests)` (upsert-and-add on the `(business_id,period_start,period_end)` unique index) — the previously-missing function the app now calls.
  - `2026-06-22-04-model-cost-profiles.sql` — new `model_cost_profiles` (UNIQUE provider+model): rolling empirical avg credits/message per model for the "≈ N messages" estimate.
  - `2026-06-22-05-credits-notification-types.sql` — seeds `business.ai_credits_low` + `business.ai_credits_exhausted` notification types.
- **Note:** `usage_counters` was dead scaffolding before this — never written to. It is now populated by the AI runtime via `increment_usage_counter` on every LLM call. Clean replacement (no production users), so dropped the obsolete plan columns outright rather than back-compat.

### 2026-06-16 - AI regional language style setting (Phase 4)
- **Changed:** Added NEW migration `backend/database/migrations/2026-06-16-02-ai-regional-style.sql` — adds `business_ai_settings.regional_style` (`varchar(20)`, `NOT NULL DEFAULT 'auto'`) plus an idempotent CHECK `chk_business_ai_settings_regional_style` (`auto`/`neutral`/`gt`/`mx`/`co`/`ar`/`cl`/`es`). Idempotent (`ADD COLUMN IF NOT EXISTS` + guarded `DO $$` for the constraint via `pg_constraint`).
- **What it controls:** Owner-tunable AI voice setting injecting ONE subtle regional Spanish register into the prompt — subordinate to the client's detected language (applies only when replying in Spanish; never slang/stereotype). `auto` derives the register from the business country when reachable (else neutral); explicit codes pin a country.
- **Why varchar+CHECK (not a PG enum):** countries can be added incrementally without an enum-alter migration.
- **Rollout:** Behavior-neutral — `DEFAULT 'auto'` backfills every existing row; `auto` resolves neutral on the conversation hot path (business ISO code not cheaply reachable there), so no business changes behavior on deploy.
- **Compose:** NOT compose-mounted (normal migrations are runner-only per `DB-INSTRUCTIONS.md`); `root/docker-compose.yml` NOT touched.
- **Docs:** Updated `database/docs/database-der.mmd` (added `regional_style`), `db/TABLES-GUIDE.md`, `db/DB-MAP.md`, `CURRENT-STATE.md`, `TASKS-LOG.md`.
- **Impact:** Fully additive. Backend TypeScript/entities updated in the same Phase 4 work (enum→entity→config→DTO→mapper→prompt); frontend NOT modified.

### 2026-06-16 - AI response length setting (Phase 3a)
- **Changed:** Added NEW migration `backend/database/migrations/2026-06-16-01-ai-response-length.sql` — creates `ai_response_length_enum` (`short`/`normal`/`detailed`) and adds `business_ai_settings.response_length` column with `NOT NULL DEFAULT 'normal'`. Idempotent (guarded `DO $$` for the type, `ADD COLUMN IF NOT EXISTS`).
- **What it controls:** Owner-tunable AI voice setting for how much factual content the AI puts in each client-facing message — `short` (answer + the single decision needed), `normal` (answer + key booking facts: service, worker; today's behavior), `detailed` (answer + full context: service, worker, duration, price, next step).
- **Rollout:** Behavior-neutral — `DEFAULT 'normal'` backfills every existing row to current behavior; no business changes behavior on deploy.
- **Compose:** NOT compose-mounted. Per `DB-INSTRUCTIONS.md` §"Docker Compose Local" + Required Change Checklist item 5, normal migrations are read directly from the folder by the `migrations` service (runner) and Railway via `npm run db:migrate`; `root/docker-compose.yml` was NOT touched.
- **Docs:** Updated `database/docs/database-der.mmd` (added `response_length` to `business_ai_settings`), `db/TABLES-GUIDE.md`, `db/DB-MAP.md`, `CURRENT-STATE.md`, `TASKS-LOG.md`.
- **Impact:** Fully additive. Backend TypeScript/entities and frontend NOT modified (separate Phase 3a work).

### 2026-06-15 - Multi-channel messaging: parent/detail account model
- **Changed:** Adopted a parent/detail account model for messaging accounts. Added a new WhatsApp DETAIL table and revised the backfill so WhatsApp-only relational fields keep real foreign keys instead of going into the parent JSONB:
  - NEW `2026-06-15-07-business-whatsapp-channel-accounts.sql` (compose mount **072**) — `business_whatsapp_channel_accounts`: one-to-one detail of `business_channel_accounts` (UNIQUE `channel_account_id`, composite FK `(channel_account_id, business_id)` → parent), real composite FK `(business_phone_number_id, business_id)` → `business_phone_numbers` (integrity preserved, **not JSONB**), `waba_id`, `meta_phone_number_id`, `display_phone_number`, `metadata` jsonb, partial-unique on `meta_phone_number_id WHERE deleted_at IS NULL`, `(business_id)` partial index, `set_updated_at` trigger, business-focused COMMENTs.
  - REVISED `2026-06-15-14-backfill-whatsapp-channel-accounts.sql` (compose mount **079**) — parent insert now stores only `channel_metadata = {'legacy_whatsapp_account_id'}` (no more `waba_id`/`business_phone_number_id` in JSONB); added a second idempotent insert populating the WhatsApp DETAIL table 1:1 by preserved id. Conversation rebind + `last_inbound_at` backfill + skipped WhatsApp `client_channel_identities` unchanged.
  - Compose order is now: `072` detail table before `079` backfill (detail must exist before the backfill populates it).
- **Backend:** Added additive TypeORM entity `BusinessWhatsappChannelAccount` (`backend/src/modules/channels/entities/business-whatsapp-channel-account.entity.ts`), registered in `ChannelsModule` `forFeature` (TypeOrmModule already exported). WhatsApp runtime code is NOT re-typed (deferred); no WhatsApp module file touched.
- **Reason:** Preserve FK integrity for WhatsApp relational fields (notably `business_phone_number_id`) under the channel abstraction, per the locked parent/detail decision. Instagram stays base-table-only in Phase 1.
- **Impact:** Fully additive. After the global `YYYY-MM-DD-NN` rename, the detail table is mount 072 and the backfill is mount 079. No applied migration edited in the fresh Railway target.

### 2026-06-15 - Multi-channel messaging DB foundation (migrations 070-079)
- **Changed:** Multi-channel messaging DB foundation migrations for Instagram + channel abstraction, compose mounts `070`-`079`:
  - `070 message-channel-instagram-enum` — adds `message_channel_enum` value `instagram` + new `channel_account_status_enum` + `channel_onboarding_status_enum`. NOT transaction-wrapped (enum `ADD VALUE` can't run in a tx / be used same-tx).
  - `071 business-channel-accounts` — canonical channel-agnostic `business_channel_accounts` table (encrypted credentials + masking hints, lifecycle CHECKs, partial unique on `(channel, inbound_routing_key)`, composite `(id, business_id)`, `set_updated_at` trigger).
  - `072 channel-onboarding-sessions` — channel-generic `channel_onboarding_sessions` (single-use `state_nonce`, FK to channel accounts).
  - `073 client-channel-identities` — participant→client mapping, account-scoped unique, for phone-less channels.
  - `074 conversations-channel-fields` — adds `conversations.business_channel_account_id` (FK + index), `external_participant_id`, `participant_username`, `last_inbound_at`; adds `notifications.channel` (notifications has no `metadata jsonb`).
  - `079 backfill-whatsapp-channel-accounts` - id-preserving copy of WhatsApp accounts into `business_channel_accounts`, binds conversations, seeds `last_inbound_at` from latest inbound (`role='client'`) message. Idempotent; WhatsApp `client_channel_identities` backfill intentionally skipped (resolution stays phone-based).
- **Reason:** Generalize the WhatsApp-only messaging model into a channel/provider abstraction and add Instagram DMs, while preserving WhatsApp. Expand → backfill → (deferred) drop.
- **Impact:** Fully additive (new tables/columns + one enum value); legacy `business_whatsapp_accounts` and `conversations.business_whatsapp_account_id` untouched. Backend will need new TypeORM entities (`business_channel_accounts`, `channel_onboarding_sessions`, `client_channel_identities`) and new conversation/notification columns. Existing volumes require manual application (`psql`); enum migration must run un-wrapped. No applied migration edited.

### 2026-06-15 — Service AI insights column (migration 069)
- **Changed:** New migration `2026-06-15-04-service-ai-insights.sql` (compose mount `069`). Adds `services.ai_insights JSONB` (+ CHECK `chk_services_ai_insights_object` = object when present).
- **Reason:** Phase 3+4 of the "AI Business Assistant". Stores OPTIONAL AI-authored service insights (`{idealFor[], notIdealFor[], intakeQuestions[], suggestedExtras[], source, generatedAt}`) — produced by the AI service-authoring endpoint, injected candidate-only into the AI receptionist prompt.
- **Impact:** Additive/nullable/idempotent. Existing volumes require manual application (`psql`). No applied migration edited.

### 2026-06-15 — Appointment AI worker-summary column (migration 068)
- **Changed:** New migration `2026-06-15-03-appointment-ai-summary.sql` (compose mount `068`). Adds `appointments.ai_summary JSONB` (+ CHECK = object when present).
- **Reason:** Phase 2 of the "AI Business Assistant". Stores a template-first, AI-generated worker-preparation summary (`{summary, highlights[], preparationNotes[], source, generatedAt}`), separate from human `appointments.notes`.
- **Impact:** Additive/nullable/idempotent. Existing volumes require manual application (`psql`). No applied migration edited.

### 2026-06-15 — AI discovery mode kill switch (migration 067)
- **Changed:** New migration `2026-06-15-02-ai-discovery-mode.sql` (compose mount `067`). Adds `business_ai_settings.discovery_mode_enabled BOOLEAN NOT NULL DEFAULT true`.
- **Reason:** Phase 1 of the "AI Business Assistant" evolution. Per-business kill switch for the new need-discovery / advisory conversation behavior; ships ON globally, any business can revert to legacy fast-booking without a global flag flip.
- **Impact:** Additive/defaulted/idempotent. Backend entity `BusinessAiSettings.discoveryModeEnabled` maps the column. Existing volumes require manual application (`psql`). No applied migration edited.

### 2026-06-13 - Appointment blocked intervals and scheduling functions (migration 060)
- **Changed:** Added `2026-06-13-14-appointment-blocked-intervals.sql`, mounted as compose step `060`. Appointments and appointment holds gain non-null `blocked_start_at`/`blocked_end_at`, backfilled from visible times for existing rows.
- **Scheduling:** worker conflict indexes and `scheduling.has_active_hold_conflict`, `scheduling.has_appointment_conflict`, and `scheduling.is_worker_available_for_booking` now use blocked intervals.
- **Impact:** `start_at`/`end_at` remain customer-visible. Backend entities and writes must populate blocked intervals with service duration plus both buffers. Applied successfully to the running local volume and rerun to verify idempotency; other existing volumes require manual application.

### 2026-06-12 — Fix: add missing `branch_id` to `business_whatsapp_accounts` (migration 047)
- **Changed:** New migration `2026-06-12-02-whatsapp-account-branch-id.sql` (mount `047`). Adds the nullable `branch_id` column (+ composite FK to `branches (id, business_id)` + partial index) that the entity/mapper/DTO/ER model already expected but the init schema never created.
- **Reason:** TypeORM emitted `branch_id` in every `business_whatsapp_accounts` INSERT, so Postgres rejected connect/onboarding with `column "branch_id" ... does not exist`. Pre-existing schema drift surfaced by the first manual Meta connect.
- **Impact:** Manual Meta connect + 360dialog onboarding can now insert. Additive/nullable; must be applied to existing volumes via `psql` (does not auto-run on an existing volume).

### 2026-06-12 — WhatsApp BYOA-ready secrets + masking hints (migration 046)
- **Changed:** New migration `2026-06-12-01-whatsapp-byoa-and-hints.sql` (registered in `docker-compose.yml` as mount `046`). Adds to `business_whatsapp_accounts`: `app_secret_encrypted TEXT`, `verify_token_encrypted TEXT` (both BYOA-ready, encrypted, NULL today), and non-secret masking hints `access_token_last4 VARCHAR(8)`, `app_secret_last4 VARCHAR(8)`. All additive/nullable/idempotent. DER updated.
- **Reason:** "Per-Business Manual Meta Cloud API (WhatsApp) Setup" — let the UI render a masked token tail (`••••••ABCD`) and leave a clean seam for future bring-your-own-app verification.
- **Impact:** No behavior change. Per-business webhook verification is **not** activated; the shared Klyro Meta App (global `META_APP_SECRET`/`META_VERIFY_TOKEN`) stays authoritative. No applied migration edited.

### 2026-06-09 — Service-extra quantity, offer branch scoping/visuals, holiday rules/applicability/visuals
- **Changed:** Three new migrations (registered in `docker-compose.yml` as mounts 037–039, applied to the running volume via `psql`, no volume reset):
  - `2026-06-09-01-service-extra-quantity.sql` — `services_extras.min_quantity`/`max_quantity` (+ CHECKs), `appointment_extras.quantity` (+ CHECK).
  - `2026-06-09-02-offer-branches-visuals.sql` — `offers.color`/`offers.icon_key` (+ CHECKs), new `offer_branches` join (empty = all branches).
  - `2026-06-09-03-holiday-rules-applicability-visuals.sql` — `branch_holidays` recurrence (`recurrence_type`/`weekday`/`week_of_month`, day/end columns now nullable) + `icon_key`/`color`; new `branch_holiday_branches` join (backfilled from owning branch); `holiday_templates.icon_key`/`color`; new `scheduling.date_matches_nth_weekday` + `scheduling.holiday_covers_date`; `scheduling.is_branch_open` updated to use the holiday applicability join and honor `nth_weekday` recurrence.
- **Reason:** Backend features §1/§6/§7/§10 (service-extra quantities affecting price/duration & availability; per-branch promotions with visuals; recurring/multi-branch holidays with visuals + suggestions).
- **Impact:** Backend restarted (compiles 0 errors, `/api/health` 200). Scheduling availability now reflects recurring holidays and multi-branch holiday applicability. No applied migration was edited; all changes are new files.

### 2026-06-02
- **Changed:** Added the `docs/ai/` documentation set (incl. ENVIRONMENT.md) and `app-builder` / `app-builder-db` skills.
- **Reason:** Documentation-first workflow for future sessions.
- **Impact:** New sessions should read `docs/ai/INDEX.md` first; document every schema change in the db docs.

<!--
### YYYY-MM-DD
- **Changed:** ...
- **Reason:** ...
- **Impact:** ... (note backend entity / stack impact)
-->

> Must reflect real changes, not assumptions.
