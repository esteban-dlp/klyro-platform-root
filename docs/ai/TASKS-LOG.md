# TASKS-LOG — Root / Infrastructure

## Purpose

Chronological log of completed infra/DB work (newest first).

## When to read

When you need history on how the infra reached its current state.

## Keep updated

After completing any meaningful task, append an entry at the top.

## Log

### 2026-07-21 — Correct Gemma catalog/provider registration
- **What:** added corrective migration `2026-07-21-07-ai-model-catalog-deepinfra-gemma-4-26b.sql`, registered the exact DeepInfra model and prices/context, disabled the old standalone row, and backfilled existing business settings.
- **Apply:** new/existing databases apply migration `07` after the immutable `05`/`06` history; Compose mount order `092` is registered and no volume reset is required.

### 2026-07-15 — Auth identity uniqueness migration
- **What:** Added a safe, idempotent unique index for active external auth identities.
- **Apply:** Use the normal migration runner on existing volumes; do not delete the database volume.

### 2026-07-03 - Branch type: physical vs online
- **What:** Added runner-only migration `2026-07-03-01-branch-type.sql`: `branch_type_enum` (`physical`/`online`) + `branches.type` (default `physical`) + partial index `idx_branches_business_type` on `(business_id, type)`.
- **Why:** The onboarding "online / mobile" option was creating an ordinary physical branch, wrongly counted against the plan's branch limit and indistinguishable from a real location in the UI.
- **Decisions:** Typed the branch instead of going branch-less, since appointments/schedules/opening-hours all require a branch row. Singleton + plan-exemption enforcement lives in `CreateBranchUseCase` (application-level), not a DB constraint — the DB only guarantees the enum + a lookup index. Did not touch `root/docker-compose.yml`; picked up by the migration runner like other post-baseline migrations.
- **Files:** `backend/database/migrations/2026-07-03-01-branch-type.sql`, `backend/src/database/enums/index.ts`, `backend/src/modules/businesses/{entities/branch.entity.ts,dto/create-branch.dto.ts,mappers/business.mapper.ts,use-cases/create-branch.use-case.ts}`, `backend/src/common/swagger/response-dtos.ts`, `root/docs/ai/{CHANGES.md,CURRENT-STATE.md,TASKS-LOG.md,db/DB-MAP.md,db/TABLES-GUIDE.md}`.

### 2026-07-02 - Plan pricing and AI credit recalibration
- **What:** Added runner-only migrations for plan packaging: `2026-07-02-02-plan-credit-recalibration.sql` updates Free/Pro/Max prices, credits, and Pro caps; `2026-07-02-03-free-plan-whatsapp.sql` enables WhatsApp on Free without modifying the checksum-pinned `02` migration.
- **Why:** Align the plan catalog with the revised commercial packaging and monthly AI budgets.
- **Decisions:** Kept this as data-only migrations instead of editing `005-seed-plans.sql`. Restored `02` to the originally applied content and moved the later WhatsApp change to `03` because applied migration files are checksum-pinned. Did not touch `root/docker-compose.yml`; normal migrations are picked up by the migration runner.
- **Files:** `backend/database/migrations/2026-07-02-02-plan-credit-recalibration.sql`, `backend/database/migrations/2026-07-02-03-free-plan-whatsapp.sql`, `root/docs/ai/CHANGES.md`, `root/docs/ai/CURRENT-STATE.md`, `root/docs/ai/TASKS-LOG.md`, `root/docs/ai/db/DB-MAP.md`, `root/docs/ai/db/TABLES-GUIDE.md`.

### 2026-06-29 - Worker free windows can exclude rescheduled appointment
- **What:** Added migration `2026-06-29-01-worker-free-windows-exclude-appointment.sql`, replacing
  `scheduling.worker_free_windows` with a defaulted `p_exclude_appointment_id` parameter and using it to ignore the
  appointment being moved during free-window calculation.
- **Why:** Reschedule searches must not treat the original appointment as a blocker for its own replacement slot.
- **Decisions:** Kept this as a runner-only normal migration; `root/docker-compose.yml` was not touched per
  `backend/database/DB-INSTRUCTIONS.md`.
- **Files:** `backend/database/migrations/2026-06-29-01-worker-free-windows-exclude-appointment.sql`,
  `root/docs/ai/db/FUNCTIONS-TRIGGERS-GUIDE.md`, `root/docs/ai/db/DB-MAP.md`, root changelog/task log.

### 2026-06-16 - AI regional language style migration (Phase 4)
- **What:** Added migration `2026-06-16-02-ai-regional-style.sql` adding `business_ai_settings.regional_style` (`varchar(20)` `NOT NULL DEFAULT 'auto'`) + idempotent CHECK `chk_business_ai_settings_regional_style` (`auto`/`neutral`/`gt`/`mx`/`co`/`ar`/`cl`/`es`). Updated the ER model and the db living docs.
- **Why:** Phase 4 (Regional Language Style) — give owners a subtle regional Spanish register knob, subordinate to the client's detected language, without changing current behavior on deploy.
- **Decisions:** varchar+CHECK (not a PG enum) so countries can be added incrementally. Behavior-neutral via `DEFAULT 'auto'`; `auto` resolves neutral on the conversation hot path because the business ISO country code is not cheaply reachable there. Did NOT touch `root/docker-compose.yml` (normal migrations are runner-only).
- **Files:** `backend/database/migrations/2026-06-16-02-ai-regional-style.sql`, `backend/database/docs/database-der.mmd`, `root/docs/ai/db/TABLES-GUIDE.md`, `root/docs/ai/db/DB-MAP.md`, `root/docs/ai/CHANGES.md`, `root/docs/ai/CURRENT-STATE.md`.

