-- 011-seed-security.sql
-- Klyro security seed.
-- Includes global roles, permissions and role-permission assignment.
-- Safe to run multiple times.

\connect klyro

BEGIN;

-- =========================================================
-- Global roles
-- For now business_id stays NULL. Later, custom business roles can be added.
-- =========================================================

INSERT INTO roles (business_id, code, name, description, is_system_role)
SELECT NULL, 'owner', 'Owner', 'Full business owner. Can manage the business, workers, services, appointments, conversations, settings and billing.', true
WHERE NOT EXISTS (
    SELECT 1 FROM roles WHERE business_id IS NULL AND code = 'owner'
);

UPDATE roles
SET
    name = 'Owner',
    description = 'Full business owner. Can manage the business, workers, services, appointments, conversations, settings and billing.',
    is_system_role = true
WHERE business_id IS NULL AND code = 'owner';

INSERT INTO roles (business_id, code, name, description, is_system_role)
SELECT NULL, 'worker', 'Worker', 'Worker role. Can view assigned appointments, availability and relevant conversations.', true
WHERE NOT EXISTS (
    SELECT 1 FROM roles WHERE business_id IS NULL AND code = 'worker'
);

UPDATE roles
SET
    name = 'Worker',
    description = 'Worker role. Can view assigned appointments, availability and relevant conversations.',
    is_system_role = true
WHERE business_id IS NULL AND code = 'worker';

-- =========================================================
-- Permissions
-- Pattern: resource.action
-- Keep permissions semantic, not directly tied to HTTP methods.
-- =========================================================

INSERT INTO permissions (code, description)
VALUES
    ('business.read', 'View business information.'),
    ('business.update', 'Update business information.'),

    ('branches.create', 'Create business branches.'),
    ('branches.read', 'View business branches.'),
    ('branches.update', 'Update business branches.'),
    ('branches.delete', 'Delete or deactivate business branches.'),

    ('members.invite', 'Invite users to the business.'),
    ('members.read', 'View business members.'),
    ('members.update', 'Update member roles or status.'),
    ('members.remove', 'Remove members from the business.'),

    ('workers.create', 'Create workers.'),
    ('workers.read', 'View workers.'),
    ('workers.update', 'Update workers.'),
    ('workers.delete', 'Delete or deactivate workers.'),

    ('services.create', 'Create services.'),
    ('services.read', 'View services.'),
    ('services.update', 'Update services.'),
    ('services.delete', 'Delete or deactivate services.'),

    ('schedules.create', 'Create worker schedules and availability overrides.'),
    ('schedules.read', 'View schedules and availability.'),
    ('schedules.update', 'Update schedules and availability.'),
    ('schedules.delete', 'Delete or deactivate schedule records.'),

    ('clients.create', 'Create clients.'),
    ('clients.read', 'View clients.'),
    ('clients.update', 'Update clients.'),
    ('clients.delete', 'Delete, block or anonymize clients.'),

    ('appointments.create', 'Create appointments.'),
    ('appointments.read', 'View appointments.'),
    ('appointments.update', 'Update appointments.'),
    ('appointments.cancel', 'Cancel appointments.'),
    ('appointments.complete', 'Mark appointments as completed.'),
    ('appointments.no_show', 'Mark appointments as no-show.'),

    ('conversations.read', 'View conversations.'),
    ('conversations.reply', 'Reply manually to conversations.'),
    ('conversations.handoff', 'Take over conversations that need human intervention.'),
    ('conversations.update', 'Update conversation status or AI availability.'),

    ('messages.read', 'View messages.'),
    ('messages.create', 'Create internal or manual messages.'),

    ('ai_settings.read', 'View AI settings.'),
    ('ai_settings.update', 'Update AI settings and business context.'),

    ('templates.create', 'Create message templates.'),
    ('templates.read', 'View message templates.'),
    ('templates.update', 'Update message templates.'),
    ('templates.delete', 'Archive or delete message templates.'),

    ('notifications.read', 'View notifications.'),
    ('notifications.update', 'Mark notifications as read or archived.'),
    ('notification_preferences.update', 'Update notification preferences.'),

    ('whatsapp.connect', 'Connect WhatsApp accounts.'),
    ('whatsapp.read', 'View WhatsApp connection status.'),
    ('whatsapp.update', 'Update WhatsApp account settings.'),
    ('whatsapp.disconnect', 'Disconnect WhatsApp accounts.'),

    ('calendar.connect', 'Connect calendar accounts.'),
    ('calendar.read', 'View calendar connection status.'),
    ('calendar.update', 'Update calendar connection settings.'),
    ('calendar.disconnect', 'Disconnect calendar accounts.'),

    ('billing.read', 'View plan, usage and subscription information.'),
    ('billing.update', 'Update billing or subscription information.'),

    ('usage.read', 'View usage counters.'),

    ('audit.read', 'View audit logs.')
ON CONFLICT (code) DO UPDATE SET
    description = EXCLUDED.description;

-- =========================================================
-- Owner permissions: all permissions
-- =========================================================

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.business_id IS NULL
  AND r.code = 'owner'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- =========================================================
-- Worker permissions: limited operational access
-- =========================================================

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'business.read',
    'branches.read',
    'workers.read',
    'services.read',
    'schedules.read',
    'appointments.read',
    'appointments.update',
    'appointments.cancel',
    'appointments.complete',
    'appointments.no_show',
    'clients.read',
    'conversations.read',
    'conversations.reply',
    'conversations.handoff',
    'messages.read',
    'messages.create',
    'notifications.read',
    'notifications.update',
    'notification_preferences.update'
)
WHERE r.business_id IS NULL
  AND r.code = 'worker'
ON CONFLICT (role_id, permission_id) DO NOTHING;

COMMIT;
