CREATE TABLE live_activity_tokens (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  group_id        UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  token           TEXT NOT NULL UNIQUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Fast lookup of all tokens for a given group (used when ending activities at unlock time)
CREATE INDEX idx_live_activity_tokens_group_id ON live_activity_tokens (group_id);

CREATE TRIGGER live_activity_tokens_updated_at
  BEFORE UPDATE ON live_activity_tokens
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();