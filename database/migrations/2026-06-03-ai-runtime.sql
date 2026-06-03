-- 2026-06-03-ai-runtime.sql
-- Phase 11 (AI runtime): add the conversation.handoff outbox event type.
-- Transaction-safe (pure INSERT; no ALTER TYPE). Apply to any pre-existing database.
INSERT INTO outbox_event_types (code, name, description, default_priority, default_max_attempts)
VALUES (
    'conversation.handoff',
    'Conversation handoff',
    'Triggered when the AI hands a conversation to a human.',
    'high',
    5
)
ON CONFLICT (code) DO NOTHING;
