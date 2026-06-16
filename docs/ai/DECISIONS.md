# DECISIONS — Root / Infrastructure

## Purpose

Lightweight decision log (ADR-style) for infra/DB.

## When to read

When a change touches an architectural choice, or you're tempted to "do it differently."

## Keep updated

Add an entry for every non-trivial technical decision; supersede rather than delete.

## Decisions

### 2026-06-15 — Multi-channel messaging: parent/detail account model (WhatsApp detail keeps real FKs)
- **Context:** WhatsApp accounts carry relational fields — above all `business_phone_number_id` (composite FK to `business_phone_numbers`). Flattening these into the canonical parent `business_channel_accounts` would force them into JSONB and lose foreign-key integrity.
- **Decision:** Use a **parent/detail model**. `business_channel_accounts` stays the channel-agnostic parent (common fields only). A new WhatsApp DETAIL table `business_whatsapp_channel_accounts` holds the WhatsApp-only relational fields with **real composite FKs** (`business_phone_number_id` → `business_phone_numbers`), one-to-one with the parent via a UNIQUE `channel_account_id` and a composite FK `(channel_account_id, business_id)` → `business_channel_accounts (id, business_id)`. The backfill writes both the parent and the detail row (id-preserving, idempotent). Instagram uses the **parent table only** in Phase 1; a `business_instagram_channel_accounts` detail table is the documented future extension point.
- **Rationale:** Preserves tenant-safe FK integrity (no relational data in JSONB), keeps the parent clean and channel-agnostic, and avoids a giant nullable-column table.
- **Sub-decisions:** Parent `channel_metadata` now carries only `legacy_whatsapp_account_id` for traceability (WhatsApp relational fields moved to the detail). WhatsApp **runtime code is NOT re-typed** onto the new model this phase (deferred, test-gated); the new entity is additive. Compose order: detail table (072) before backfill (079).
- **Status:** accepted (Phase 1 DB foundation; supersedes the JSONB-in-parent aspect of the entry below).

### 2026-06-15 — Multi-channel messaging: unified channel-account model + id-preserving backfill
- **Context:** Messaging was WhatsApp-only (`business_whatsapp_accounts`, `conversations.business_whatsapp_account_id`). Adding Instagram needs a channel/provider abstraction without breaking WhatsApp.
- **Decision:** Introduce a canonical, channel-agnostic `business_channel_accounts` table (plus `channel_onboarding_sessions` and `client_channel_identities`) and additive `conversations` channel fields. Backfill existing WhatsApp accounts **preserving the original id** as the new channel-account id, so the conversation rebind is a 1:1 copy; the legacy id is also stored in `channel_metadata.legacy_whatsapp_account_id`. Legacy WhatsApp table/column are kept (expand + backfill) and dropped only by a later, separately-approved contract migration.
- **Rationale:** Id preservation makes the backfill deterministic, trivially idempotent, and the conversation binding a simple copy. Additive-only changes preserve instant rollback and keep WhatsApp untouched.
- **Sub-decisions:** `notifications` gained a dedicated nullable `channel` column (it has no `metadata jsonb`). The Instagram enum value lives alone in an un-wrapped migration (`ADD VALUE` can't run in / be used in the same tx). WhatsApp `client_channel_identities` backfill skipped — WhatsApp resolution stays phone-based.
- **Status:** accepted (Phase 1 DB foundation).

### 2026-06-13 - Scheduling conflicts use explicit blocked intervals
- **Context:** Customer-visible appointment duration and worker capacity differ when services have buffers.
- **Decision:** Preserve visible `start_at`/`end_at`, and use non-null `blocked_start_at`/`blocked_end_at` for worker conflict functions and indexes on both appointments and holds.
- **Rationale:** One interval contract for search, temporary holds, and final bookings prevents buffer mismatches without changing what the client sees.
- **Status:** accepted.

### 2026-06-02 — Database is the schema source of truth (raw SQL)
- **Context:** Need an authoritative schema independent of ORM specifics.
- **Decision:** Schema is defined in raw SQL under `database/` (`init/` for first boot, `migrations/` for changes); backend TypeORM entities map onto it.
- **Rationale:** Explicit, reviewable schema; portable; clear ordering.
- **Consequences:** Schema changes are SQL-first; keep entities in sync.
- **Status:** accepted (observed).

### 2026-06-02 — New migrations only; never edit applied SQL
- **Context:** Deployed databases must not diverge from history.
- **Decision:** All schema changes go in new, ordered migration files; `init/` and applied migrations are immutable.
- **Rationale:** Safe, reproducible evolution.
- **Consequences:** Even small tweaks become a new migration.
- **Status:** accepted.

### 2026-06-02 — Compose-driven local stack with ordered init mounts
- **Context:** One-command local environment.
- **Decision:** `docker-compose.yml` runs postgres/backend/frontend; init + seed SQL mounted into `/docker-entrypoint-initdb.d` in numeric order.
- **Rationale:** Deterministic first-boot schema + seed.
- **Consequences:** File ordering (enums → tables → functions → seeds) must be preserved.
- **Status:** accepted.

<!-- New decisions above this line. -->

> Must reflect real decisions, not assumptions.
