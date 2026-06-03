-- 002-tables.sql
-- Klyro PostgreSQL tables, constraints, foreign keys, indexes and update triggers.
-- Run after 001-enums.sql.

\connect klyro

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================================
-- Utility function: updated_at auto-refresh
-- =========================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- Type/catalog tables
-- =========================================================

CREATE TABLE IF NOT EXISTS currencies (
    code CHAR(3) PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_currencies_code_upper CHECK (code = upper(code)),
    CONSTRAINT chk_currencies_name_length CHECK (length(trim(name)) >= 2),
    CONSTRAINT chk_currencies_symbol_length CHECK (length(trim(symbol)) >= 1)
);

CREATE TABLE IF NOT EXISTS countries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    iso_code CHAR(2) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    default_currency_code CHAR(3) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT fk_countries_default_currency FOREIGN KEY (default_currency_code) REFERENCES currencies (code),
    CONSTRAINT chk_countries_iso_upper CHECK (iso_code = upper(iso_code)),
    CONSTRAINT chk_countries_name_length CHECK (length(trim(name)) >= 2)
);

CREATE TABLE IF NOT EXISTS phone_prefixes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    country_id UUID NOT NULL,
    dial_code VARCHAR(8) NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT fk_phone_prefixes_country FOREIGN KEY (country_id) REFERENCES countries (id),
    CONSTRAINT chk_phone_prefixes_dial_code CHECK (dial_code ~ '^[+][0-9]{1,6}$'),
    CONSTRAINT uq_phone_prefixes_country_dial_code UNIQUE (country_id, dial_code)
);

CREATE TABLE IF NOT EXISTS languages (
    code VARCHAR(10) PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    native_name VARCHAR(80) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_languages_code_format CHECK (
        code ~ '^[a-z]{2}(-[A-Z]{2})?$'
    ),
    CONSTRAINT chk_languages_name_length CHECK (length(trim(name)) >= 2),
    CONSTRAINT chk_languages_native_name_length CHECK (
        length(trim(native_name)) >= 2
    )
);

CREATE TABLE IF NOT EXISTS business_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_business_types_code_format CHECK (code ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_business_types_name_length CHECK (length(trim(name)) >= 2)
);

CREATE TABLE IF NOT EXISTS payment_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_payment_providers_code_format CHECK (code ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_payment_providers_name_length CHECK (length(trim(name)) >= 2)
);

CREATE TABLE IF NOT EXISTS availability_override_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    blocks_availability BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_availability_override_types_code_format CHECK (code ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_availability_override_types_name_length CHECK (length(trim(name)) >= 2)
);

CREATE TABLE IF NOT EXISTS notification_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    default_enabled BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_notification_types_code_format CHECK (code ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_notification_types_name_length CHECK (length(trim(name)) >= 2)
);

-- =========================================================
-- Core entity tables
-- =========================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    email VARCHAR(255) NOT NULL,
    password_hash TEXT,
    full_name VARCHAR(200) NOT NULL,
    phone_prefix_id UUID,
    phone_number VARCHAR(30),
    phone_e164 VARCHAR(30),
    avatar_url TEXT,
    auth_provider auth_provider_enum NOT NULL DEFAULT 'local',
    auth_provider_id VARCHAR(255),
    email_verified_at TIMESTAMPTZ,
    status user_status_enum NOT NULL DEFAULT 'active',
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_users_phone_prefix FOREIGN KEY (phone_prefix_id) REFERENCES phone_prefixes (id),
    CONSTRAINT chk_users_email_format CHECK (
        email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}$'
    ),
    CONSTRAINT chk_users_password_hash_length CHECK (
        password_hash IS NULL
        OR length(password_hash) >= 20
    ),
    CONSTRAINT chk_users_full_name_length CHECK (length(trim(full_name)) >= 2),
    CONSTRAINT chk_users_phone_number_format CHECK (
        phone_number IS NULL
        OR phone_number ~ '^[0-9]{6,20}$'
    ),
    CONSTRAINT chk_users_phone_e164_format CHECK (
        phone_e164 IS NULL
        OR phone_e164 ~ '^[+][0-9]{7,20}$'
    ),
    CONSTRAINT chk_users_avatar_url_format CHECK (
        avatar_url IS NULL
        OR avatar_url ~* '^https?://'
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique_idx ON users (lower(email))
WHERE
    deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS businesses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(120) NOT NULL,
    description TEXT,
    business_type_id UUID,
    country_id UUID NOT NULL,
    currency_code CHAR(3) NOT NULL,
    default_language_code VARCHAR(10) NOT NULL,
    timezone VARCHAR(80) NOT NULL,
    logo_url TEXT,
    default_phone_number_id UUID,
    status business_status_enum NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_businesses_business_type FOREIGN KEY (business_type_id) REFERENCES business_types (id),
    CONSTRAINT fk_businesses_country FOREIGN KEY (country_id) REFERENCES countries (id),
    CONSTRAINT fk_businesses_currency FOREIGN KEY (currency_code) REFERENCES currencies (code),
    CONSTRAINT fk_businesses_language FOREIGN KEY (default_language_code) REFERENCES languages (code),
    CONSTRAINT uq_businesses_id_business_id UNIQUE (id),
    CONSTRAINT chk_businesses_name_length CHECK (length(trim(name)) >= 2),
    CONSTRAINT chk_businesses_slug_format CHECK (
        slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    ),
    CONSTRAINT chk_businesses_timezone_length CHECK (length(trim(timezone)) >= 3),
    CONSTRAINT chk_businesses_logo_url_format CHECK (
        logo_url IS NULL
        OR logo_url ~* '^https?://'
    ),
    CONSTRAINT chk_businesses_description_length CHECK (
        description IS NULL
        OR (
            length(trim(description)) >= 10
            AND length(trim(description)) <= 1200
        )
    )
);

