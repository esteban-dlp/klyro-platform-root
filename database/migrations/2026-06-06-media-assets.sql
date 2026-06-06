-- 2026-06-06 media-assets
-- Adds optional image support backed by Cloudflare R2.
--
-- New `media_assets` table holds one stored (optimized webp) image per row. Owning
-- entities reference an optional asset via nullable *_asset_id FKs:
--   businesses.logo_asset_id      -> business logo
--   businesses.catalog_asset_id   -> default/general business catalog
--   services.image_asset_id       -> service main image
--   branches.catalog_asset_id     -> optional per-branch catalog (overrides business catalog)
--
-- `businesses.logo_url` is kept for backward-compat; the API derives the logo URL from
-- the asset first, then falls back to logo_url.
--
-- Idempotent: safe to re-run and to apply to an existing database without dropping volumes.

-- 1. Enum for the asset kind (drives the R2 key prefix).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'media_asset_kind_enum') THEN
        CREATE TYPE media_asset_kind_enum AS ENUM (
            'business_logo',
            'service_image',
            'business_catalog',
            'branch_catalog'
        );
    END IF;
END$$;

-- 2. media_assets table.
CREATE TABLE IF NOT EXISTS media_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    kind media_asset_kind_enum NOT NULL,
    r2_key TEXT NOT NULL,
    public_url TEXT NOT NULL,
    mime_type VARCHAR(120) NOT NULL DEFAULT 'image/webp',
    size_bytes INTEGER,
    width INTEGER,
    height INTEGER,
    created_by_user_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_media_assets_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_media_assets_created_by FOREIGN KEY (created_by_user_id) REFERENCES users (id),
    CONSTRAINT chk_media_assets_public_url_format CHECK (public_url ~* '^https?://')
);

CREATE UNIQUE INDEX IF NOT EXISTS media_assets_r2_key_unique_idx ON media_assets (r2_key);
CREATE INDEX IF NOT EXISTS media_assets_business_idx ON media_assets (business_id);

-- 3. Nullable asset FK columns on owning entities.
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS logo_asset_id UUID;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS catalog_asset_id UUID;
ALTER TABLE services ADD COLUMN IF NOT EXISTS image_asset_id UUID;
ALTER TABLE branches ADD COLUMN IF NOT EXISTS catalog_asset_id UUID;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_businesses_logo_asset') THEN
        ALTER TABLE businesses
            ADD CONSTRAINT fk_businesses_logo_asset
            FOREIGN KEY (logo_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_businesses_catalog_asset') THEN
        ALTER TABLE businesses
            ADD CONSTRAINT fk_businesses_catalog_asset
            FOREIGN KEY (catalog_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_services_image_asset') THEN
        ALTER TABLE services
            ADD CONSTRAINT fk_services_image_asset
            FOREIGN KEY (image_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_branches_catalog_asset') THEN
        ALTER TABLE branches
            ADD CONSTRAINT fk_branches_catalog_asset
            FOREIGN KEY (catalog_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL;
    END IF;
END$$;
