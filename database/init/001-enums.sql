-- 001-enums.sql
-- Klyro PostgreSQL enums.
-- Run after 000-create-database.sql.

\connect klyro

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'auth_provider_enum') THEN
        CREATE TYPE auth_provider_enum AS ENUM ('local', 'firebase');

END IF;

IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ai_provider_enum') THEN
    CREATE TYPE ai_provider_enum AS ENUM ('openai', 'google');

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'user_status_enum'
) THEN
CREATE TYPE user_status_enum AS ENUM(
    'active',
    'inactive',
    'suspended',
    'banned'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'business_status_enum'
) THEN
CREATE TYPE business_status_enum AS ENUM(
    'active',
    'inactive',
    'paused',
    'suspended'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'branch_status_enum'
) THEN
CREATE TYPE branch_status_enum AS ENUM('active', 'inactive');

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'member_status_enum'
) THEN
CREATE TYPE member_status_enum AS ENUM(
    'active',
    'inactive',
    'removed'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'invitation_status_enum'
) THEN
CREATE TYPE invitation_status_enum AS ENUM(
    'pending',
    'accepted',
    'expired',
    'cancelled'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'invite_link_status_enum'
) THEN
CREATE TYPE invite_link_status_enum AS ENUM(
    'active',
    'inactive',
    'expired',
    'revoked'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'worker_status_enum'
) THEN
CREATE TYPE worker_status_enum AS ENUM(
    'active',
    'inactive',
    'archived'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'service_status_enum'
) THEN
CREATE TYPE service_status_enum AS ENUM(
    'active',
    'inactive',
    'archived'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'client_status_enum'
) THEN
CREATE TYPE client_status_enum AS ENUM('active', 'blocked');

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'conversation_status_enum'
) THEN
CREATE TYPE conversation_status_enum AS ENUM(
    'open',
    'pending_ai',
    'pending_human',
    'closed',
    'archived'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'message_role_enum'
) THEN
CREATE TYPE message_role_enum AS ENUM(
    'client',
    'assistant',
    'system',
    'tool',
    'human',
    'worker'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'message_channel_enum'
) THEN
CREATE TYPE message_channel_enum AS ENUM(
    'demo',
    'whatsapp',
    'web',
    'manual',
    'email'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'message_type_enum'
) THEN
CREATE TYPE message_type_enum AS ENUM(
    'text',
    'audio',
    'image',
    'video',
    'document',
    'sticker',
    'tool_result',
    'system_event'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'attachment_type_enum'
) THEN
CREATE TYPE attachment_type_enum AS ENUM(
    'audio',
    'image',
    'video',
    'document',
    'sticker'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'message_status_enum'
) THEN
CREATE TYPE message_status_enum AS ENUM(
    'received',
    'queued',
    'processing',
    'processed',
    'sent',
    'delivered',
    'read',
    'failed',
    'ignored'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'source_enum'
) THEN
CREATE TYPE source_enum AS ENUM(
    'ai',
    'manual',
    'demo',
    'whatsapp',
    'web',
    'system',
    'import',
    'google_calendar'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'appointment_status_enum'
) THEN
CREATE TYPE appointment_status_enum AS ENUM(
    'pending',
    'confirmed',
    'cancelled',
    'completed',
    'no_show',
    'rescheduled'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'created_by_type_enum'
) THEN
CREATE TYPE created_by_type_enum AS ENUM('user', 'ai', 'system');

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'appointment_event_type_enum'
) THEN
CREATE TYPE appointment_event_type_enum AS ENUM(
    'created',
    'confirmed',
    'cancelled',
    'rescheduled',
    'completed',
    'no_show',
    'updated'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'ai_tone_enum'
) THEN
CREATE TYPE ai_tone_enum AS ENUM(
    'friendly',
    'professional',
    'casual',
    'formal'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'ai_emoji_usage_enum'
) THEN
CREATE TYPE ai_emoji_usage_enum AS ENUM(
    'never',
    'few',
    'normal'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'tool_overflow_behavior_enum'
) THEN
CREATE TYPE tool_overflow_behavior_enum AS ENUM(
    'handoff',
    'fallback_message',
    'stop'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'template_provider_enum'
) THEN
CREATE TYPE template_provider_enum AS ENUM(
    'internal',
    'whatsapp_meta',
    'email'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'template_type_enum'
) THEN
CREATE TYPE template_type_enum AS ENUM(
    'welcome',
    'reminder',
    'confirmation',
    'cancellation',
    'reschedule',
    'handoff',
    'generic'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'template_status_enum'
) THEN
CREATE TYPE template_status_enum AS ENUM(
    'draft',
    'active',
    'pending_approval',
    'approved',
    'rejected',
    'archived'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'calendar_provider_enum'
) THEN
CREATE TYPE calendar_provider_enum AS ENUM(
    'google',
    'apple_ics',
    'outlook'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'calendar_connection_status_enum'
) THEN
CREATE TYPE calendar_connection_status_enum AS ENUM(
    'connected',
    'expired',
    'disconnected',
    'error'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'calendar_event_status_enum'
) THEN
CREATE TYPE calendar_event_status_enum AS ENUM(
    'created',
    'updated',
    'cancelled',
    'sync_failed'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'whatsapp_account_status_enum'
) THEN
CREATE TYPE whatsapp_account_status_enum AS ENUM(
    'connected',
    'disconnected',
    'pending',
    'error'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'reminder_status_enum'
) THEN
CREATE TYPE reminder_status_enum AS ENUM(
    'pending',
    'sent',
    'failed',
    'cancelled',
    'skipped'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'notification_channel_enum'
) THEN
CREATE TYPE notification_channel_enum AS ENUM('in_app', 'email');

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'notification_status_enum'
) THEN
CREATE TYPE notification_status_enum AS ENUM('unread', 'read', 'archived');

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'subscription_status_enum'
) THEN
CREATE TYPE subscription_status_enum AS ENUM(
    'free',
    'active',
    'trialing',
    'past_due',
    'cancelled',
    'expired'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'entity_type_enum'
) THEN
CREATE TYPE entity_type_enum AS ENUM(
    'business',
    'branch',
    'user',
    'worker',
    'service',
    'client',
    'conversation',
    'message',
    'appointment',
    'reminder',
    'notification',
    'subscription',
    'whatsapp_account',
    'calendar_connection'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'outbox_event_status_enum'
) THEN
CREATE TYPE outbox_event_status_enum AS ENUM(
    'pending',
    'processing',
    'completed',
    'failed',
    'cancelled',
    'dead_letter'
);

END IF;

IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE
        typname = 'outbox_event_priority_enum'
) THEN
CREATE TYPE outbox_event_priority_enum AS ENUM(
    'low',
    'normal',
    'high',
    'critical'
);

END IF;

END $$;