CREATE TABLE IF NOT EXISTS business_phone_numbers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    phone_prefix_id UUID,
    phone_number VARCHAR(30),
    phone_e164 VARCHAR(30) NOT NULL,
    label VARCHAR(100),
    is_whatsapp_enabled BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_business_phone_numbers_id_business_id UNIQUE (id, business_id),
    CONSTRAINT fk_business_phone_numbers_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_business_phone_numbers_phone_prefix FOREIGN KEY (phone_prefix_id) REFERENCES phone_prefixes (id),
    CONSTRAINT chk_business_phone_numbers_phone_number_format CHECK (
        phone_number IS NULL
        OR phone_number ~ '^[0-9]{6,20}$'
    ),
    CONSTRAINT chk_business_phone_numbers_phone_e164_format CHECK (
        phone_e164 ~ '^[+][0-9]{7,20}$'
    ),
    CONSTRAINT chk_business_phone_numbers_label_length CHECK (
        label IS NULL
        OR length(trim(label)) >= 2
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS business_phone_numbers_business_phone_unique_idx ON business_phone_numbers (business_id, phone_e164)
WHERE
    deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS business_phone_numbers_business_idx ON business_phone_numbers (business_id)
WHERE
    deleted_at IS NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_businesses_default_phone_number'
    ) THEN
        ALTER TABLE businesses
        ADD CONSTRAINT fk_businesses_default_phone_number
        FOREIGN KEY (default_phone_number_id, id)
        REFERENCES business_phone_numbers (id, business_id);
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS businesses_slug_unique_idx ON businesses (slug)
WHERE
    deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    name VARCHAR(160) NOT NULL,
    address TEXT,
    country_id UUID NOT NULL,
    currency_code CHAR(3) NOT NULL,
    default_language_code VARCHAR(10) NOT NULL,
    timezone VARCHAR(80) NOT NULL,
    google_maps_url TEXT,
    waze_url TEXT,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    business_phone_number_id UUID,
    color VARCHAR(20),
    status branch_status_enum NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_branches_id_business_id UNIQUE (id, business_id),
    CONSTRAINT fk_branches_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_branches_business_phone_number FOREIGN KEY (business_phone_number_id, business_id) REFERENCES business_phone_numbers (id, business_id),
    CONSTRAINT chk_branches_name_length CHECK (length(trim(name)) >= 2),
    CONSTRAINT fk_branches_country FOREIGN KEY (country_id) REFERENCES countries (id),
    CONSTRAINT fk_branches_currency FOREIGN KEY (currency_code) REFERENCES currencies (code),
    CONSTRAINT fk_branches_language FOREIGN KEY (default_language_code) REFERENCES languages (code),
    CONSTRAINT chk_branches_timezone_length CHECK (length(trim(timezone)) >= 3),
    CONSTRAINT chk_branches_google_maps_url_format CHECK (
        google_maps_url IS NULL
        OR google_maps_url ~* '^https?://'
    ),
    CONSTRAINT chk_branches_waze_url_format CHECK (
        waze_url IS NULL
        OR waze_url ~* '^https?://'
    ),
    CONSTRAINT chk_branches_latitude CHECK (
        latitude IS NULL
        OR latitude BETWEEN -90 AND 90
    ),
    CONSTRAINT chk_branches_longitude CHECK (
        longitude IS NULL
        OR longitude BETWEEN -180 AND 180
    ),
    CONSTRAINT chk_branches_color_format CHECK (
        color IS NULL
        OR color ~ '^#[0-9A-Fa-f]{6}$'
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS branches_business_name_unique_idx ON branches (business_id, lower(name))
WHERE
    deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS branch_opening_hours (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    day_of_week SMALLINT NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_branch_opening_hours_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_branch_opening_hours_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT chk_branch_opening_hours_day_of_week CHECK (day_of_week BETWEEN 1 AND 7),
    CONSTRAINT chk_branch_opening_hours_time_range CHECK (start_time < end_time)
);

CREATE TABLE IF NOT EXISTS branch_availability_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    override_type_id UUID NOT NULL,
    label VARCHAR(100),
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    reason TEXT,
    source source_enum NOT NULL DEFAULT 'manual',
    created_by_user_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_branch_availability_overrides_id_business_id UNIQUE (id, business_id),
    CONSTRAINT fk_branch_availability_overrides_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_branch_availability_overrides_type FOREIGN KEY (override_type_id) REFERENCES availability_override_types (id),
    CONSTRAINT fk_branch_availability_overrides_created_by_user FOREIGN KEY (created_by_user_id) REFERENCES users (id),
    CONSTRAINT chk_branch_availability_overrides_time_range CHECK (start_at < end_at)
);

CREATE TABLE IF NOT EXISTS branch_availability_override_branches (
    override_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    business_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (override_id, branch_id),
    CONSTRAINT fk_branch_availability_override_branches_override_business FOREIGN KEY (override_id, business_id) REFERENCES branch_availability_overrides (id, business_id),
    CONSTRAINT fk_branch_availability_override_branches_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id)
);

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID,
    code VARCHAR(80) NOT NULL,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_roles_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT uq_roles_business_code UNIQUE (business_id, code),
    CONSTRAINT chk_roles_code_format CHECK (code ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_roles_name_length CHECK (length(trim(name)) >= 2)
);

CREATE UNIQUE INDEX IF NOT EXISTS roles_global_code_unique_idx ON roles (code)
WHERE
    business_id IS NULL;

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    code VARCHAR(120) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_permissions_code_format CHECK (
        code ~ '^[a-z0-9_]+[.][a-z0-9_]+$'
    ),
    CONSTRAINT chk_permissions_description_length CHECK (
        length(trim(description)) >= 5
    )
);

CREATE TABLE IF NOT EXISTS business_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    role_id UUID NOT NULL,
    email VARCHAR(255) NOT NULL,
    token_hash TEXT NOT NULL,
    status invitation_status_enum NOT NULL DEFAULT 'pending',
    invited_by_user_id UUID NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_business_invitations_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_business_invitations_role FOREIGN KEY (role_id) REFERENCES roles (id),
    CONSTRAINT fk_business_invitations_invited_by_user FOREIGN KEY (invited_by_user_id) REFERENCES users (id),
    CONSTRAINT chk_business_invitations_email_format CHECK (
        email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}$'
    ),
    CONSTRAINT chk_business_invitations_token_hash_length CHECK (length(token_hash) >= 20),
    CONSTRAINT chk_business_invitations_expires_at CHECK (expires_at > created_at)
);

CREATE TABLE IF NOT EXISTS business_invite_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    role_id UUID NOT NULL,
    token_hash TEXT NOT NULL,
    status invite_link_status_enum NOT NULL DEFAULT 'active',
    max_uses INTEGER,
    uses_count INTEGER NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ,
    created_by_user_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_business_invite_links_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_business_invite_links_role FOREIGN KEY (role_id) REFERENCES roles (id),
    CONSTRAINT fk_business_invite_links_created_by_user FOREIGN KEY (created_by_user_id) REFERENCES users (id),
    CONSTRAINT chk_business_invite_links_token_hash_length CHECK (length(token_hash) >= 20),
    CONSTRAINT chk_business_invite_links_max_uses CHECK (
        max_uses IS NULL
        OR max_uses > 0
    ),
    CONSTRAINT chk_business_invite_links_uses_count CHECK (uses_count >= 0),
    CONSTRAINT chk_business_invite_links_uses_not_above_max CHECK (
        max_uses IS NULL
        OR uses_count <= max_uses
    )
);

