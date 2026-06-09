-- 2026-06-08 scheduling enums
-- Adds duration enum used by services, service options, and service extras.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'service_duration_type_enum') THEN
        CREATE TYPE service_duration_type_enum AS ENUM ('fixed', 'range');
    END IF;
END
$$;
