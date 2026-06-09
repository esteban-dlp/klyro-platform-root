-- 2026-06-08 open-period scheduling functions.
-- Replaces blocking override helpers with branch/worker open-period semantics.

CREATE SCHEMA IF NOT EXISTS scheduling;

DROP FUNCTION IF EXISTS scheduling.has_blocking_branch_override(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS scheduling.has_blocking_worker_override(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ);
DROP TABLE IF EXISTS availability_override_types;

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

CREATE OR REPLACE FUNCTION scheduling.date_in_recurring_window(
    p_date DATE,
    p_start_month SMALLINT,
    p_start_day SMALLINT,
    p_end_month SMALLINT,
    p_end_day SMALLINT
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
    WITH bounds AS (
        SELECT
            ((EXTRACT(MONTH FROM p_date)::INT * 100) + EXTRACT(DAY FROM p_date)::INT) AS date_key,
            ((p_start_month::INT * 100) + p_start_day::INT) AS start_key,
            ((p_end_month::INT * 100) + p_end_day::INT) AS end_key
    )
    SELECT CASE
        WHEN p_date IS NULL
          OR p_start_month IS NULL
          OR p_start_day IS NULL
          OR p_end_month IS NULL
          OR p_end_day IS NULL
            THEN false
        WHEN start_key <= end_key
            THEN date_key BETWEEN start_key AND end_key
        ELSE date_key >= start_key OR date_key <= end_key
    END
    FROM bounds;
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

CREATE OR REPLACE FUNCTION scheduling.is_branch_open(
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
    ),
    normalized AS (
        SELECT
            start_local::date AS local_date,
            start_local::time AS local_start_time,
            end_local::time AS local_end_time,
            start_local::date = end_local::date AS same_local_date,
            EXTRACT(MONTH FROM start_local)::SMALLINT AS local_month,
            EXTRACT(DAY FROM start_local)::SMALLINT AS local_day
        FROM local_range
    )
    SELECT CASE
        WHEN p_branch_id IS NULL THEN false
        WHEN NOT (SELECT same_local_date FROM normalized) THEN false
        WHEN EXISTS (
            SELECT 1
            FROM public.branch_availability_overrides override_row
            INNER JOIN public.branch_availability_override_branches target
                ON target.override_id = override_row.id
               AND target.business_id = override_row.business_id
               AND target.branch_id = p_branch_id
            CROSS JOIN normalized n
            WHERE override_row.business_id = p_business_id
              AND override_row.deleted_at IS NULL
              AND override_row.start_date <= n.local_date
              AND override_row.end_date >= n.local_date
        )
            THEN EXISTS (
                SELECT 1
                FROM public.branch_availability_overrides override_row
                INNER JOIN public.branch_availability_override_branches target
                    ON target.override_id = override_row.id
                   AND target.business_id = override_row.business_id
                   AND target.branch_id = p_branch_id
                INNER JOIN public.branch_availability_override_periods period
                    ON period.override_id = override_row.id
                   AND period.business_id = override_row.business_id
                CROSS JOIN normalized n
                WHERE override_row.business_id = p_business_id
                  AND override_row.deleted_at IS NULL
                  AND override_row.start_date <= n.local_date
                  AND override_row.end_date >= n.local_date
                  AND period.on_date = n.local_date
                  AND period.start_time <= n.local_start_time
                  AND n.local_end_time <= period.end_time
            )
        WHEN EXISTS (
            SELECT 1
            FROM public.branch_holidays holiday
            CROSS JOIN normalized n
            WHERE holiday.business_id = p_business_id
              AND holiday.branch_id = p_branch_id
              AND holiday.is_active = true
              AND holiday.deleted_at IS NULL
              AND scheduling.date_in_recurring_window(
                  n.local_date,
                  holiday.start_month,
                  holiday.start_day,
                  holiday.end_month,
                  holiday.end_day
              )
        )
            THEN EXISTS (
                SELECT 1
                FROM public.branch_holidays holiday
                INNER JOIN public.branch_holiday_open_periods period
                    ON period.holiday_id = holiday.id
                   AND period.business_id = holiday.business_id
                CROSS JOIN normalized n
                WHERE holiday.business_id = p_business_id
                  AND holiday.branch_id = p_branch_id
                  AND holiday.is_active = true
                  AND holiday.deleted_at IS NULL
                  AND scheduling.date_in_recurring_window(
                      n.local_date,
                      holiday.start_month,
                      holiday.start_day,
                      holiday.end_month,
                      holiday.end_day
                  )
                  AND period.month = n.local_month
                  AND period.day = n.local_day
                  AND period.start_time <= n.local_start_time
                  AND n.local_end_time <= period.end_time
            )
        ELSE scheduling.has_covering_branch_opening_hour(
            p_business_id,
            p_branch_id,
            p_start_at,
            p_end_at
        )
    END;
$$;

CREATE OR REPLACE FUNCTION scheduling.is_worker_open(
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
    ),
    normalized AS (
        SELECT
            start_local::date AS local_date,
            start_local::time AS local_start_time,
            end_local::time AS local_end_time,
            start_local::date = end_local::date AS same_local_date,
            EXTRACT(ISODOW FROM start_local)::SMALLINT AS local_day_of_week
        FROM local_range
    )
    SELECT CASE
        WHEN NOT (SELECT same_local_date FROM normalized) THEN false
        WHEN EXISTS (
            SELECT 1
            FROM public.worker_availability_overrides override_row
            INNER JOIN public.worker_availability_override_workers target
                ON target.override_id = override_row.id
               AND target.business_id = override_row.business_id
               AND target.worker_id = p_worker_id
            CROSS JOIN normalized n
            WHERE override_row.business_id = p_business_id
              AND override_row.deleted_at IS NULL
              AND override_row.start_date <= n.local_date
              AND override_row.end_date >= n.local_date
        )
            THEN EXISTS (
                SELECT 1
                FROM public.worker_availability_overrides override_row
                INNER JOIN public.worker_availability_override_workers target
                    ON target.override_id = override_row.id
                   AND target.business_id = override_row.business_id
                   AND target.worker_id = p_worker_id
                INNER JOIN public.worker_availability_override_periods period
                    ON period.override_id = override_row.id
                   AND period.business_id = override_row.business_id
                CROSS JOIN normalized n
                WHERE override_row.business_id = p_business_id
                  AND override_row.deleted_at IS NULL
                  AND override_row.start_date <= n.local_date
                  AND override_row.end_date >= n.local_date
                  AND period.on_date = n.local_date
                  AND period.start_time <= n.local_start_time
                  AND n.local_end_time <= period.end_time
            )
        ELSE scheduling.has_covering_worker_schedule(
            p_business_id,
            p_worker_id,
            p_branch_id,
            p_start_at,
            p_end_at
        )
        AND NOT EXISTS (
            SELECT 1
            FROM public.worker_schedule_breaks break_row
            CROSS JOIN normalized n
            WHERE break_row.business_id = p_business_id
              AND break_row.worker_id = p_worker_id
              AND (
                  (p_branch_id IS NULL AND break_row.branch_id IS NULL)
                  OR (p_branch_id IS NOT NULL AND (break_row.branch_id = p_branch_id OR break_row.branch_id IS NULL))
              )
              AND break_row.day_of_week = n.local_day_of_week
              AND break_row.is_active = true
              AND break_row.deleted_at IS NULL
              AND break_row.start_time < n.local_end_time
              AND (break_row.start_time + (break_row.duration_minutes || ' minutes')::INTERVAL)::time > n.local_start_time
        )
    END;
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
    SELECT scheduling.is_worker_open(
               p_business_id,
               p_worker_id,
               p_branch_id,
               p_start_at,
               p_end_at
           )
       AND (
               p_branch_id IS NULL
               OR scheduling.is_branch_open(
                   p_business_id,
                   p_branch_id,
                   p_start_at,
                   p_end_at
               )
           )
       AND NOT scheduling.has_appointment_conflict(
               p_business_id,
               p_worker_id,
               p_start_at,
               p_end_at,
               p_exclude_appointment_id
           );
$$;