CREATE TABLE IF NOT EXISTS workers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    user_id UUID,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone_prefix_id UUID,
    phone_number VARCHAR(30),
    phone_e164 VARCHAR(30),
    bio TEXT,
    color VARCHAR(20),
    status worker_status_enum NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_workers_id_business_id UNIQUE (id, business_id),
    CONSTRAINT fk_workers_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_workers_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_workers_phone_prefix FOREIGN KEY (phone_prefix_id) REFERENCES phone_prefixes (id),
    CONSTRAINT chk_workers_first_name_length CHECK (length(trim(first_name)) >= 2),
    CONSTRAINT chk_workers_email_format CHECK (
        email IS NULL
        OR email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}$'
    ),
    CONSTRAINT chk_workers_phone_number_format CHECK (
        phone_number IS NULL
        OR phone_number ~ '^[0-9]{6,20}$'
    ),
    CONSTRAINT chk_workers_phone_e164_format CHECK (
        phone_e164 IS NULL
        OR phone_e164 ~ '^[+][0-9]{7,20}$'
    ),
    CONSTRAINT chk_workers_color_format CHECK (
        color IS NULL
        OR color ~ '^#[0-9A-Fa-f]{6}$'
    )
);

CREATE TABLE IF NOT EXISTS worker_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    worker_id UUID NOT NULL,
    alias VARCHAR(150) NOT NULL,
    normalized_alias VARCHAR(150) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_worker_aliases_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_worker_aliases_worker_business FOREIGN KEY (worker_id, business_id) REFERENCES workers (id, business_id),
    CONSTRAINT chk_worker_aliases_alias_length CHECK (length(trim(alias)) >= 2),
    CONSTRAINT chk_worker_aliases_normalized_alias_length CHECK (
        length(trim(normalized_alias)) >= 2
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS worker_aliases_worker_normalized_unique_idx ON worker_aliases (worker_id, normalized_alias);

CREATE INDEX IF NOT EXISTS worker_aliases_business_normalized_idx ON worker_aliases (business_id, normalized_alias);

CREATE TABLE IF NOT EXISTS services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    icon_key VARCHAR(50),
    color VARCHAR(20),
    base_price NUMERIC(10, 2),
    duration_minutes INTEGER NOT NULL,
    buffer_before_minutes INTEGER NOT NULL DEFAULT 0,
    buffer_after_minutes INTEGER NOT NULL DEFAULT 0,
    status service_status_enum NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_services_id_business_id UNIQUE (id, business_id),
    CONSTRAINT fk_services_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT chk_services_name_length CHECK (length(trim(name)) >= 2),
    CONSTRAINT chk_services_base_price CHECK (
        base_price IS NULL
        OR base_price >= 0
    ),
    CONSTRAINT chk_services_duration_minutes CHECK (
        duration_minutes > 0
        AND duration_minutes <= 1440
    ),
    CONSTRAINT chk_services_buffer_before CHECK (buffer_before_minutes >= 0),
    CONSTRAINT chk_services_buffer_after CHECK (buffer_after_minutes >= 0),
    CONSTRAINT chk_services_color_format CHECK (
        color IS NULL
        OR color ~ '^#[0-9A-Fa-f]{6}$'
    )
);

CREATE TABLE IF NOT EXISTS service_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    service_id UUID NOT NULL,
    alias VARCHAR(150) NOT NULL,
    normalized_alias VARCHAR(150) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_service_aliases_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_service_aliases_service_business FOREIGN KEY (service_id, business_id) REFERENCES services (id, business_id),
    CONSTRAINT chk_service_aliases_alias_length CHECK (length(trim(alias)) >= 2),
    CONSTRAINT chk_service_aliases_normalized_alias_length CHECK (
        length(trim(normalized_alias)) >= 2
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS service_aliases_service_normalized_unique_idx ON service_aliases (service_id, normalized_alias);

CREATE INDEX IF NOT EXISTS service_aliases_business_normalized_idx ON service_aliases (business_id, normalized_alias);

CREATE TABLE IF NOT EXISTS worker_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    worker_id UUID NOT NULL,
    branch_id UUID,
    day_of_week SMALLINT NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_worker_schedules_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_worker_schedules_worker_business FOREIGN KEY (worker_id, business_id) REFERENCES workers (id, business_id),
    CONSTRAINT fk_worker_schedules_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT chk_worker_schedules_day_of_week CHECK (day_of_week BETWEEN 1 AND 7),
    CONSTRAINT chk_worker_schedules_time_range CHECK (start_time < end_time)
);

CREATE TABLE IF NOT EXISTS worker_availability_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    override_type_id UUID NOT NULL,
    label VARCHAR(100),
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    reason TEXT,
    source source_enum NOT NULL DEFAULT 'manual',
    created_by_user_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_worker_availability_overrides_id_business_id UNIQUE (id, business_id),
    CONSTRAINT fk_worker_availability_overrides_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_worker_availability_overrides_type FOREIGN KEY (override_type_id) REFERENCES availability_override_types (id),
    CONSTRAINT fk_worker_availability_overrides_created_by_user FOREIGN KEY (created_by_user_id) REFERENCES users (id),
    CONSTRAINT chk_worker_availability_overrides_time_range CHECK (start_at < end_at)
);

CREATE TABLE IF NOT EXISTS worker_availability_override_workers (
    override_id UUID NOT NULL,
    worker_id UUID NOT NULL,
    business_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (override_id, worker_id),
    CONSTRAINT fk_worker_availability_override_workers_override_business FOREIGN KEY (override_id, business_id) REFERENCES worker_availability_overrides (id, business_id),
    CONSTRAINT fk_worker_availability_override_workers_worker_business FOREIGN KEY (worker_id, business_id) REFERENCES workers (id, business_id)
);

CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    default_branch_id UUID,
    name VARCHAR(200),
    phone_prefix_id UUID,
    phone_number VARCHAR(30),
    phone_e164 VARCHAR(30),
    email VARCHAR(255),
    source source_enum NOT NULL DEFAULT 'manual',
    notes TEXT,
    status client_status_enum NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_clients_id_business_id UNIQUE (id, business_id),
    CONSTRAINT fk_clients_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_clients_default_branch_business FOREIGN KEY (
        default_branch_id,
        business_id
    ) REFERENCES branches (id, business_id),
    CONSTRAINT fk_clients_phone_prefix FOREIGN KEY (phone_prefix_id) REFERENCES phone_prefixes (id),
    CONSTRAINT chk_clients_name_length CHECK (
        name IS NULL
        OR length(trim(name)) >= 2
    ),
    CONSTRAINT chk_clients_phone_number_format CHECK (
        phone_number IS NULL
        OR phone_number ~ '^[0-9]{6,20}$'
    ),
    CONSTRAINT chk_clients_phone_e164_format CHECK (
        phone_e164 IS NULL
        OR phone_e164 ~ '^[+][0-9]{7,20}$'
    ),
    CONSTRAINT chk_clients_email_format CHECK (
        email IS NULL
        OR email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}$'
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS clients_business_phone_unique_idx ON clients (business_id, phone_e164)
WHERE
    phone_e164 IS NOT NULL
    AND deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    branch_id UUID,
    client_id UUID NOT NULL,
    channel message_channel_enum NOT NULL,
    status conversation_status_enum NOT NULL DEFAULT 'open',
    ai_enabled BOOLEAN NOT NULL DEFAULT true,
    state JSONB NOT NULL DEFAULT '{}'::jsonb,
    summary TEXT,
    last_message_at TIMESTAMPTZ,
    last_processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_conversations_id_business_id UNIQUE (id, business_id),
    CONSTRAINT fk_conversations_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_conversations_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_conversations_client_business FOREIGN KEY (client_id, business_id) REFERENCES clients (id, business_id),
    CONSTRAINT chk_conversations_state_object CHECK (
        jsonb_typeof(state) = 'object'
    )
);

CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    branch_id UUID,
    conversation_id UUID NOT NULL,
    client_id UUID,
    role message_role_enum NOT NULL,
    channel message_channel_enum NOT NULL,
    message_type message_type_enum NOT NULL DEFAULT 'text',
    content TEXT,
    external_message_id VARCHAR(255),
    status message_status_enum NOT NULL DEFAULT 'received',
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_messages_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_messages_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_messages_conversation_business FOREIGN KEY (conversation_id, business_id) REFERENCES conversations (id, business_id),
    CONSTRAINT fk_messages_client_business FOREIGN KEY (client_id, business_id) REFERENCES clients (id, business_id),
    CONSTRAINT chk_messages_metadata_object CHECK (
        metadata IS NULL
        OR jsonb_typeof(metadata) = 'object'
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS messages_external_unique_idx ON messages (channel, external_message_id)
WHERE
    external_message_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS message_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    message_id UUID NOT NULL,
    media_type attachment_type_enum NOT NULL,
    provider VARCHAR(50) NOT NULL,
    external_media_id VARCHAR(255),
    file_url TEXT,
    mime_type VARCHAR(120),
    file_size_bytes INTEGER,
    transcription TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_message_attachments_message FOREIGN KEY (message_id) REFERENCES messages (id),
    CONSTRAINT chk_message_attachments_provider_format CHECK (provider ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_message_attachments_file_url_format CHECK (
        file_url IS NULL
        OR file_url ~* '^https?://'
    ),
    CONSTRAINT chk_message_attachments_mime_type_format CHECK (
        mime_type IS NULL
        OR mime_type ~ '^[a-z0-9.+-]+/[a-z0-9.+-]+$'
    ),
    CONSTRAINT chk_message_attachments_file_size CHECK (
        file_size_bytes IS NULL
        OR file_size_bytes > 0
    ),
    CONSTRAINT chk_message_attachments_metadata_object CHECK (
        metadata IS NULL
        OR jsonb_typeof(metadata) = 'object'
    )
);

CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    branch_id UUID,
    client_id UUID NOT NULL,
    worker_id UUID NOT NULL,
    service_id UUID NOT NULL,
    color VARCHAR(20),
    conversation_id UUID,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    status appointment_status_enum NOT NULL DEFAULT 'confirmed',
    quoted_price NUMERIC(10, 2),
    currency_code CHAR(3),
    notes TEXT,
    source source_enum NOT NULL,
    created_by_type created_by_type_enum NOT NULL,
    created_by_user_id UUID,
    confirmed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancel_reason TEXT,
    expires_at TIMESTAMPTZ,
    idempotency_key VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_appointments_id_business_id UNIQUE (id, business_id),
    CONSTRAINT fk_appointments_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_appointments_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_appointments_client_business FOREIGN KEY (client_id, business_id) REFERENCES clients (id, business_id),
    CONSTRAINT fk_appointments_worker_business FOREIGN KEY (worker_id, business_id) REFERENCES workers (id, business_id),
    CONSTRAINT fk_appointments_service_business FOREIGN KEY (service_id, business_id) REFERENCES services (id, business_id),
    CONSTRAINT fk_appointments_conversation_business FOREIGN KEY (conversation_id, business_id) REFERENCES conversations (id, business_id),
    CONSTRAINT fk_appointments_currency FOREIGN KEY (currency_code) REFERENCES currencies (code),
    CONSTRAINT fk_appointments_created_by_user FOREIGN KEY (created_by_user_id) REFERENCES users (id),
    CONSTRAINT chk_appointments_time_range CHECK (start_at < end_at),
    CONSTRAINT chk_appointments_quoted_price CHECK (
        quoted_price IS NULL
        OR quoted_price >= 0
    ),
    CONSTRAINT chk_appointments_expires_at CHECK (
        expires_at IS NULL
        OR expires_at > created_at
    ),
    CONSTRAINT chk_appointments_user_creator_required CHECK (
        (
            created_by_type = 'user'
            AND created_by_user_id IS NOT NULL
        )
        OR (
            created_by_type IN ('ai', 'system')
        )
    ),
    CONSTRAINT chk_appointments_color_format CHECK (
        color IS NULL
        OR color ~ '^#[0-9A-Fa-f]{6}$'
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS appointments_idempotency_unique_idx ON appointments (idempotency_key)
WHERE
    idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS appointments_worker_time_idx ON appointments (worker_id, start_at, end_at)
WHERE
    deleted_at IS NULL
    AND status IN ('pending', 'confirmed');

CREATE INDEX IF NOT EXISTS appointments_business_worker_active_time_idx ON appointments (business_id, worker_id, start_at, end_at)
WHERE
    deleted_at IS NULL
    AND status IN ('pending', 'confirmed');

CREATE TABLE IF NOT EXISTS appointment_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    appointment_id UUID NOT NULL,
    business_id UUID NOT NULL,
    event_type appointment_event_type_enum NOT NULL,
    old_values JSONB,
    new_values JSONB,
    created_by_type created_by_type_enum NOT NULL,
    created_by_user_id UUID,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_appointment_events_appointment_business FOREIGN KEY (appointment_id, business_id) REFERENCES appointments (id, business_id),
    CONSTRAINT fk_appointment_events_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_appointment_events_created_by_user FOREIGN KEY (created_by_user_id) REFERENCES users (id),
    CONSTRAINT chk_appointment_events_old_values_object CHECK (
        old_values IS NULL
        OR jsonb_typeof(old_values) = 'object'
    ),
    CONSTRAINT chk_appointment_events_new_values_object CHECK (
        new_values IS NULL
        OR jsonb_typeof(new_values) = 'object'
    ),
    CONSTRAINT chk_appointment_events_user_creator_required CHECK (
        (
            created_by_type = 'user'
            AND created_by_user_id IS NOT NULL
        )
        OR (
            created_by_type IN ('ai', 'system')
        )
    )
);

CREATE TABLE IF NOT EXISTS message_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID,
    provider template_provider_enum NOT NULL,
    type template_type_enum NOT NULL,
    name VARCHAR(120) NOT NULL,
    external_template_name VARCHAR(255),
    language_code VARCHAR(10) NOT NULL,
    subject VARCHAR(255),
    body TEXT NOT NULL,
    status template_status_enum NOT NULL DEFAULT 'draft',
    variables_schema JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_message_templates_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_message_templates_language FOREIGN KEY (language_code) REFERENCES languages (code),
    CONSTRAINT chk_message_templates_name_length CHECK (length(trim(name)) >= 2),
    CONSTRAINT chk_message_templates_body_length CHECK (length(trim(body)) >= 1),
    CONSTRAINT chk_message_templates_variables_schema_object CHECK (
        variables_schema IS NULL
        OR jsonb_typeof(variables_schema) = 'object'
    )
);

