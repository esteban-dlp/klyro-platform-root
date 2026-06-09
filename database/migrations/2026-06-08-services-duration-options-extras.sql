-- 2026-06-08 services duration, options, and extras
-- Hard cutover from services.duration_minutes to duration_type/min/max.

ALTER TABLE services
    ADD COLUMN IF NOT EXISTS duration_type service_duration_type_enum NOT NULL DEFAULT 'fixed',
    ADD COLUMN IF NOT EXISTS duration_min INTEGER,
    ADD COLUMN IF NOT EXISTS duration_max INTEGER;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'services'
          AND column_name = 'duration_minutes'
    ) THEN
        UPDATE services
           SET duration_min = COALESCE(duration_min, duration_minutes),
               duration_max = COALESCE(duration_max, duration_minutes)
         WHERE duration_min IS NULL OR duration_max IS NULL;
    ELSE
        UPDATE services
           SET duration_min = COALESCE(duration_min, 0),
               duration_max = COALESCE(duration_max, GREATEST(COALESCE(duration_min, 0), 1))
         WHERE duration_min IS NULL OR duration_max IS NULL;
    END IF;
END
$$;

ALTER TABLE services
    ALTER COLUMN duration_type SET NOT NULL,
    ALTER COLUMN duration_min SET NOT NULL,
    ALTER COLUMN duration_max SET NOT NULL;

ALTER TABLE services DROP CONSTRAINT IF EXISTS chk_services_duration_minutes;
ALTER TABLE services DROP CONSTRAINT IF EXISTS chk_services_duration_min;
ALTER TABLE services DROP CONSTRAINT IF EXISTS chk_services_duration_max;
ALTER TABLE services DROP CONSTRAINT IF EXISTS chk_services_duration_order;
ALTER TABLE services DROP CONSTRAINT IF EXISTS chk_services_duration_fixed;
ALTER TABLE services DROP COLUMN IF EXISTS duration_minutes;

ALTER TABLE services
    ADD CONSTRAINT chk_services_duration_min CHECK (duration_min >= 0 AND duration_min <= 1440),
    ADD CONSTRAINT chk_services_duration_max CHECK (duration_max >= 1 AND duration_max <= 1440),
    ADD CONSTRAINT chk_services_duration_order CHECK (duration_min <= duration_max),
    ADD CONSTRAINT chk_services_duration_fixed CHECK (duration_type <> 'fixed' OR duration_min = duration_max);

CREATE TABLE IF NOT EXISTS services_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    service_id UUID NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    duration_type service_duration_type_enum NOT NULL DEFAULT 'fixed',
    duration_min INTEGER NOT NULL,
    duration_max INTEGER NOT NULL,
    price_delta NUMERIC(10, 2),
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_services_options_id_business UNIQUE (id, business_id),
    CONSTRAINT uq_services_options_id_service UNIQUE (id, service_id),
    CONSTRAINT fk_services_options_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_services_options_service_business FOREIGN KEY (service_id, business_id) REFERENCES services (id, business_id),
    CONSTRAINT chk_services_options_name_length CHECK (length(trim(name)) >= 1),
    CONSTRAINT chk_services_options_duration_min CHECK (duration_min >= 0 AND duration_min <= 1440),
    CONSTRAINT chk_services_options_duration_max CHECK (duration_max >= 0 AND duration_max <= 1440),
    CONSTRAINT chk_services_options_duration_order CHECK (duration_min <= duration_max),
    CONSTRAINT chk_services_options_duration_fixed CHECK (duration_type <> 'fixed' OR duration_min = duration_max),
    CONSTRAINT chk_services_options_price_delta CHECK (price_delta IS NULL OR price_delta >= 0)
);

CREATE INDEX IF NOT EXISTS services_options_service_idx ON services_options (service_id)
WHERE deleted_at IS NULL;

DROP TRIGGER IF EXISTS trg_services_options_set_updated_at ON services_options;
CREATE TRIGGER trg_services_options_set_updated_at
BEFORE UPDATE ON services_options
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS services_extras (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    service_id UUID NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    duration_type service_duration_type_enum NOT NULL DEFAULT 'fixed',
    duration_min INTEGER NOT NULL,
    duration_max INTEGER NOT NULL,
    price_delta NUMERIC(10, 2),
    is_required BOOLEAN NOT NULL DEFAULT false,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_services_extras_id_business UNIQUE (id, business_id),
    CONSTRAINT uq_services_extras_id_service UNIQUE (id, service_id),
    CONSTRAINT fk_services_extras_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_services_extras_service_business FOREIGN KEY (service_id, business_id) REFERENCES services (id, business_id),
    CONSTRAINT chk_services_extras_name_length CHECK (length(trim(name)) >= 1),
    CONSTRAINT chk_services_extras_duration_min CHECK (duration_min >= 0 AND duration_min <= 1440),
    CONSTRAINT chk_services_extras_duration_max CHECK (duration_max >= 0 AND duration_max <= 1440),
    CONSTRAINT chk_services_extras_duration_order CHECK (duration_min <= duration_max),
    CONSTRAINT chk_services_extras_duration_fixed CHECK (duration_type <> 'fixed' OR duration_min = duration_max),
    CONSTRAINT chk_services_extras_price_delta CHECK (price_delta IS NULL OR price_delta >= 0)
);

CREATE INDEX IF NOT EXISTS services_extras_service_idx ON services_extras (service_id)
WHERE deleted_at IS NULL;

DROP TRIGGER IF EXISTS trg_services_extras_set_updated_at ON services_extras;
CREATE TRIGGER trg_services_extras_set_updated_at
BEFORE UPDATE ON services_extras
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
