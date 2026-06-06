-- 2026-06-05 — Simulated appointments flag
-- Adds `appointments.is_simulated` so AI-simulator bookings are persisted but
-- excluded from the real calendar/listings (same philosophy as `source='demo'`
-- clients and `conversations.state.simulated`). Idempotent; safe to re-run.

ALTER TABLE appointments
    ADD COLUMN IF NOT EXISTS is_simulated boolean NOT NULL DEFAULT false;

-- Real calendar/listing queries filter on this; partial index keeps them fast.
CREATE INDEX IF NOT EXISTS appointments_real_start_idx
    ON appointments (business_id, start_at)
    WHERE is_simulated = false;

-- Conflict detection must ignore simulator bookings: real appointments are not
-- blocked by simulated ones, while a simulated booking still respects the real
-- calendar (real rows are still counted).
CREATE OR REPLACE FUNCTION scheduling.has_appointment_conflict(
    p_business_id UUID,
    p_worker_id UUID,
    p_start_at TIMESTAMPTZ,
    p_end_at TIMESTAMPTZ,
    p_exclude_appointment_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.appointments appointment
        WHERE appointment.business_id = p_business_id
          AND appointment.worker_id = p_worker_id
          AND appointment.deleted_at IS NULL
          AND appointment.is_simulated = false
          AND appointment.status IN (
              'pending'::public.appointment_status_enum,
              'confirmed'::public.appointment_status_enum
          )
          AND appointment.start_at < p_end_at
          AND appointment.end_at > p_start_at
          AND (
              p_exclude_appointment_id IS NULL
              OR appointment.id <> p_exclude_appointment_id
          )
    );
$$;