CREATE TABLE IF NOT EXISTS business_ai_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL UNIQUE,
    ai_name VARCHAR(100) NOT NULL,
    default_language_code VARCHAR(10) NOT NULL,
    tone ai_tone_enum NOT NULL DEFAULT 'friendly',
    business_context TEXT,
    welcome_template_id UUID,
    handoff_template_id UUID,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    max_tool_calls INTEGER NOT NULL DEFAULT 3,
    tool_call_overflow_behavior tool_overflow_behavior_enum NOT NULL DEFAULT 'handoff',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_business_ai_settings_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_business_ai_settings_language FOREIGN KEY (default_language_code) REFERENCES languages (code),
    CONSTRAINT fk_business_ai_settings_welcome_template FOREIGN KEY (welcome_template_id) REFERENCES message_templates (id),
    CONSTRAINT fk_business_ai_settings_handoff_template FOREIGN KEY (handoff_template_id) REFERENCES message_templates (id),
    CONSTRAINT chk_business_ai_settings_ai_name_length CHECK (length(trim(ai_name)) >= 2),
    CONSTRAINT chk_business_ai_settings_max_tool_calls CHECK (
        max_tool_calls BETWEEN 1 AND 10
    )
);

CREATE TABLE IF NOT EXISTS business_whatsapp_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    business_phone_number_id UUID NOT NULL,
    waba_id VARCHAR(255),
    meta_phone_number_id VARCHAR(255) NOT NULL,
    display_phone_number VARCHAR(40),
    access_token_encrypted TEXT,
    status whatsapp_account_status_enum NOT NULL DEFAULT 'pending',
    connected_at TIMESTAMPTZ,
    disconnected_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_business_whatsapp_accounts_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_business_whatsapp_accounts_phone_number_business FOREIGN KEY (business_phone_number_id, business_id) REFERENCES business_phone_numbers (id, business_id),
    CONSTRAINT chk_business_whatsapp_accounts_display_phone_number_length CHECK (
        display_phone_number IS NULL
        OR length(trim(display_phone_number)) >= 5
    ),
    CONSTRAINT chk_bwa_connected_requires_token CHECK (
        status <> 'connected'
        OR (access_token_encrypted IS NOT NULL AND connected_at IS NOT NULL)
    ),
    CONSTRAINT chk_bwa_disconnected_requires_ts CHECK (
        status <> 'disconnected'
        OR disconnected_at IS NOT NULL
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS business_whatsapp_accounts_business_phone_unique_idx ON business_whatsapp_accounts (business_id, business_phone_number_id)
WHERE
    deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS business_whatsapp_accounts_business_idx ON business_whatsapp_accounts (business_id)
WHERE
    deleted_at IS NULL;

-- meta_phone_number_id is the webhook routing key; unique only among non-deleted
-- rows so a disconnected (soft-deleted) account can be reconnected later.
CREATE UNIQUE INDEX IF NOT EXISTS business_whatsapp_accounts_meta_phone_unique_idx ON business_whatsapp_accounts (meta_phone_number_id)
WHERE
    deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS calendar_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    branch_id UUID,
    worker_id UUID NOT NULL,
    provider calendar_provider_enum NOT NULL,
    external_calendar_id VARCHAR(255),
    access_token_encrypted TEXT,
    refresh_token_encrypted TEXT,
    status calendar_connection_status_enum NOT NULL DEFAULT 'connected',
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_calendar_connections_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_calendar_connections_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_calendar_connections_worker_business FOREIGN KEY (worker_id, business_id) REFERENCES workers (id, business_id)
);

CREATE TABLE IF NOT EXISTS appointment_calendar_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    branch_id UUID,
    appointment_id UUID NOT NULL,
    calendar_connection_id UUID NOT NULL,
    external_event_id VARCHAR(255) NOT NULL,
    status calendar_event_status_enum NOT NULL,
    last_synced_at TIMESTAMPTZ,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_appointment_calendar_events_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_appointment_calendar_events_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_appointment_calendar_events_appointment_business FOREIGN KEY (appointment_id, business_id) REFERENCES appointments (id, business_id),
    CONSTRAINT fk_appointment_calendar_events_calendar_connection FOREIGN KEY (calendar_connection_id) REFERENCES calendar_connections (id),
    CONSTRAINT chk_appointment_calendar_events_metadata_object CHECK (
        metadata IS NULL
        OR jsonb_typeof(metadata) = 'object'
    )
);

CREATE TABLE IF NOT EXISTS reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    branch_id UUID,
    appointment_id UUID NOT NULL,
    client_id UUID NOT NULL,
    channel message_channel_enum NOT NULL,
    scheduled_for TIMESTAMPTZ NOT NULL,
    sent_at TIMESTAMPTZ,
    status reminder_status_enum NOT NULL DEFAULT 'pending',
    template_id UUID,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_reminders_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_reminders_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_reminders_appointment_business FOREIGN KEY (appointment_id, business_id) REFERENCES appointments (id, business_id),
    CONSTRAINT fk_reminders_client_business FOREIGN KEY (client_id, business_id) REFERENCES clients (id, business_id),
    CONSTRAINT fk_reminders_template FOREIGN KEY (template_id) REFERENCES message_templates (id)
);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    branch_id UUID,
    user_id UUID NOT NULL,
    notification_type_id UUID NOT NULL,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    status notification_status_enum NOT NULL DEFAULT 'unread',
    related_entity_type entity_type_enum,
    related_entity_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ,
    CONSTRAINT fk_notifications_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_notifications_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_notifications_notification_type FOREIGN KEY (notification_type_id) REFERENCES notification_types (id),
    CONSTRAINT chk_notifications_title_length CHECK (length(trim(title)) >= 2),
    CONSTRAINT chk_notifications_body_length CHECK (length(trim(body)) >= 1)
);

CREATE TABLE IF NOT EXISTS plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    monthly_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    currency_code CHAR(3) NOT NULL,
    max_workers INTEGER,
    max_branches INTEGER,
    max_conversations_per_month INTEGER,
    max_ai_messages_per_month INTEGER,
    max_input_tokens_per_month INTEGER,
    max_output_tokens_per_month INTEGER,
    has_google_calendar BOOLEAN NOT NULL DEFAULT false,
    has_whatsapp BOOLEAN NOT NULL DEFAULT false,
    has_reminders BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_plans_currency FOREIGN KEY (currency_code) REFERENCES currencies (code),
    CONSTRAINT chk_plans_code_format CHECK (code ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_plans_name_length CHECK (length(trim(name)) >= 2),
    CONSTRAINT chk_plans_monthly_price CHECK (monthly_price >= 0),
    CONSTRAINT chk_plans_max_workers CHECK (
        max_workers IS NULL
        OR max_workers > 0
    ),
    CONSTRAINT chk_plans_max_branches CHECK (
        max_branches IS NULL
        OR max_branches > 0
    ),
    CONSTRAINT chk_plans_max_conversations CHECK (
        max_conversations_per_month IS NULL
        OR max_conversations_per_month >= 0
    ),
    CONSTRAINT chk_plans_max_ai_messages CHECK (
        max_ai_messages_per_month IS NULL
        OR max_ai_messages_per_month >= 0
    ),
    CONSTRAINT chk_plans_max_input_tokens CHECK (
        max_input_tokens_per_month IS NULL
        OR max_input_tokens_per_month >= 0
    ),
    CONSTRAINT chk_plans_max_output_tokens CHECK (
        max_output_tokens_per_month IS NULL
        OR max_output_tokens_per_month >= 0
    )
);

