-- 006-seed-ai-model-catalog.sql
-- Klyro AI model catalog (informative USD pricing for the model selector +
-- cost estimation). Source of truth for the supported models.
--
-- IMPORTANT: this seed depends on the `ai_model_catalog` table + `ai_provider_enum`
-- created by migration `2026-06-05-ai-provider-model-and-catalog.sql`, so in the
-- docker-entrypoint-initdb.d order it is mounted AFTER the migrations.
-- Idempotent (ON CONFLICT DO NOTHING) — safe to run multiple times.

\connect klyro

BEGIN;

INSERT INTO ai_model_catalog (provider, model, display_name, input_cost_per_1k_usd, output_cost_per_1k_usd, is_enabled)
VALUES
    ('openai', 'gpt-5',             'GPT-5',            0.001250, 0.010000, true),
    ('openai', 'gpt-5-mini',        'GPT-5 mini',       0.000250, 0.002000, true),
    ('google', 'gemini-2.5-flash',  'Gemini 2.5 Flash', 0.000300, 0.002500, true)
ON CONFLICT (provider, model) DO NOTHING;

COMMIT;
