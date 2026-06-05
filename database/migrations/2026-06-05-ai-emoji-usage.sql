-- 2026-06-05 — AI emoji usage setting
-- Adds the `ai_emoji_usage_enum` type and the `business_ai_settings.emoji_usage`
-- column (default 'normal'). Idempotent; safe to re-run.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'ai_emoji_usage_enum'
    ) THEN
        CREATE TYPE ai_emoji_usage_enum AS ENUM ('never', 'few', 'normal');
    END IF;
END
$$;

ALTER TABLE business_ai_settings
    ADD COLUMN IF NOT EXISTS emoji_usage ai_emoji_usage_enum NOT NULL DEFAULT 'normal';