CREATE TABLE IF NOT EXISTS business_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    plan_id UUID NOT NULL,
    payment_provider_id UUID NOT NULL,
    provider_customer_id VARCHAR(255),
    provider_subscription_id VARCHAR(255),
    status subscription_status_enum NOT NULL,
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_business_subscriptions_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_business_subscriptions_plan FOREIGN KEY (plan_id) REFERENCES plans (id),
    CONSTRAINT fk_business_subscriptions_payment_provider FOREIGN KEY (payment_provider_id) REFERENCES payment_providers (id),
    CONSTRAINT chk_business_subscriptions_period CHECK (
        current_period_end IS NULL
        OR current_period_start IS NULL
        OR current_period_end > current_period_start
    )
);

CREATE TABLE IF NOT EXISTS usage_counters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    conversations_count INTEGER NOT NULL DEFAULT 0,
    messages_count INTEGER NOT NULL DEFAULT 0,
    ai_requests_count INTEGER NOT NULL DEFAULT 0,
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    appointments_created_count INTEGER NOT NULL DEFAULT 0,
    whatsapp_messages_sent_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_usage_counters_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT chk_usage_counters_period CHECK (period_end > period_start),
    CONSTRAINT chk_usage_counters_conversations_count CHECK (conversations_count >= 0),
    CONSTRAINT chk_usage_counters_messages_count CHECK (messages_count >= 0),
    CONSTRAINT chk_usage_counters_ai_requests_count CHECK (ai_requests_count >= 0),
    CONSTRAINT chk_usage_counters_input_tokens CHECK (input_tokens >= 0),
    CONSTRAINT chk_usage_counters_output_tokens CHECK (output_tokens >= 0),
    CONSTRAINT chk_usage_counters_appointments_created_count CHECK (
        appointments_created_count >= 0
    ),
    CONSTRAINT chk_usage_counters_whatsapp_messages_sent_count CHECK (
        whatsapp_messages_sent_count >= 0
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS usage_counters_business_period_unique_idx ON usage_counters (
    business_id,
    period_start,
    period_end
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID,
    branch_id UUID,
    user_id UUID,
    client_id UUID,
    conversation_id UUID,
    action VARCHAR(120) NOT NULL,
    entity_type entity_type_enum NOT NULL,
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_audit_logs_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_audit_logs_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_audit_logs_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_audit_logs_client FOREIGN KEY (client_id) REFERENCES clients (id),
    CONSTRAINT fk_audit_logs_conversation FOREIGN KEY (conversation_id) REFERENCES conversations (id),
    CONSTRAINT chk_audit_logs_action_format CHECK (
        action ~ '^[a-z0-9_]+[.][a-z0-9_]+$'
    ),
    CONSTRAINT chk_audit_logs_old_values_object CHECK (
        old_values IS NULL
        OR jsonb_typeof(old_values) = 'object'
    ),
    CONSTRAINT chk_audit_logs_new_values_object CHECK (
        new_values IS NULL
        OR jsonb_typeof(new_values) = 'object'
    ),
    CONSTRAINT chk_audit_logs_metadata_object CHECK (
        metadata IS NULL
        OR jsonb_typeof(metadata) = 'object'
    )
);

-- =========================================================
-- Relational tables
-- =========================================================

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID NOT NULL,
    permission_id UUID NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE,
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS business_members (
    business_id UUID NOT NULL,
    user_id UUID NOT NULL,
    role_id UUID NOT NULL,
    status member_status_enum NOT NULL DEFAULT 'active',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    PRIMARY KEY (business_id, user_id),
    CONSTRAINT fk_business_members_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_business_members_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_business_members_role FOREIGN KEY (role_id) REFERENCES roles (id)
);

CREATE TABLE IF NOT EXISTS business_invite_link_uses (
    invite_link_id UUID NOT NULL,
    user_id UUID NOT NULL,
    used_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (invite_link_id, user_id),
    CONSTRAINT fk_business_invite_link_uses_invite_link FOREIGN KEY (invite_link_id) REFERENCES business_invite_links (id),
    CONSTRAINT fk_business_invite_link_uses_user FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE TABLE IF NOT EXISTS worker_branches (
    worker_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    business_id UUID NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (worker_id, branch_id),
    CONSTRAINT fk_worker_branches_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_worker_branches_worker_business FOREIGN KEY (worker_id, business_id) REFERENCES workers (id, business_id),
    CONSTRAINT fk_worker_branches_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id)
);

CREATE TABLE IF NOT EXISTS worker_services (
    worker_id UUID NOT NULL,
    service_id UUID NOT NULL,
    business_id UUID NOT NULL,
    price_override NUMERIC(10, 2),
    duration_override_minutes INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (worker_id, service_id),
    CONSTRAINT fk_worker_services_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_worker_services_worker_business FOREIGN KEY (worker_id, business_id) REFERENCES workers (id, business_id),
    CONSTRAINT fk_worker_services_service_business FOREIGN KEY (service_id, business_id) REFERENCES services (id, business_id),
    CONSTRAINT chk_worker_services_price_override CHECK (
        price_override IS NULL
        OR price_override >= 0
    ),
    CONSTRAINT chk_worker_services_duration_override CHECK (
        duration_override_minutes IS NULL
        OR duration_override_minutes > 0
    )
);

CREATE TABLE IF NOT EXISTS branch_services (
    branch_id UUID NOT NULL,
    service_id UUID NOT NULL,
    business_id UUID NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (branch_id, service_id),
    CONSTRAINT fk_branch_services_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_branch_services_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_branch_services_service_business FOREIGN KEY (service_id, business_id) REFERENCES services (id, business_id)
);

CREATE TABLE IF NOT EXISTS client_branches (
    client_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    business_id UUID NOT NULL,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ,
    PRIMARY KEY (client_id, branch_id),
    CONSTRAINT fk_client_branches_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_client_branches_client_business FOREIGN KEY (client_id, business_id) REFERENCES clients (id, business_id),
    CONSTRAINT fk_client_branches_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT chk_client_branches_last_seen CHECK (
        last_seen_at IS NULL
        OR last_seen_at >= first_seen_at
    )
);

CREATE TABLE IF NOT EXISTS notification_preferences (
    user_id UUID NOT NULL,
    business_id UUID NOT NULL,
    notification_type_id UUID NOT NULL,
    channel notification_channel_enum NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (
        user_id,
        business_id,
        notification_type_id,
        channel
    ),
    CONSTRAINT fk_notification_preferences_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_notification_preferences_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_notification_preferences_type FOREIGN KEY (notification_type_id) REFERENCES notification_types (id)
);

-- =========================================================
-- Outbox event types
-- =========================================================

CREATE TABLE IF NOT EXISTS outbox_event_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    code VARCHAR(120) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    default_priority outbox_event_priority_enum NOT NULL DEFAULT 'normal',
    default_max_attempts INTEGER NOT NULL DEFAULT 5,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_outbox_event_types_code_format CHECK (
        code ~ '^[a-z0-9_]+[.][a-z0-9_.]+$'
    ),
    CONSTRAINT chk_outbox_event_types_name_length CHECK (length(trim(name)) >= 2),
    CONSTRAINT chk_outbox_event_types_default_max_attempts CHECK (
        default_max_attempts BETWEEN 1 AND 20
    )
);

