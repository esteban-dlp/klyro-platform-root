-- 012-seed-operational-types.sql
-- Klyro operational type seed.
-- Includes availability override types and notification types.
-- Safe to run multiple times.

\connect klyro

BEGIN;

-- =========================================================
-- Availability override types
-- =========================================================

INSERT INTO
    availability_override_types (
        code,
        name,
        blocks_availability,
        is_active
    )
VALUES (
        'closed_day',
        'Closed Day',
        true,
        true
    ),
    (
        'custom_hours',
        'Custom Hours',
        false,
        true
    ),
    (
        'vacation',
        'Vacation',
        true,
        true
    ),
    (
        'sick_leave',
        'Sick Leave',
        true,
        true
    ),
    ('break', 'Break', true, true),
    ('lunch', 'Lunch', true, true),
    (
        'meeting',
        'Meeting',
        true,
        true
    ),
    (
        'emergency',
        'Emergency',
        true,
        true
    ),
    (
        'manual_block',
        'Manual Block',
        true,
        true
    ),
    (
        'external_calendar_busy',
        'External Calendar Busy',
        true,
        true
    )
ON CONFLICT (code) DO
UPDATE
SET
    name = EXCLUDED.name,
    blocks_availability = EXCLUDED.blocks_availability,
    is_active = EXCLUDED.is_active;

-- =========================================================
-- Notification types
-- =========================================================

INSERT INTO
    notification_types (
        code,
        name,
        description,
        default_enabled
    )
VALUES (
        'appointment_created',
        'Appointment Created',
        'Triggered when a new appointment is created.',
        true
    ),
    (
        'appointment_cancelled',
        'Appointment Cancelled',
        'Triggered when an appointment is cancelled.',
        true
    ),
    (
        'appointment_rescheduled',
        'Appointment Rescheduled',
        'Triggered when an appointment is moved to another date or time.',
        true
    ),
    (
        'appointment_completed',
        'Appointment Completed',
        'Triggered when an appointment is marked as completed.',
        false
    ),
    (
        'appointment_no_show',
        'Appointment No-show',
        'Triggered when a client does not show up.',
        true
    ),
    (
        'appointment_reminder_failed',
        'Appointment Reminder Failed',
        'Triggered when a reminder could not be sent.',
        true
    ),
    (
        'handoff_needed',
        'Human Handoff Needed',
        'Triggered when the AI needs human intervention.',
        true
    ),
    (
        'conversation_error',
        'Conversation Error',
        'Triggered when the AI or conversation processor fails.',
        true
    ),
    (
        'conversation_paused',
        'Conversation Paused',
        'Triggered when AI is paused for a conversation.',
        false
    ),
    (
        'worker_unavailable',
        'Worker Unavailable',
        'Triggered when a worker becomes unavailable due to an override.',
        true
    ),
    (
        'worker_schedule_changed',
        'Worker Schedule Changed',
        'Triggered when a worker schedule is changed.',
        false
    ),
    (
        'whatsapp_disconnected',
        'WhatsApp Disconnected',
        'Triggered when a WhatsApp account gets disconnected or fails.',
        true
    ),
    (
        'calendar_sync_failed',
        'Calendar Sync Failed',
        'Triggered when calendar synchronization fails.',
        true
    ),
    (
        'usage_limit_warning',
        'Usage Limit Warning',
        'Triggered when a business approaches its plan usage limit.',
        true
    ),
    (
        'usage_limit_reached',
        'Usage Limit Reached',
        'Triggered when a business reaches its plan usage limit.',
        true
    ),
    (
        'subscription_status_changed',
        'Subscription Status Changed',
        'Triggered when a subscription status changes.',
        true
    )
ON CONFLICT (code) DO
UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    default_enabled = EXCLUDED.default_enabled;

-- =========================================================
-- Outbox event types
-- =========================================================

INSERT INTO
    outbox_event_types (
        code,
        name,
        description,
        default_priority,
        default_max_attempts
    )
VALUES (
        'appointment.created',
        'Appointment created',
        'Triggered when an appointment is created.',
        'high',
        5
    ),
    (
        'appointment.cancelled',
        'Appointment cancelled',
        'Triggered when an appointment is cancelled.',
        'high',
        5
    ),
    (
        'appointment.rescheduled',
        'Appointment rescheduled',
        'Triggered when an appointment is rescheduled.',
        'high',
        5
    ),
    (
        'whatsapp.message.send',
        'Send WhatsApp message',
        'Queues an outbound WhatsApp message.',
        'high',
        5
    ),
    (
        'calendar.event.create',
        'Create calendar event',
        'Creates an external calendar event.',
        'normal',
        5
    ),
    (
        'calendar.event.update',
        'Update calendar event',
        'Updates an external calendar event.',
        'normal',
        5
    ),
    (
        'calendar.event.cancel',
        'Cancel calendar event',
        'Cancels an external calendar event.',
        'normal',
        5
    ),
    (
        'reminder.send',
        'Send reminder',
        'Sends a scheduled appointment reminder.',
        'normal',
        5
    ),
    (
        'conversation.process',
        'Process conversation',
        'Processes an incoming conversation message through the AI engine.',
        'critical',
        3
    ),
    (
        'billing.usage.increment',
        'Increment usage counter',
        'Increments usage counters for billing and limits.',
        'normal',
        5
    )
ON CONFLICT (code) DO NOTHING;

COMMIT;