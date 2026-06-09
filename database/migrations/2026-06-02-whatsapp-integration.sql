-- Phase 10 WhatsApp integration. Apply to databases created before 2026-06-02.
-- NOTE: ALTER TYPE ... ADD VALUE cannot run inside a transaction block.

ALTER TYPE message_status_enum ADD VALUE IF NOT EXISTS 'delivered' AFTER 'sent';
ALTER TYPE message_status_enum ADD VALUE IF NOT EXISTS 'read' AFTER 'delivered';

-- Conversation race guard
CREATE UNIQUE INDEX IF NOT EXISTS conversations_open_channel_unique_idx
ON conversations (business_id, client_id, channel)
WHERE status = 'open' AND deleted_at IS NULL;

-- WhatsApp account state consistency
ALTER TABLE business_whatsapp_accounts DROP CONSTRAINT IF EXISTS chk_bwa_connected_requires_token;
ALTER TABLE business_whatsapp_accounts
    ADD CONSTRAINT chk_bwa_connected_requires_token CHECK (
        status <> 'connected' OR (access_token_encrypted IS NOT NULL AND connected_at IS NOT NULL));
ALTER TABLE business_whatsapp_accounts DROP CONSTRAINT IF EXISTS chk_bwa_disconnected_requires_ts;
ALTER TABLE business_whatsapp_accounts
    ADD CONSTRAINT chk_bwa_disconnected_requires_ts CHECK (
        status <> 'disconnected' OR disconnected_at IS NOT NULL);

-- Message status-transition guard
CREATE OR REPLACE FUNCTION enforce_message_status_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
        RETURN NEW;
    END IF;
    IF (OLD.status, NEW.status) IN (
        ('received','processing'), ('received','processed'), ('received','ignored'), ('received','failed'),
        ('processing','processed'), ('processing','ignored'), ('processing','failed'),
        ('queued','sent'), ('queued','failed'),
        ('sent','delivered'), ('sent','read'), ('sent','failed'),
        ('delivered','read'),
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

-- Reconnect-after-disconnect: meta_phone_number_id uniqueness must ignore soft-deleted rows
ALTER TABLE business_whatsapp_accounts DROP CONSTRAINT IF EXISTS business_whatsapp_accounts_meta_phone_number_id_key;
CREATE UNIQUE INDEX IF NOT EXISTS business_whatsapp_accounts_meta_phone_unique_idx
ON business_whatsapp_accounts (meta_phone_number_id)
WHERE deleted_at IS NULL;