### 2026-06-16 - AI response length setting migration (Phase 3a)
- **What:** Added migration `2026-06-16-01-ai-response-length.sql` creating `ai_response_length_enum` (`short`/`normal`/`detailed`) and the `business_ai_settings.response_length` column (`NOT NULL DEFAULT 'normal'`), mirroring the `2026-06-05-01-ai-emoji-usage.sql` pattern (enum type + additive column). Updated the ER model and the db living docs.
- **Why:** Phase 3a (Response Length Control) — give business owners a voice setting for how verbose the AI's client-facing messages are, without changing current behavior on deploy.
- **Decisions:** Behavior-neutral via `DEFAULT 'normal'` (= today's behavior). Did NOT touch `root/docker-compose.yml` — normal migrations are runner-only per `DB-INSTRUCTIONS.md` (folder picked up directly by the `migrations` service / `npm run db:migrate`). No backend TypeScript or frontend changes (out of scope for this migration).
- **Files:** `backend/database/migrations/2026-06-16-01-ai-response-length.sql`, `backend/database/docs/database-der.mmd`, `root/docs/ai/db/TABLES-GUIDE.md`, `root/docs/ai/db/DB-MAP.md`, `root/docs/ai/CHANGES.md`, `root/docs/ai/CURRENT-STATE.md`.

### 2026-06-15 - Multi-channel messaging DB foundation (070-079)
- **What:** Added the multi-channel messaging migration sequence (compose `070`-`079`) for Phase 1 of the multi-channel messaging plan: the `instagram` channel value + two channel-generic enums; the canonical `business_channel_accounts` table; WhatsApp detail table; `channel_onboarding_sessions`; `client_channel_identities`; additive `conversations` channel fields + `notifications.channel`; outbox/notification seeds; and an id-preserving WhatsApp -> channel-account backfill. Updated `root/docker-compose.yml`, the ER model, and the db living docs.
- **Why:** Generalize the WhatsApp-only model and add Instagram DMs behind a channel abstraction without breaking WhatsApp (expand + backfill; legacy drop deferred).
- **Decisions:** Backfill preserves the original WhatsApp account id as the new channel-account id (1:1 conversation rebind); legacy id also stored in `channel_metadata`. Added `notifications.channel` (no `metadata jsonb` on that table). WhatsApp `client_channel_identities` backfill skipped (phone-based resolution retained).
- **Files:** `backend/database/migrations/2026-06-15-05..14-*.sql`, `root/docker-compose.yml`, `backend/database/docs/database-der.mmd`, and the root db docs. Apply to existing volumes via `psql` (enum migrations un-wrapped).

### 2026-06-13 - Added appointment blocked intervals (060)
- **What:** Added an idempotent migration for appointment/hold blocked intervals, constraints, partial indexes, and updated scheduling conflict functions. Registered it after mount `059`, updated the ER model, applied it to the running local DB, and reran it successfully.
- **Why:** Search, holds, conflict validation, and final appointments must reserve the same duration-plus-buffers interval while preserving customer-visible service times.
- **Files:** `backend/database/migrations/2026-06-13-14-appointment-blocked-intervals.sql`, `backend/database/docs/database-der.mmd`, `root/docker-compose.yml`, and root database documentation.

### 2026-06-12 — Fix missing `branch_id` on `business_whatsapp_accounts` (047)
- **What:** Added migration `2026-06-12-02-whatsapp-account-branch-id.sql` (mount `047`) adding the nullable `branch_id` column + composite FK `(branch_id, business_id) → branches (id, business_id)` + partial index.
- **Why:** The entity/mapper/DTO/ER model expected `branch_id` but init never created it; TypeORM's INSERT failed with `column "branch_id" does not exist`, blocking manual Meta connect + onboarding.
- **Files:** `backend/database/migrations/2026-06-12-02-whatsapp-account-branch-id.sql`, `root/docker-compose.yml`. Apply to existing volumes via `psql` (not auto-run on existing volumes).

### 2026-06-12 — WhatsApp BYOA secrets + masking hints migration (046)
- **What:** Added migration `2026-06-12-01-whatsapp-byoa-and-hints.sql` (additive, idempotent) → `business_whatsapp_accounts` gains `app_secret_encrypted`, `verify_token_encrypted`, `access_token_last4`, `app_secret_last4`. Registered as docker-compose mount `046`; DER + TABLES-GUIDE updated.
- **Why:** Per-business manual Meta Cloud API setup — masked token display + a BYOA-ready seam (not activated; shared Klyro Meta App stays authoritative).
- **Files:** `backend/database/migrations/2026-06-12-01-whatsapp-byoa-and-hints.sql`, `root/docker-compose.yml`, `backend/database/docs/database-der.mmd`, `root/docs/ai/db/TABLES-GUIDE.md`.

### 2026-06-02 — AI documentation system initialized
- **What:** Created `docs/ai/` structure (incl. ENVIRONMENT.md) and the `app-builder` / `app-builder-db` skills.
- **Why:** Establish a documentation-first workflow for future Claude Code sessions.
- **Files:** `root/.claude/skills/**`, `root/docs/ai/**`.

<!--
### YYYY-MM-DD — <title>
- **What:** ...
- **Why:** ...
- **Files:** ...
-->

> Must reflect work actually completed, not assumptions.
