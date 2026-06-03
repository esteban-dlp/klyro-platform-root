-- Phase 10 WhatsApp integration. Apply to databases created before 2026-06-02.
-- NOTE: ALTER TYPE ... ADD VALUE cannot run inside a transaction block.

ALTER TYPE message_status_enum ADD VALUE IF NOT EXISTS 'delivered' AFTER 'sent';
ALTER TYPE message_status_enum ADD VALUE IF NOT EXISTS 'read' AFTER 'delivered';

-- (Index, CHECKs and trigger from Task 4 are appended to this file in a later task.)