-- =========================================================
-- Outbox events
-- =========================================================

CREATE TABLE IF NOT EXISTS outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    business_id UUID,
    branch_id UUID,
    event_type_id UUID NOT NULL,
    status outbox_event_status_enum NOT NULL DEFAULT 'pending',
    priority outbox_event_priority_enum NOT NULL DEFAULT 'normal',
    aggregate_type entity_type_enum NOT NULL,
    aggregate_id UUID NOT NULL,
    source source_enum NOT NULL DEFAULT 'system',
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata JSONB,
    idempotency_key VARCHAR(255),
    scheduled_for TIMESTAMPTZ NOT NULL DEFAULT now(),
    locked_at TIMESTAMPTZ,
    locked_by VARCHAR(120),
    lock_expires_at TIMESTAMPTZ,
    attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 5,
    last_error_message TEXT,
    last_error_metadata JSONB,
    processed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_outbox_events_business FOREIGN KEY (business_id) REFERENCES businesses (id),
    CONSTRAINT fk_outbox_events_branch_business FOREIGN KEY (branch_id, business_id) REFERENCES branches (id, business_id),
    CONSTRAINT fk_outbox_events_event_type FOREIGN KEY (event_type_id) REFERENCES outbox_event_types (id),
    CONSTRAINT chk_outbox_events_payload_object CHECK (
        jsonb_typeof(payload) = 'object'
    ),
    CONSTRAINT chk_outbox_events_metadata_object CHECK (
        metadata IS NULL
        OR jsonb_typeof(metadata) = 'object'
    ),
    CONSTRAINT chk_outbox_events_last_error_metadata_object CHECK (
        last_error_metadata IS NULL
        OR jsonb_typeof(last_error_metadata) = 'object'
    ),
    CONSTRAINT chk_outbox_events_attempts CHECK (attempts >= 0),
    CONSTRAINT chk_outbox_events_max_attempts CHECK (max_attempts BETWEEN 1 AND 20),
    CONSTRAINT chk_outbox_events_attempts_not_greater_than_max CHECK (attempts <= max_attempts),
    CONSTRAINT chk_outbox_events_lock_range CHECK (
        lock_expires_at IS NULL
        OR locked_at IS NOT NULL
    ),
    CONSTRAINT chk_outbox_events_processed_status CHECK (
        (
            status = 'completed'
            AND processed_at IS NOT NULL
        )
        OR (status <> 'completed')
    ),
    CONSTRAINT chk_outbox_events_failed_status CHECK (
        (
            status IN ('failed', 'dead_letter')
            AND failed_at IS NOT NULL
        )
        OR (
            status NOT IN ('failed', 'dead_letter')
        )
    ),
    CONSTRAINT chk_outbox_events_cancelled_status CHECK (
        (
            status = 'cancelled'
            AND cancelled_at IS NOT NULL
        )
        OR (status <> 'cancelled')
    )
);

-- =========================================================
-- Extra indexes for common query paths
-- =========================================================

CREATE INDEX IF NOT EXISTS businesses_country_idx ON businesses (country_id);

CREATE INDEX IF NOT EXISTS branches_business_idx ON branches (business_id);

CREATE INDEX IF NOT EXISTS branches_business_phone_number_idx ON branches (business_phone_number_id)
WHERE
    business_phone_number_id IS NOT NULL
    AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS branch_opening_hours_branch_day_idx ON branch_opening_hours (branch_id, day_of_week)
WHERE
    deleted_at IS NULL
    AND is_active = true;

CREATE INDEX IF NOT EXISTS branch_availability_overrides_business_time_idx ON branch_availability_overrides (business_id, start_at, end_at)
WHERE
    deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS branch_availability_override_branches_branch_idx ON branch_availability_override_branches (branch_id, override_id);

CREATE INDEX IF NOT EXISTS branch_availability_override_branches_business_branch_idx ON branch_availability_override_branches (business_id, branch_id);

CREATE INDEX IF NOT EXISTS workers_business_idx ON workers (business_id);

CREATE INDEX IF NOT EXISTS services_business_idx ON services (business_id);

CREATE INDEX IF NOT EXISTS worker_schedules_worker_day_idx ON worker_schedules (worker_id, day_of_week)
WHERE
    deleted_at IS NULL
    AND is_active = true;

CREATE INDEX IF NOT EXISTS worker_schedules_branch_day_idx ON worker_schedules (branch_id, day_of_week)
WHERE
    branch_id IS NOT NULL
    AND deleted_at IS NULL
    AND is_active = true;

CREATE INDEX IF NOT EXISTS worker_availability_overrides_business_time_idx ON worker_availability_overrides (business_id, start_at, end_at)
WHERE
    deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS worker_availability_override_workers_worker_idx ON worker_availability_override_workers (worker_id, override_id);

CREATE INDEX IF NOT EXISTS worker_availability_override_workers_business_worker_idx ON worker_availability_override_workers (business_id, worker_id);

CREATE INDEX IF NOT EXISTS clients_business_idx ON clients (business_id);

CREATE INDEX IF NOT EXISTS conversations_business_client_idx ON conversations (business_id, client_id);

-- At most one OPEN conversation per client + channel (race guard for concurrent inbound webhooks).
CREATE UNIQUE INDEX IF NOT EXISTS conversations_open_channel_unique_idx
ON conversations (business_id, client_id, channel)
WHERE status = 'open' AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS messages_conversation_created_idx ON messages (conversation_id, created_at);

CREATE INDEX IF NOT EXISTS appointments_business_start_idx ON appointments (business_id, start_at);

CREATE INDEX IF NOT EXISTS appointments_client_start_idx ON appointments (client_id, start_at);

CREATE INDEX IF NOT EXISTS reminders_pending_idx ON reminders (scheduled_for)
WHERE
    status = 'pending'
    AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS notifications_user_status_idx ON notifications (user_id, status, created_at);

