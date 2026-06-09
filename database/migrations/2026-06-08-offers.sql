-- 2026-06-08 offers/promotions
-- Pricing-only offers, per-service fixed prices, and appointment price snapshots.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'offer_discount_type_enum') THEN
        CREATE TYPE offer_discount_type_enum AS ENUM ('percentage', 'fixed_amount', 'fixed_price');
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    discount_type offer_discount_type_enum NOT NULL,
    discount_value NUMERIC(10, 2),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_offers_id_business UNIQUE (id, business_id),
    CONSTRAINT fk_offers_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT chk_offers_name_length CHECK (length(trim(name)) >= 2),
    CONSTRAINT chk_offers_date_range CHECK (start_date <= end_date),
    CONSTRAINT chk_offers_value_required CHECK (discount_type = 'fixed_price' OR discount_value IS NOT NULL),
    CONSTRAINT chk_offers_percentage CHECK (discount_type <> 'percentage' OR (discount_value > 0 AND discount_value <= 100)),
    CONSTRAINT chk_offers_fixed_amount CHECK (discount_type <> 'fixed_amount' OR discount_value > 0),
    CONSTRAINT chk_offers_fixed_price_null CHECK (discount_type <> 'fixed_price' OR discount_value IS NULL)
);

CREATE INDEX IF NOT EXISTS offers_business_active_idx ON offers (business_id)
WHERE deleted_at IS NULL AND is_active = true;

DROP TRIGGER IF EXISTS trg_offers_set_updated_at ON offers;
CREATE TRIGGER trg_offers_set_updated_at
BEFORE UPDATE ON offers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS offer_services (
    offer_id UUID NOT NULL,
    service_id UUID NOT NULL,
    business_id UUID NOT NULL,
    fixed_price NUMERIC(10, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (offer_id, service_id),
    CONSTRAINT fk_offer_services_offer_business FOREIGN KEY (offer_id, business_id) REFERENCES offers (id, business_id) ON DELETE CASCADE,
    CONSTRAINT fk_offer_services_service_business FOREIGN KEY (service_id, business_id) REFERENCES services (id, business_id),
    CONSTRAINT chk_offer_services_fixed_price CHECK (fixed_price IS NULL OR fixed_price >= 0)
);

CREATE INDEX IF NOT EXISTS offer_services_service_idx ON offer_services (service_id);

ALTER TABLE appointments
    ADD COLUMN IF NOT EXISTS applied_offer_id UUID,
    ADD COLUMN IF NOT EXISTS original_price NUMERIC(10, 2);

ALTER TABLE appointments DROP CONSTRAINT IF EXISTS fk_appointments_applied_offer_business;
ALTER TABLE appointments DROP CONSTRAINT IF EXISTS chk_appointments_original_price;

ALTER TABLE appointments
    ADD CONSTRAINT fk_appointments_applied_offer_business
        FOREIGN KEY (applied_offer_id, business_id) REFERENCES offers (id, business_id),
    ADD CONSTRAINT chk_appointments_original_price CHECK (original_price IS NULL OR original_price >= 0);
