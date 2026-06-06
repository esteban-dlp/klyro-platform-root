-- 2026-06-05 — English-only templates + AI translation cache
-- English becomes the single source of truth for global templates; translations
-- to other languages are produced on demand by the AI and cached here.
-- Idempotent; safe to re-run.

CREATE TABLE IF NOT EXISTS message_template_translations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    template_id UUID NOT NULL,
    language_code VARCHAR(10) NOT NULL,
    -- sha256 of the English source body; invalidates the cache when the source changes.
    content_hash VARCHAR(64) NOT NULL,
    translated_body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_mtt_template FOREIGN KEY (template_id) REFERENCES message_templates (id) ON DELETE CASCADE,
    CONSTRAINT uq_mtt_template_lang_hash UNIQUE (template_id, language_code, content_hash)
);

-- Drop the seeded Spanish global templates; English is now the source of truth.
DELETE FROM message_templates
WHERE business_id IS NULL
  AND provider = 'internal'
  AND language_code = 'es';
