# CHANGES — Root / Infrastructure

## Purpose

Changelog of meaningful infra/DB changes, newest first.

## When to read

At the start of any task, after MAP — to know what just changed.

## Keep updated

After every meaningful change, append an entry at the top. Flag changes affecting backend entities or the running stack.

## Changelog

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
