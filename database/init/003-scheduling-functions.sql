-- =========================================================
-- Scheduling functions
-- =========================================================

CREATE SCHEMA IF NOT EXISTS scheduling;

CREATE OR REPLACE FUNCTION scheduling.resolve_availability_timezone(
    p_business_id UUID,
    p_branch_id UUID DEFAULT NULL
)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        (
            SELECT b.timezone
            FROM public.branches b
            WHERE b.id = p_branch_id
              AND b.business_id = p_business_id
              AND b.deleted_at IS NULL
            LIMIT 1
        ),
        (
            SELECT bu.timezone
            FROM public.businesses bu
            WHERE bu.id = p_business_id
              AND bu.deleted_at IS NULL
            LIMIT 1
        ),
        'UTC'
    );
$$;

CREATE OR REPLACE FUNCTION scheduling.has_covering_worker_schedule(
    p_business_id UUID,
    p_worker_id UUID,
    p_branch_id UUID,
    p_start_at TIMESTAMPTZ,
    p_end_at TIMESTAMPTZ
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    WITH local_range AS (
        SELECT
            p_start_at AT TIME ZONE scheduling.resolve_availability_timezone(p_business_id, p_branch_id) AS start_local,
            p_end_at AT TIME ZONE scheduling.resolve_availability_timezone(p_business_id, p_branch_id) AS end_local
    )
    SELECT CASE
        WHEN (SELECT start_local::date FROM local_range) <> (SELECT end_local::date FROM local_range)
            THEN false
        ELSE EXISTS (
            SELECT 1
            FROM public.worker_schedules ws
            CROSS JOIN local_range lr
            WHERE ws.business_id = p_business_id
              AND ws.worker_id = p_worker_id
              AND (
                  (p_branch_id IS NULL AND ws.branch_id IS NULL)
                  OR (p_branch_id IS NOT NULL AND (ws.branch_id = p_branch_id OR ws.branch_id IS NULL))
              )
              AND ws.day_of_week = EXTRACT(ISODOW FROM lr.start_local)::SMALLINT
              AND ws.start_time <= lr.start_local::time
              AND lr.end_local::time <= ws.end_time
              AND ws.is_active = true
              AND ws.deleted_at IS NULL
        )
    END;
$$;

CREATE OR REPLACE FUNCTION scheduling.has_covering_branch_opening_hour(
    p_business_id UUID,
    p_branch_id UUID,
    p_start_at TIMESTAMPTZ,
    p_end_at TIMESTAMPTZ
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    WITH local_range AS (
        SELECT
            p_start_at AT TIME ZONE scheduling.resolve_availability_timezone(p_business_id, p_branch_id) AS start_local,
            p_end_at AT TIME ZONE scheduling.resolve_availability_timezone(p_business_id, p_branch_id) AS end_local
    )
    SELECT CASE
        WHEN p_branch_id IS NULL
            THEN false
        WHEN (SELECT start_local::date FROM local_range) <> (SELECT end_local::date FROM local_range)
            THEN false
        ELSE EXISTS (
            SELECT 1
            FROM public.branch_opening_hours boh
            CROSS JOIN local_range lr
            WHERE boh.business_id = p_business_id
              AND boh.branch_id = p_branch_id
              AND boh.day_of_week = EXTRACT(ISODOW FROM lr.start_local)::SMALLINT
              AND boh.start_time <= lr.start_local::time
              AND lr.end_local::time <= boh.end_time
              AND boh.is_active = true
              AND boh.deleted_at IS NULL
        )
    END;
$$;

CREATE OR REPLACE FUNCTION scheduling.has_blocking_branch_override(
    p_business_id UUID,
    p_branch_id UUID,
    p_start_at TIMESTAMPTZ,
    p_end_at TIMESTAMPTZ
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT p_branch_id IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM public.branch_availability_overrides override_row
            INNER JOIN public.availability_override_types type_row
                ON type_row.id = override_row.override_type_id
               AND type_row.blocks_availability = true
            INNER JOIN public.branch_availability_override_branches target
                ON target.override_id = override_row.id
               AND target.business_id = override_row.business_id
               AND target.branch_id = p_branch_id
            WHERE override_row.business_id = p_business_id
              AND override_row.deleted_at IS NULL
              AND override_row.start_at < p_end_at
              AND override_row.end_at > p_start_at
       );
$$;

CREATE OR REPLACE FUNCTION scheduling.has_blocking_worker_override(
    p_business_id UUID,
    p_worker_id UUID,
    p_start_at TIMESTAMPTZ,
    p_end_at TIMESTAMPTZ
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.worker_availability_overrides override_row
        INNER JOIN public.availability_override_types type_row
            ON type_row.id = override_row.override_type_id
           AND type_row.blocks_availability = true
        INNER JOIN public.worker_availability_override_workers target
            ON target.override_id = override_row.id
           AND target.business_id = override_row.business_id
           AND target.worker_id = p_worker_id
        WHERE override_row.business_id = p_business_id
          AND override_row.deleted_at IS NULL
          AND override_row.start_at < p_end_at
          AND override_row.end_at > p_start_at
    );
$$;

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

CREATE OR REPLACE FUNCTION scheduling.is_worker_available(
    p_business_id UUID,
    p_branch_id UUID,
    p_worker_id UUID,
    p_start_at TIMESTAMPTZ,
    p_end_at TIMESTAMPTZ,
    p_exclude_appointment_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT scheduling.has_covering_worker_schedule(
               p_business_id,
               p_worker_id,
               p_branch_id,
               p_start_at,
               p_end_at
           )
       AND (
               p_branch_id IS NULL
               OR scheduling.has_covering_branch_opening_hour(
                   p_business_id,
                   p_branch_id,
                   p_start_at,
                   p_end_at
               )
           )
       AND NOT scheduling.has_blocking_branch_override(
               p_business_id,
               p_branch_id,
               p_start_at,
               p_end_at
           )
       AND NOT scheduling.has_blocking_worker_override(
               p_business_id,
               p_worker_id,
               p_start_at,
               p_end_at
           )
       AND NOT scheduling.has_appointment_conflict(
               p_business_id,
               p_worker_id,
               p_start_at,
               p_end_at,
               p_exclude_appointment_id
           );
$$;
