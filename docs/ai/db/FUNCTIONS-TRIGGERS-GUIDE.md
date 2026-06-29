# FUNCTIONS-TRIGGERS-GUIDE

## Purpose

Database-side logic: functions, triggers, constraints — what they do and why.

## When to read

Before changing schema logic, scheduling, or anything interacting with a function/trigger.

## Keep updated

When a function, trigger, or notable constraint changes.

## Functions (`scheduling` schema)

Source: `database/init/003-scheduling-functions.sql`.

| Function | Purpose (business) |
| --- | --- |
| `scheduling.resolve_availability_timezone(...)` | Resolve the effective timezone for availability checks |
| `scheduling.has_covering_worker_schedule(...)` | Is the worker scheduled to work at the requested time? |
| `scheduling.has_covering_branch_opening_hour(...)` | Is the branch open at the requested time? |
| `scheduling.has_blocking_branch_override(...)` | Does a branch override block this time? |
| `scheduling.has_blocking_worker_override(...)` | Does a worker override block this time? |
| `scheduling.has_active_hold_conflict(...)` | Does the worker's requested blocked interval overlap another live hold? |
| `scheduling.has_appointment_conflict(...)` | Does the worker's requested blocked interval overlap an active appointment or live hold? |
| `scheduling.is_worker_available_for_booking(...)` | Composite exact-booking validation using opening rules and blocked appointment/hold intervals, with exclusion ids for reschedule/hold replacement. |
| `scheduling.worker_free_windows(..., p_exclude_appointment_id DEFAULT NULL)` | Returns continuous worker free ranges for availability search; can ignore the appointment being rescheduled so it does not block its own new slot. |
| `scheduling.is_worker_available(...)` | Composite: is the worker bookable for this slot? |

These back the appointment/availability logic — keep them consistent with the backend's appointments use-cases.

## Functions (`public` schema)

Source: `database/migrations/2026-06-22-03-usage-counters-credits-and-increment-fn.sql`.

| Function | Purpose (business) |
| --- | --- |
| `increment_usage_counter(business_id, period_start, period_end, input_tokens, output_tokens, credits, ai_requests)` | The ONLY way app code mutates `usage_counters`. Upsert-and-add: creates the per-business per-period row if missing, else atomically adds the deltas (input/output tokens, LLM credits, AI requests). Negative deltas are clamped to 0. Conflict target = the `(business_id, period_start, period_end)` unique index. Called by `CreditsService.deductForLlmCall` on every LLM call. |

## Triggers

| Trigger | Table | Event | Function | Purpose |
| --- | --- | --- | --- | --- |
| `set_updated_at()` triggers | most tables w/ `updated_at` | BEFORE UPDATE | `set_updated_at()` | Stamp `updated_at = now()` on row update |
| `trg_business_channel_accounts_set_updated_at` | `business_channel_accounts` | BEFORE UPDATE | `set_updated_at()` | Stamp `updated_at` on channel-account changes |
| `trg_channel_onboarding_sessions_set_updated_at` | `channel_onboarding_sessions` | BEFORE UPDATE | `set_updated_at()` | Stamp `updated_at` on onboarding-session changes |
| `trg_client_channel_identities_set_updated_at` | `client_channel_identities` | BEFORE UPDATE | `set_updated_at()` | Stamp `updated_at` on identity changes |

## Notable constraints

- Status enums constrain valid states (see enums in `001-enums.sql`).
- `chk_appointments_blocked_time_range` and `chk_appointment_holds_blocked_time_range` require blocked intervals to contain the visible interval and remain non-empty.
- `appointment_holds_one_active_conversation_idx` enforces one active hold per conversation.
- `chk_bca_connected_requires_token` / `chk_bca_disconnected_requires_ts` on `business_channel_accounts`: a `connected` account must have a token, a connect timestamp, and a routing key; a `disconnected` account must have a disconnect timestamp (mirrors the WhatsApp account CHECKs).
- `business_channel_accounts_channel_routing_unique_idx`: one live account per `(channel, inbound_routing_key)` (ignores soft-deleted rows so accounts can be reconnected).
- `client_channel_identities_unique_idx`: one live identity per `(business_id, channel, business_channel_account_id, external_participant_id)`.
- `chk_channel_onboarding_state_nonce_length`: the onboarding CSRF nonce must be ≥16 chars.
- _Document unique/check/exclusion constraints (e.g. preventing double-booking) and their business meaning as found in `002-tables.sql`._

> Must reflect the real current functions/triggers/constraints, not assumptions.
