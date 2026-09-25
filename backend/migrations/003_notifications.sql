ALTER TABLE notifications ADD COLUMN IF NOT EXISTS related_entity_type TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS related_entity_id UUID;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS notifications_unread_idx ON notifications(user_id, is_read, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS notifications_event_uidx ON notifications(user_id, type, related_entity_type, related_entity_id) WHERE related_entity_id IS NOT NULL;
