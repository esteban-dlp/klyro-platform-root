-- 2026-06-08 holiday templates and country links.

CREATE TABLE IF NOT EXISTS holiday_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    recurrence_type VARCHAR(20) NOT NULL DEFAULT 'fixed_date',
    start_month SMALLINT,
    start_day SMALLINT,
    end_month SMALLINT,
    end_day SMALLINT,
    weekday SMALLINT,
    week_of_month SMALLINT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_holiday_templates_code_format CHECK (code ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_holiday_templates_recurrence CHECK (recurrence_type IN ('fixed_date', 'nth_weekday')),
    CONSTRAINT chk_holiday_templates_month CHECK (start_month IS NULL OR start_month BETWEEN 1 AND 12),
    CONSTRAINT chk_holiday_templates_day CHECK (start_day IS NULL OR start_day BETWEEN 1 AND 31),
    CONSTRAINT chk_holiday_templates_end_month CHECK (end_month IS NULL OR end_month BETWEEN 1 AND 12),
    CONSTRAINT chk_holiday_templates_end_day CHECK (end_day IS NULL OR end_day BETWEEN 1 AND 31),
    CONSTRAINT chk_holiday_templates_weekday CHECK (weekday IS NULL OR weekday BETWEEN 1 AND 7)
);

DROP TRIGGER IF EXISTS trg_holiday_templates_set_updated_at ON holiday_templates;
CREATE TRIGGER trg_holiday_templates_set_updated_at
BEFORE UPDATE ON holiday_templates
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS holiday_template_countries (
    template_id UUID NOT NULL,
    country_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (template_id, country_id),
    CONSTRAINT fk_holiday_template_countries_template FOREIGN KEY (template_id) REFERENCES holiday_templates (id),
    CONSTRAINT fk_holiday_template_countries_country FOREIGN KEY (country_id) REFERENCES countries (id)
);

INSERT INTO holiday_templates (
    code,
    name,
    description,
    recurrence_type,
    start_month,
    start_day,
    end_month,
    end_day,
    is_active
)
VALUES
    ('new_year', 'New Year''s Day', 'Recurring January 1 holiday template.', 'fixed_date', 1, 1, 1, 1, true),
    ('christmas', 'Christmas', 'Recurring December 25 holiday template.', 'fixed_date', 12, 25, 12, 25, true),
    ('labor_day', 'Labor Day', 'Recurring May 1 labor day holiday template.', 'fixed_date', 5, 1, 5, 1, true)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    recurrence_type = EXCLUDED.recurrence_type,
    start_month = EXCLUDED.start_month,
    start_day = EXCLUDED.start_day,
    end_month = EXCLUDED.end_month,
    end_day = EXCLUDED.end_day,
    is_active = EXCLUDED.is_active;

INSERT INTO holiday_template_countries (template_id, country_id)
SELECT template.id, country.id
FROM holiday_templates template
INNER JOIN countries country
    ON country.iso_code IN ('GT', 'MX', 'SV', 'ES', 'US')
WHERE template.code IN ('new_year', 'christmas')
ON CONFLICT (template_id, country_id) DO NOTHING;

INSERT INTO holiday_template_countries (template_id, country_id)
SELECT template.id, country.id
FROM holiday_templates template
INNER JOIN countries country
    ON country.iso_code IN ('GT', 'MX', 'SV', 'ES')
WHERE template.code = 'labor_day'
ON CONFLICT (template_id, country_id) DO NOTHING;
