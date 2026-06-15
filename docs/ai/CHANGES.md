# CHANGES — Root / Infrastructure

## Purpose

Changelog of meaningful infra/DB changes, newest first.

## When to read

At the start of any task, after MAP — to know what just changed.

## Keep updated

After every meaningful change, append an entry at the top. Flag changes affecting backend entities or the running stack.

## Changelog

### 2026-06-15 — Service AI insights column (migration 069)
- **Changed:** New migration `2026-06-15-service-ai-insights.sql` (compose mount `069`). Adds `services.ai_insights JSONB` (+ CHECK `chk_services_ai_insights_object` = object when present).
- **Reason:** Phase 3+4 of the "AI Business Assistant". Stores OPTIONAL AI-authored service insights (`{idealFor[], notIdealFor[], intakeQuestions[], suggestedExtras[], source, generatedAt}`) — produced by the AI service-authoring endpoint, injected candidate-only into the AI receptionist prompt.
- **Impact:** Additive/nullable/idempotent. Existing volumes require manual application (`psql`). No applied migration edited.

### 2026-06-15 — Appointment AI worker-summary column (migration 068)
- **Changed:** New migration `2026-06-15-appointment-ai-summary.sql` (compose mount `068`). Adds `appointments.ai_summary JSONB` (+ CHECK = object when present).
- **Reason:** Phase 2 of the "AI Business Assistant". Stores a template-first, AI-generated worker-preparation summary (`{summary, highlights[], preparationNotes[], source, generatedAt}`), separate from human `appointments.notes`.
- **Impact:** Additive/nullable/idempotent. Existing volumes require manual application (`psql`). No applied migration edited.

### 2026-06-15 — AI discovery mode kill switch (migration 067)
- **Changed:** New migration `2026-06-15-ai-discovery-mode.sql` (compose mount `067`). Adds `business_ai_settings.discovery_mode_enabled BOOLEAN NOT NULL DEFAULT true`.
- **Reason:** Phase 1 of the "AI Business Assistant" evolution. Per-business kill switch for the new need-discovery / advisory conversation behavior; ships ON globally, any business can revert to legacy fast-booking without a global flag flip.
- **Impact:** Additive/defaulted/idempotent. Backend entity `BusinessAiSettings.discoveryModeEnabled` maps the column. Existing volumes require manual application (`psql`). No applied migration edited.

### 2026-06-13 - Appointment blocked intervals and scheduling functions (migration 060)
- **Changed:** Added `2026-06-13-appointment-blocked-intervals.sql`, mounted as compose step `060`. Appointments and appointment holds gain non-null `blocked_start_at`/`blocked_end_at`, backfilled from visible times for existing rows.
- **Scheduling:** worker conflict indexes and `scheduling.has_active_hold_conflict`, `scheduling.has_appointment_conflict`, and `scheduling.is_worker_available_for_booking` now use blocked intervals.
- **Impact:** `start_at`/`end_at` remain customer-visible. Backend entities and writes must populate blocked intervals with service duration plus both buffers. Applied successfully to the running local volume and rerun to verify idempotency; other existing volumes require manual application.

### 2026-06-12 — Fix: add missing `branch_id` to `business_whatsapp_accounts` (migration 047)
- **Changed:** New migration `2026-06-12-whatsapp-account-branch-id.sql` (mount `047`). Adds the nullable `branch_id` column (+ composite FK to `branches (id, business_id)` + partial index) that the entity/mapper/DTO/ER model already expected but the init schema never created.
- **Reason:** TypeORM emitted `branch_id` in every `business_whatsapp_accounts` INSERT, so Postgres rejected connect/onboarding with `column "branch_id" ... does not exist`. Pre-existing schema drift surfaced by the first manual Meta connect.
- **Impact:** Manual Meta connect + 360dialog onboarding can now insert. Additive/nullable; must be applied to existing volumes via `psql` (does not auto-run on an existing volume).

### 2026-06-12 — WhatsApp BYOA-ready secrets + masking hints (migration 046)
- **Changed:** New migration `2026-06-12-whatsapp-byoa-and-hints.sql` (registered in `docker-compose.yml` as mount `046`). Adds to `business_whatsapp_accounts`: `app_secret_encrypted TEXT`, `verify_token_encrypted TEXT` (both BYOA-ready, encrypted, NULL today), and non-secret masking hints `access_token_last4 VARCHAR(8)`, `app_secret_last4 VARCHAR(8)`. All additive/nullable/idempotent. DER updated.
- **Reason:** "Per-Business Manual Meta Cloud API (WhatsApp) Setup" — let the UI render a masked token tail (`••••••ABCD`) and leave a clean seam for future bring-your-own-app verification.
- **Impact:** No behavior change. Per-business webhook verification is **not** activated; the shared Klyro Meta App (global `META_APP_SECRET`/`META_VERIFY_TOKEN`) stays authoritative. No applied migration edited.

### 2026-06-09 — Service-extra quantity, offer branch scoping/visuals, holiday rules/applicability/visuals
- **Changed:** Three new migrations (registered in `docker-compose.yml` as mounts 037–039, applied to the running volume via `psql`, no volume reset):
  - `2026-06-09-service-extra-quantity.sql` — `services_extras.min_quantity`/`max_quantity` (+ CHECKs), `appointment_extras.quantity` (+ CHECK).
  - `2026-06-09-offer-branches-visuals.sql` — `offers.color`/`offers.icon_key` (+ CHECKs), new `offer_branches` join (empty = all branches).
  - `2026-06-09-holiday-rules-applicability-visuals.sql` — `branch_holidays` recurrence (`recurrence_type`/`weekday`/`week_of_month`, day/end columns now nullable) + `icon_key`/`color`; new `branch_holiday_branches` join (backfilled from owning branch); `holiday_templates.icon_key`/`color`; new `scheduling.date_matches_nth_weekday` + `scheduling.holiday_covers_date`; `scheduling.is_branch_open` updated to use the holiday applicability join and honor `nth_weekday` recurrence.
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
