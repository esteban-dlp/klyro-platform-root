-- 004-seed-message-templates.sql
-- Klyro global message templates.
-- These are internal defaults. Business-specific templates can override them later.
-- English is the single source of truth; other languages are produced on demand
-- by the AI and cached in message_template_translations.
-- Safe to run multiple times.

\connect klyro

BEGIN;

-- =========================================================
-- English global templates (source of truth)
-- =========================================================

INSERT INTO message_templates (
    business_id,
    provider,
    type,
    name,
    external_template_name,
    language_code,
    subject,
    body,
    status,
    variables_schema
)
SELECT
    NULL,
    'internal',
    v.type::template_type_enum,
    v.name,
    NULL,
    'en',
    v.subject,
    v.body,
    'active',
    v.variables_schema::jsonb
FROM (
    VALUES
        (
            'welcome',
            'global_welcome_en',
            NULL,
            'Hi, I’m {{ai_name}}, the virtual assistant for {{business_name}}. I’m here and ready to help.',
            '{"ai_name":"string","business_name":"string"}'
        ),
        (
            'confirmation',
            'global_appointment_confirmation_en',
            NULL,
            'Done, your appointment is confirmed for {{appointment_date}} at {{appointment_time}} with {{worker_name}} for {{service_name}}.',
            '{"appointment_date":"string","appointment_time":"string","worker_name":"string","service_name":"string"}'
        ),
        (
            'reminder',
            'global_appointment_reminder_en',
            NULL,
            'Reminder: you have an appointment at {{business_name}} on {{appointment_date}} at {{appointment_time}} with {{worker_name}}.',
            '{"business_name":"string","appointment_date":"string","appointment_time":"string","worker_name":"string"}'
        ),
        (
            'cancellation',
            'global_appointment_cancellation_en',
            NULL,
            'Your appointment on {{appointment_date}} at {{appointment_time}} was cancelled. I can help you find another time.',
            '{"appointment_date":"string","appointment_time":"string"}'
        ),
        (
            'reschedule',
            'global_appointment_reschedule_en',
            NULL,
            'Your appointment was rescheduled to {{appointment_date}} at {{appointment_time}} with {{worker_name}}.',
            '{"appointment_date":"string","appointment_time":"string","worker_name":"string"}'
        ),
        (
            'handoff',
            'global_handoff_en',
            NULL,
            'I will pass your conversation to someone from the team so they can help you better.',
            '{}'
        )
) AS v(type, name, subject, body, variables_schema)
WHERE NOT EXISTS (
    SELECT 1
    FROM message_templates mt
    WHERE mt.business_id IS NULL
      AND mt.provider = 'internal'
      AND mt.language_code = 'en'
      AND mt.name = v.name
);

COMMIT;
