-- 014-seed-plans.sql
-- Klyro plan seed.
-- Lemon Squeezy can manage payment, but Klyro needs local plan limits.
-- Safe to run multiple times.

\connect klyro

BEGIN;

INSERT INTO plans (
    code,
    name,
    description,
    monthly_price,
    currency_code,
    max_workers,
    max_branches,
    max_conversations_per_month,
    max_ai_messages_per_month,
    max_input_tokens_per_month,
    max_output_tokens_per_month,
    has_google_calendar,
    has_whatsapp,
    has_reminders,
    is_active
)
VALUES
    (
        'free',
        'Free',
        'Free plan for testing Klyro with limited usage.',
        0.00,
        'USD',
        1,
        1,
        30,
        100,
        100000,
        30000,
        false,
        false,
        false,
        true
    ),
    (
        'pro',
        'Pro',
        'Main plan for small businesses that want AI-assisted appointment booking.',
        19.00,
        'USD',
        10,
        3,
        1000,
        3000,
        3000000,
        900000,
        true,
        true,
        true,
        true
    ),
    (
        'max',
        'Max',
        'Higher-volume plan for businesses with more workers, branches and conversations.',
        49.00,
        'USD',
        NULL,
        NULL,
        5000,
        15000,
        15000000,
        4500000,
        true,
        true,
        true,
        true
    )
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    monthly_price = EXCLUDED.monthly_price,
    currency_code = EXCLUDED.currency_code,
    max_workers = EXCLUDED.max_workers,
    max_branches = EXCLUDED.max_branches,
    max_conversations_per_month = EXCLUDED.max_conversations_per_month,
    max_ai_messages_per_month = EXCLUDED.max_ai_messages_per_month,
    max_input_tokens_per_month = EXCLUDED.max_input_tokens_per_month,
    max_output_tokens_per_month = EXCLUDED.max_output_tokens_per_month,
    has_google_calendar = EXCLUDED.has_google_calendar,
    has_whatsapp = EXCLUDED.has_whatsapp,
    has_reminders = EXCLUDED.has_reminders,
    is_active = EXCLUDED.is_active;

COMMIT;
