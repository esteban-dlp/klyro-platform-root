-- 2026-06-08 appointment option/extras selection and early completion.

ALTER TABLE appointments
    ADD COLUMN IF NOT EXISTS service_option_id UUID,
    ADD COLUMN IF NOT EXISTS actual_end_at TIMESTAMPTZ;

ALTER TABLE appointments DROP CONSTRAINT IF EXISTS fk_appointments_service_option_business;
ALTER TABLE appointments DROP CONSTRAINT IF EXISTS chk_appointments_actual_end_at;

ALTER TABLE appointments
    ADD CONSTRAINT fk_appointments_service_option_business
        FOREIGN KEY (service_option_id, business_id) REFERENCES services_options (id, business_id),
    ADD CONSTRAINT chk_appointments_actual_end_at
        CHECK (actual_end_at IS NULL OR (actual_end_at > start_at AND actual_end_at <= end_at));

CREATE TABLE IF NOT EXISTS appointment_extras (
    appointment_id UUID NOT NULL,
    extra_id UUID NOT NULL,
    business_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (appointment_id, extra_id),
    CONSTRAINT fk_appointment_extras_appointment_business
        FOREIGN KEY (appointment_id, business_id) REFERENCES appointments (id, business_id),
    CONSTRAINT fk_appointment_extras_extra_business
        FOREIGN KEY (extra_id, business_id) REFERENCES services_extras (id, business_id)
);
