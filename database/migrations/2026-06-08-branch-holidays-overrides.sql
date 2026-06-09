-- 2026-06-08 branch holidays and open-period overrides.
-- Hard cutover from blocking branch override intervals to exact-date open periods.

CREATE TABLE IF NOT EXISTS branch_override_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_branch_override_types_code_format CHECK (code ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_branch_override_types_name_length CHECK (length(trim(name)) >= 2)
);

INSERT INTO branch_override_types (code, name, is_active)
VALUES
    ('special_hours', 'Special Hours', true),
    ('closed_for_maintenance', 'Closed for Maintenance', true),
    ('closed_for_remodeling', 'Closed for Remodeling', true),
    ('private_event', 'Private Event', true),
    ('inventory_day', 'Inventory Day', true),
    ('weather_closure', 'Weather Closure', true),
    ('extended_holiday_hours', 'Extended Holiday Hours', true),
    ('temporary_closure', 'Temporary Closure', true),
    ('other', 'Other', true)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    is_active = EXCLUDED.is_active;

CREATE TABLE IF NOT EXISTS branch_holidays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    source_template_id UUID,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    start_month SMALLINT NOT NULL,
    start_day SMALLINT NOT NULL,
    end_month SMALLINT NOT NULL,
    end_day SMALLINT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_branch_holidays_id_business UNIQUE (id, business_id),
    CONSTRAINT fk_branch_holidays_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_branch_holidays_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_branch_holidays_template FOREIGN KEY (source_template_id) REFERENCES holiday_templates (id),
    CONSTRAINT chk_branch_holidays_start_month CHECK (start_month BETWEEN 1 AND 12),
    CONSTRAINT chk_branch_holidays_end_month CHECK (end_month BETWEEN 1 AND 12),
    CONSTRAINT chk_branch_holidays_start_day CHECK (start_day BETWEEN 1 AND 31),
    CONSTRAINT chk_branch_holidays_end_day CHECK (end_day BETWEEN 1 AND 31),
    CONSTRAINT chk_branch_holidays_name_length CHECK (length(trim(name)) >= 2)
);

CREATE INDEX IF NOT EXISTS branch_holidays_branch_idx ON branch_holidays (branch_id)
WHERE deleted_at IS NULL;

DROP TRIGGER IF EXISTS trg_branch_holidays_set_updated_at ON branch_holidays;
CREATE TRIGGER trg_branch_holidays_set_updated_at
BEFORE UPDATE ON branch_holidays
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS branch_holiday_open_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    holiday_id UUID NOT NULL,
    business_id UUID NOT NULL,
    month SMALLINT NOT NULL,
    day SMALLINT NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_branch_holiday_open_periods_holiday_business
        FOREIGN KEY (holiday_id, business_id) REFERENCES branch_holidays (id, business_id) ON DELETE CASCADE,
    CONSTRAINT chk_branch_holiday_open_periods_month CHECK (month BETWEEN 1 AND 12),
    CONSTRAINT chk_branch_holiday_open_periods_day CHECK (day BETWEEN 1 AND 31),
    CONSTRAINT chk_branch_holiday_open_periods_time CHECK (start_time < end_time)
);

CREATE INDEX IF NOT EXISTS branch_holiday_open_periods_holiday_idx ON branch_holiday_open_periods (holiday_id);

ALTER TABLE branch_availability_overrides
    ADD COLUMN IF NOT EXISTS branch_override_type_id UUID,
    ADD COLUMN IF NOT EXISTS start_date DATE,
    ADD COLUMN IF NOT EXISTS end_date DATE;

DO $$
DECLARE
    v_other_type_id UUID;
BEGIN
    SELECT id INTO v_other_type_id
    FROM branch_override_types
    WHERE code = 'other'
    LIMIT 1;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'branch_availability_overrides'
          AND column_name = 'start_at'
    ) THEN
        UPDATE branch_availability_overrides
           SET start_date = COALESCE(start_date, (start_at AT TIME ZONE 'UTC')::date),
               end_date = COALESCE(end_date, (end_at AT TIME ZONE 'UTC')::date),
               branch_override_type_id = COALESCE(branch_override_type_id, v_other_type_id)
         WHERE start_date IS NULL
            OR end_date IS NULL
            OR branch_override_type_id IS NULL;
    ELSE
        UPDATE branch_availability_overrides
           SET start_date = COALESCE(start_date, CURRENT_DATE),
               end_date = COALESCE(end_date, COALESCE(start_date, CURRENT_DATE)),
               branch_override_type_id = COALESCE(branch_override_type_id, v_other_type_id)
         WHERE start_date IS NULL
            OR end_date IS NULL
            OR branch_override_type_id IS NULL;
    END IF;
END
$$;

ALTER TABLE branch_availability_overrides
    ALTER COLUMN start_date SET NOT NULL,
    ALTER COLUMN end_date SET NOT NULL,
    ALTER COLUMN branch_override_type_id SET NOT NULL;

ALTER TABLE branch_availability_overrides DROP CONSTRAINT IF EXISTS fk_branch_availability_overrides_type;
ALTER TABLE branch_availability_overrides DROP CONSTRAINT IF EXISTS fk_branch_availability_overrides_branch_type;
ALTER TABLE branch_availability_overrides DROP CONSTRAINT IF EXISTS chk_branch_availability_overrides_time_range;
ALTER TABLE branch_availability_overrides DROP CONSTRAINT IF EXISTS chk_branch_availability_overrides_date_range;

ALTER TABLE branch_availability_overrides
    DROP COLUMN IF EXISTS override_type_id,
    DROP COLUMN IF EXISTS start_at,
    DROP COLUMN IF EXISTS end_at;

ALTER TABLE branch_availability_overrides
    ADD CONSTRAINT fk_branch_availability_overrides_branch_type
        FOREIGN KEY (branch_override_type_id) REFERENCES branch_override_types (id),
    ADD CONSTRAINT chk_branch_availability_overrides_date_range CHECK (start_date <= end_date);

DROP INDEX IF EXISTS branch_availability_overrides_business_time_idx;
CREATE INDEX IF NOT EXISTS branch_availability_overrides_business_date_idx
ON branch_availability_overrides (business_id, start_date, end_date)
WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS branch_availability_override_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    override_id UUID NOT NULL,
    business_id UUID NOT NULL,
    on_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_branch_override_periods_override_business
        FOREIGN KEY (override_id, business_id) REFERENCES branch_availability_overrides (id, business_id) ON DELETE CASCADE,
    CONSTRAINT chk_branch_override_periods_time CHECK (start_time < end_time)
);

CREATE INDEX IF NOT EXISTS branch_override_periods_override_idx ON branch_availability_override_periods (override_id);
