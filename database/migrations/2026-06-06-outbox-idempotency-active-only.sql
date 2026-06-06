-- 2026-06-06 — Outbox idempotency uniqueness applies to ACTIVE events only
-- Fix: a COMPLETED conversation.process event poisoned its idempotency key
-- (`conversation.process:<conv>:<lastProcessedAt>`), so the next inbound message
-- (which reuses that key while last_processed_at is unchanged) was deduped away
-- and never processed — the simulator/WhatsApp would reply once, then go silent.
--
-- Terminal events (completed/cancelled/dead_letter) must NOT participate in the
-- idempotency unique index; uniqueness only matters for in-flight work
-- (pending/processing) and retryable failures (failed). Idempotent.

DROP INDEX IF EXISTS outbox_events_idempotency_unique_idx;

CREATE UNIQUE INDEX IF NOT EXISTS outbox_events_idempotency_unique_idx
    ON outbox_events (idempotency_key)
    WHERE idempotency_key IS NOT NULL
      AND deleted_at IS NULL
      AND status NOT IN (
          'completed'::outbox_event_status_enum,
          'cancelled'::outbox_event_status_enum,
          'dead_letter'::outbox_event_status_enum
      );
