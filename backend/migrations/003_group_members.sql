CREATE TYPE member_role AS ENUM ('owner', 'member');

CREATE TABLE group_members (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role        member_role NOT NULL DEFAULT 'member',
  joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT unique_group_member UNIQUE (group_id, user_id)
);

-- Given a user, find all their groups quickly
CREATE INDEX idx_group_members_user_id ON group_members (user_id);
-- Given a group, find all members quickly
CREATE INDEX idx_group_members_group_id ON group_members (group_id);