CREATE INDEX IF NOT EXISTS outbox_event_types_code_idx ON outbox_event_types (code)
WHERE
    deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS outbox_events_idempotency_unique_idx ON outbox_events (idempotency_key)
WHERE
    idempotency_key IS NOT NULL
    AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS outbox_events_pending_idx ON outbox_events (
    status,
    scheduled_for,
    priority,
    created_at
)
WHERE
    status = 'pending'
    AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS outbox_events_processing_locks_idx ON outbox_events (status, lock_expires_at)
WHERE
    status = 'processing'
    AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS outbox_events_business_status_idx ON outbox_events (
    business_id,
    status,
    created_at
)
WHERE
    deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS outbox_events_aggregate_idx ON outbox_events (aggregate_type, aggregate_id)
WHERE
    deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS outbox_events_event_type_status_idx ON outbox_events (
    event_type_id,
    status,
    created_at
)
WHERE
    deleted_at IS NULL;

-- =========================================================
-- updated_at triggers
-- =========================================================

DROP TRIGGER IF EXISTS trg_users_set_updated_at ON users;

CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_businesses_set_updated_at ON businesses;

CREATE TRIGGER trg_businesses_set_updated_at
BEFORE UPDATE ON businesses
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_business_phone_numbers_set_updated_at ON business_phone_numbers;

CREATE TRIGGER trg_business_phone_numbers_set_updated_at
BEFORE UPDATE ON business_phone_numbers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_branches_set_updated_at ON branches;

CREATE TRIGGER trg_branches_set_updated_at
BEFORE UPDATE ON branches
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_branch_opening_hours_set_updated_at ON branch_opening_hours;

CREATE TRIGGER trg_branch_opening_hours_set_updated_at
BEFORE UPDATE ON branch_opening_hours
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_branch_availability_overrides_set_updated_at ON branch_availability_overrides;

CREATE TRIGGER trg_branch_availability_overrides_set_updated_at
BEFORE UPDATE ON branch_availability_overrides
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_roles_set_updated_at ON roles;

CREATE TRIGGER trg_roles_set_updated_at
BEFORE UPDATE ON roles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_business_invite_links_set_updated_at ON business_invite_links;

CREATE TRIGGER trg_business_invite_links_set_updated_at
BEFORE UPDATE ON business_invite_links
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_workers_set_updated_at ON workers;

CREATE TRIGGER trg_workers_set_updated_at
BEFORE UPDATE ON workers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_services_set_updated_at ON services;

CREATE TRIGGER trg_services_set_updated_at
BEFORE UPDATE ON services
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_worker_schedules_set_updated_at ON worker_schedules;

CREATE TRIGGER trg_worker_schedules_set_updated_at
BEFORE UPDATE ON worker_schedules
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_worker_availability_overrides_set_updated_at ON worker_availability_overrides;

CREATE TRIGGER trg_worker_availability_overrides_set_updated_at
BEFORE UPDATE ON worker_availability_overrides
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_clients_set_updated_at ON clients;

CREATE TRIGGER trg_clients_set_updated_at
BEFORE UPDATE ON clients
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_conversations_set_updated_at ON conversations;

CREATE TRIGGER trg_conversations_set_updated_at
BEFORE UPDATE ON conversations
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_appointments_set_updated_at ON appointments;

CREATE TRIGGER trg_appointments_set_updated_at
BEFORE UPDATE ON appointments
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_message_templates_set_updated_at ON message_templates;

CREATE TRIGGER trg_message_templates_set_updated_at
BEFORE UPDATE ON message_templates
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_business_ai_settings_set_updated_at ON business_ai_settings;

CREATE TRIGGER trg_business_ai_settings_set_updated_at
BEFORE UPDATE ON business_ai_settings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_business_whatsapp_accounts_set_updated_at ON business_whatsapp_accounts;

CREATE TRIGGER trg_business_whatsapp_accounts_set_updated_at
BEFORE UPDATE ON business_whatsapp_accounts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_calendar_connections_set_updated_at ON calendar_connections;

CREATE TRIGGER trg_calendar_connections_set_updated_at
BEFORE UPDATE ON calendar_connections
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_appointment_calendar_events_set_updated_at ON appointment_calendar_events;

CREATE TRIGGER trg_appointment_calendar_events_set_updated_at
BEFORE UPDATE ON appointment_calendar_events
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_reminders_set_updated_at ON reminders;

CREATE TRIGGER trg_reminders_set_updated_at
BEFORE UPDATE ON reminders
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_plans_set_updated_at ON plans;

CREATE TRIGGER trg_plans_set_updated_at
BEFORE UPDATE ON plans
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_business_subscriptions_set_updated_at ON business_subscriptions;

CREATE TRIGGER trg_business_subscriptions_set_updated_at
BEFORE UPDATE ON business_subscriptions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_usage_counters_set_updated_at ON usage_counters;

CREATE TRIGGER trg_usage_counters_set_updated_at
BEFORE UPDATE ON usage_counters
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_business_members_set_updated_at ON business_members;

CREATE TRIGGER trg_business_members_set_updated_at
BEFORE UPDATE ON business_members
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_worker_services_set_updated_at ON worker_services;

CREATE TRIGGER trg_worker_services_set_updated_at
BEFORE UPDATE ON worker_services
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_notification_preferences_set_updated_at ON notification_preferences;

CREATE TRIGGER trg_notification_preferences_set_updated_at
BEFORE UPDATE ON notification_preferences
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_outbox_event_types_set_updated_at ON outbox_event_types;

CREATE TRIGGER trg_outbox_event_types_set_updated_at
BEFORE UPDATE ON outbox_event_types
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_outbox_events_set_updated_at ON outbox_events;

CREATE TRIGGER trg_outbox_events_set_updated_at
BEFORE UPDATE ON outbox_events
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- Enforce monotonic, lifecycle-correct message status transitions.
CREATE OR REPLACE FUNCTION enforce_message_status_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
        RETURN NEW; -- idempotent no-op
    END IF;

    IF (OLD.status, NEW.status) IN (
        -- inbound lifecycle
        ('received','processing'), ('received','processed'), ('received','ignored'), ('received','failed'),
        ('processing','processed'), ('processing','ignored'), ('processing','failed'),
        -- outbound lifecycle
        ('queued','sent'), ('queued','failed'),
        ('sent','delivered'), ('sent','read'), ('sent','failed'),
        ('delivered','read'),
        -- explicit recovery
        ('failed','queued'), ('failed','processing')
    ) THEN
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Illegal message status transition % -> %', OLD.status, NEW.status
        USING ERRCODE = 'check_violation';
END;
$$;

DROP TRIGGER IF EXISTS trg_messages_status_transition ON messages;
CREATE TRIGGER trg_messages_status_transition
BEFORE UPDATE OF status ON messages
FOR EACH ROW
EXECUTE FUNCTION enforce_message_status_transition();
