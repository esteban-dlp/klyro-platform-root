# CHANGES — Root / Infrastructure

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
