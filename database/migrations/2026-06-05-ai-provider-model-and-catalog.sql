-- 2026-06-05 — Configurable AI provider/model + cost catalog
-- Adds `ai_provider_enum`, per-business `provider`/`model` columns, and the
-- `ai_model_catalog` table (informative USD pricing for the model selector +
-- cost estimation). Idempotent; safe to re-run.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ai_provider_enum') THEN
        CREATE TYPE ai_provider_enum AS ENUM ('openai', 'google');
    END IF;
END
$$;

ALTER TABLE business_ai_settings
    ADD COLUMN IF NOT EXISTS provider ai_provider_enum NOT NULL DEFAULT 'openai',
    ADD COLUMN IF NOT EXISTS model VARCHAR(80) NOT NULL DEFAULT 'gpt-5-mini';

-- Informative pricing per model (providers do not expose pricing via API).
-- USD is the base currency; the business currency is derived via FX at read time.
CREATE TABLE IF NOT EXISTS ai_model_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    provider ai_provider_enum NOT NULL,
    model VARCHAR(80) NOT NULL,
    display_name VARCHAR(120) NOT NULL,
    input_cost_per_1k_usd NUMERIC(12, 6) NOT NULL DEFAULT 0,
    output_cost_per_1k_usd NUMERIC(12, 6) NOT NULL DEFAULT 0,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ai_model_catalog_provider_model UNIQUE (provider, model)
);

-- NOTE: the catalog ROWS are seeded by `seeds/006-seed-ai-model-catalog.sql`,
-- which is mounted to run AFTER this migration (idempotent). This migration only
-- creates the schema.
