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
| `scheduling.is_worker_available(...)` | Composite: is the worker bookable for this slot? |

These back the appointment/availability logic — keep them consistent with the backend's appointments use-cases.

## Triggers

| Trigger | Table | Event | Function | Purpose |
| --- | --- | --- | --- | --- |
| _document any triggers from the SQL here_ | | | | |

## Notable constraints

- Status enums constrain valid states (see enums in `001-enums.sql`).
- `chk_appointments_blocked_time_range` and `chk_appointment_holds_blocked_time_range` require blocked intervals to contain the visible interval and remain non-empty.
- `appointment_holds_one_active_conversation_idx` enforces one active hold per conversation.
- _Document unique/check/exclusion constraints (e.g. preventing double-booking) and their business meaning as found in `002-tables.sql`._

> Must reflect the real current functions/triggers/constraints, not assumptions.
