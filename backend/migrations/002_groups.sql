CREATE TYPE unlock_mode AS ENUM (
  'sunrise',       -- unlocks at local sunrise (default)
  'custom',        -- user-specified datetime
  'sunday_night'   -- unlocks Sunday at 11:59pm (weekend roll-up)
);

CREATE TABLE groups (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  cover_photo_url TEXT,
  created_by      UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  unlock_mode     unlock_mode NOT NULL DEFAULT 'sunrise',
  unlock_at       TIMESTAMPTZ,         -- set for 'custom' and 'sunday_night' modes
  timezone        TEXT NOT NULL DEFAULT 'America/New_York',
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  invite_code     TEXT UNIQUE DEFAULT UPPER(SUBSTRING(gen_random_uuid()::TEXT, 1, 6)),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Lookup active groups by creator
CREATE INDEX idx_groups_created_by ON groups (created_by);
-- Invite code lookups
CREATE INDEX idx_groups_invite_code ON groups (invite_code);

CREATE TRIGGER groups_updated_at
  BEFORE UPDATE ON groups
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
