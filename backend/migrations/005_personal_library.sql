CREATE TABLE personal_library (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  photo_id    UUID NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
  saved_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- A user can only save a given photo once
  CONSTRAINT unique_library_entry UNIQUE (user_id, photo_id)
);

-- Fetch a user's full personal library ordered by save time
CREATE INDEX idx_personal_library_user ON personal_library (user_id, saved_at DESC);
