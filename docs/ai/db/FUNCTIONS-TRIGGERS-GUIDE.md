# FUNCTIONS-TRIGGERS-GUIDE

## Messaging reliability triggers (2026-08-04)

`trg_messaging_operational_issues_set_updated_at` and `trg_message_delivery_holds_set_updated_at` reuse `set_updated_at()`. Check constraints enforce valid origins, severities, scopes, owners, hold states, freshness policies and resolution timestamps.

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

Source: `database/migrations/2026-07-30-03-ai-usage-ledger.sql`.

| Function | Purpose (business) |
| --- | --- |
| `open_or_touch_ai_conversation_window(business_id, conversation_id, at, period_start, period_end)` | Opens the 24h window a call belongs to, or returns the existing one. Returns `was_created` because opening a window IS what consumes one of a plan's published conversations — the caller must be able to tell an open from a touch without racing a second SELECT (`xmax = 0` is the standard way to distinguish a fresh INSERT from an ON CONFLICT update). The plain UNIQUE on `(conversation_id, window_key)` is what serializes concurrent openers: 20 simultaneous first turns produce exactly one window, with no advisory lock. |
| `touch_conversation_window_cost(window_id, cost_usd, cost_kind, is_retry, used_fallback)` | Accrues one attempt's fully-loaded cost onto its window, splitting text / multimodal / retry so cost drift can be attributed to a cause rather than merely observed. |
| `increment_business_ai_usage(business_id, period_start, period_end, ai_runtime_cost, owner_ai_cost, input_tokens, output_tokens, llm_calls, conversations)` | The ONLY way app code mutates `business_ai_usage_periods`. Atomic upsert-and-add, negatives clamped to 0. All money arithmetic happens here rather than in TypeScript: `pg` returns NUMERIC as a string, and adding money in JavaScript is how precision quietly disappears. |

Source: `database/migrations/2026-07-30-01-platform-settings.sql`.

| Function | Purpose (business) |
| --- | --- |
| `platform_settings_bump_version()` | Makes the version number of a commercial setting the database's responsibility, not the caller's — an update that changes `value` bumps `version` and stamps `updated_at`; an update that only edits the description does neither. Prevents a config change from being silently untraceable because app code forgot to increment. |
| `platform_settings_write_audit()` | Writes the append-only audit row for every settings change. Reads the actor from the `klyro.actor_id` session variable (`SET LOCAL` inside the app's transaction) and records NULL when absent, so a manual `psql` edit is still captured and flagged as unattributed. Skips description-only edits, so the audit stays a record of economic changes. Never blocks the change: `changed_by` is not foreign-keyed on purpose. |

## Triggers

| Trigger | Table | Event | Function | Purpose |
| --- | --- | --- | --- | --- |
| `set_updated_at()` triggers | most tables w/ `updated_at` | BEFORE UPDATE | `set_updated_at()` | Stamp `updated_at = now()` on row update |
| `trg_business_channel_accounts_set_updated_at` | `business_channel_accounts` | BEFORE UPDATE | `set_updated_at()` | Stamp `updated_at` on channel-account changes |
| `trg_channel_onboarding_sessions_set_updated_at` | `channel_onboarding_sessions` | BEFORE UPDATE | `set_updated_at()` | Stamp `updated_at` on onboarding-session changes |
| `trg_client_channel_identities_set_updated_at` | `client_channel_identities` | BEFORE UPDATE | `set_updated_at()` | Stamp `updated_at` on identity changes |
| `trg_platform_settings_bump_version` | `platform_settings` | BEFORE UPDATE | `platform_settings_bump_version()` | Bump `version` + `updated_at` only when the value actually changed |
| `trg_platform_settings_write_audit` | `platform_settings` | AFTER INSERT OR UPDATE | `platform_settings_write_audit()` | Record the before/after of every commercial-number change, including manual `psql` edits |

## Notable constraints

- `users_auth_identity_unique_idx` prevents an active external identity (`auth_provider` + `auth_provider_id`) from being linked to more than one user. Null provider IDs are excluded so local users remain valid.

- Status enums constrain valid states (see enums in `001-enums.sql`).
- `chk_appointments_blocked_time_range` and `chk_appointment_holds_blocked_time_range` require blocked intervals to contain the visible interval and remain non-empty.
- `appointment_holds_one_active_conversation_idx` enforces one active hold per conversation.
- `chk_bca_connected_requires_token` / `chk_bca_disconnected_requires_ts` on `business_channel_accounts`: a `connected` account must have a token, a connect timestamp, and a routing key; a `disconnected` account must have a disconnect timestamp (mirrors the WhatsApp account CHECKs).
- `business_channel_accounts_channel_routing_unique_idx`: one live account per `(channel, inbound_routing_key)` (ignores soft-deleted rows so accounts can be reconnected).
- `client_channel_identities_unique_idx`: one live identity per `(business_id, channel, business_channel_account_id, external_participant_id)`.
- `chk_channel_onboarding_state_nonce_length`: the onboarding CSRF nonce must be ≥16 chars.
- `chk_platform_settings_key_format`: a settings key must be dotted lowercase snake (`^[a-z0-9_]+(\.[a-z0-9_]+)+$`), so keys stay namespaced (`pool.*`, `cost.*`, `warning.*`) and a typo cannot create a stray sibling knob.
- `chk_platform_settings_value_type`: `value_type` is one of `percent`/`integer`/`money_usd`/`string`/`list` — documentation for operators, while the real per-key validation lives in the backend registry.
- _Document unique/check/exclusion constraints (e.g. preventing double-booking) and their business meaning as found in `002-tables.sql`._

> Must reflect the real current functions/triggers/constraints, not assumptions.
