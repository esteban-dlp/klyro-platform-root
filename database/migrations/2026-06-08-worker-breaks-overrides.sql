-- 2026-06-08 worker breaks and open-period overrides.
-- Hard cutover from blocking worker override intervals to exact-date open periods.

CREATE TABLE IF NOT EXISTS worker_override_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_worker_override_types_code_format CHECK (code ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_worker_override_types_name_length CHECK (length(trim(name)) >= 2)
);

INSERT INTO worker_override_types (code, name, is_active)
VALUES
    ('day_off', 'Day Off', true),
    ('sick_day', 'Sick Day', true),
    ('vacation', 'Vacation', true),
    ('early_leave', 'Early Leave', true),
    ('late_start', 'Late Start', true),
    ('custom_hours', 'Custom Hours', true),
    ('training', 'Training', true),
    ('emergency', 'Emergency', true),
    ('other', 'Other', true)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    is_active = EXCLUDED.is_active;

CREATE TABLE IF NOT EXISTS break_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_break_types_code_format CHECK (code ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_break_types_name_length CHECK (length(trim(name)) >= 2)
);

INSERT INTO break_types (code, name, is_active)
VALUES
    ('lunch', 'Lunch', true),
    ('short_break', 'Short Break', true),
    ('personal_break', 'Personal Break', true),
    ('admin_break', 'Admin Break', true),
    ('training_break', 'Training Break', true),
    ('other', 'Other', true)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    is_active = EXCLUDED.is_active;

CREATE TABLE IF NOT EXISTS worker_schedule_breaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    worker_id UUID NOT NULL,
    branch_id UUID,
    break_type_id UUID NOT NULL,
    day_of_week SMALLINT NOT NULL,
    start_time TIME NOT NULL,
    duration_minutes INTEGER NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_worker_schedule_breaks_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_worker_schedule_breaks_worker_business FOREIGN KEY (worker_id, business_id) REFERENCES workers (id, business_id),
    CONSTRAINT fk_worker_schedule_breaks_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_worker_schedule_breaks_type FOREIGN KEY (break_type_id) REFERENCES break_types (id),
    CONSTRAINT chk_worker_schedule_breaks_day CHECK (day_of_week BETWEEN 1 AND 7),
    CONSTRAINT chk_worker_schedule_breaks_duration CHECK (duration_minutes > 0 AND duration_minutes <= 1440)
);

CREATE INDEX IF NOT EXISTS worker_schedule_breaks_worker_day_idx ON worker_schedule_breaks (worker_id, day_of_week)
WHERE deleted_at IS NULL;

DROP TRIGGER IF EXISTS trg_worker_schedule_breaks_set_updated_at ON worker_schedule_breaks;
CREATE TRIGGER trg_worker_schedule_breaks_set_updated_at
BEFORE UPDATE ON worker_schedule_breaks
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

ALTER TABLE worker_availability_overrides
    ADD COLUMN IF NOT EXISTS worker_override_type_id UUID,
    ADD COLUMN IF NOT EXISTS start_date DATE,
    ADD COLUMN IF NOT EXISTS end_date DATE;

DO $$
DECLARE
    v_other_type_id UUID;
BEGIN
    SELECT id INTO v_other_type_id
    FROM worker_override_types
    WHERE code = 'other'
    LIMIT 1;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'worker_availability_overrides'
          AND column_name = 'start_at'
    ) THEN
        UPDATE worker_availability_overrides
           SET start_date = COALESCE(start_date, (start_at AT TIME ZONE 'UTC')::date),
               end_date = COALESCE(end_date, (end_at AT TIME ZONE 'UTC')::date),
               worker_override_type_id = COALESCE(worker_override_type_id, v_other_type_id)
         WHERE start_date IS NULL
            OR end_date IS NULL
            OR worker_override_type_id IS NULL;
    ELSE
        UPDATE worker_availability_overrides
           SET start_date = COALESCE(start_date, CURRENT_DATE),
               end_date = COALESCE(end_date, COALESCE(start_date, CURRENT_DATE)),
               worker_override_type_id = COALESCE(worker_override_type_id, v_other_type_id)
         WHERE start_date IS NULL
            OR end_date IS NULL
            OR worker_override_type_id IS NULL;
    END IF;
END
$$;

ALTER TABLE worker_availability_overrides
    ALTER COLUMN start_date SET NOT NULL,
    ALTER COLUMN end_date SET NOT NULL,
    ALTER COLUMN worker_override_type_id SET NOT NULL;

ALTER TABLE worker_availability_overrides DROP CONSTRAINT IF EXISTS fk_worker_availability_overrides_type;
ALTER TABLE worker_availability_overrides DROP CONSTRAINT IF EXISTS fk_worker_availability_overrides_worker_type;
ALTER TABLE worker_availability_overrides DROP CONSTRAINT IF EXISTS chk_worker_availability_overrides_time_range;
ALTER TABLE worker_availability_overrides DROP CONSTRAINT IF EXISTS chk_worker_availability_overrides_date_range;

ALTER TABLE worker_availability_overrides
    DROP COLUMN IF EXISTS override_type_id,
    DROP COLUMN IF EXISTS start_at,
    DROP COLUMN IF EXISTS end_at;

ALTER TABLE worker_availability_overrides
    ADD CONSTRAINT fk_worker_availability_overrides_worker_type
        FOREIGN KEY (worker_override_type_id) REFERENCES worker_override_types (id),
    ADD CONSTRAINT chk_worker_availability_overrides_date_range CHECK (start_date <= end_date);

DROP INDEX IF EXISTS worker_availability_overrides_business_time_idx;
CREATE INDEX IF NOT EXISTS worker_availability_overrides_business_date_idx
ON worker_availability_overrides (business_id, start_date, end_date)
WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS worker_availability_override_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    override_id UUID NOT NULL,
    business_id UUID NOT NULL,
    on_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_worker_override_periods_override_business
        FOREIGN KEY (override_id, business_id) REFERENCES worker_availability_overrides (id, business_id) ON DELETE CASCADE,
    CONSTRAINT chk_worker_override_periods_time CHECK (start_time < end_time)
);

CREATE INDEX IF NOT EXISTS worker_override_periods_override_idx ON worker_availability_override_periods (override_id);
