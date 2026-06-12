# TASKS-LOG — Root / Infrastructure

## Purpose

Chronological log of completed infra/DB work (newest first).

## When to read

When you need history on how the infra reached its current state.

## Keep updated

After completing any meaningful task, append an entry at the top.

## Log

### 2026-06-12 — WhatsApp BYOA secrets + masking hints migration (046)
- **What:** Added migration `2026-06-12-whatsapp-byoa-and-hints.sql` (additive, idempotent) → `business_whatsapp_accounts` gains `app_secret_encrypted`, `verify_token_encrypted`, `access_token_last4`, `app_secret_last4`. Registered as docker-compose mount `046`; DER + TABLES-GUIDE updated.
- **Why:** Per-business manual Meta Cloud API setup — masked token display + a BYOA-ready seam (not activated; shared Klyro Meta App stays authoritative).
- **Files:** `backend/database/migrations/2026-06-12-whatsapp-byoa-and-hints.sql`, `root/docker-compose.yml`, `backend/database/docs/database-der.mmd`, `root/docs/ai/db/TABLES-GUIDE.md`.

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
