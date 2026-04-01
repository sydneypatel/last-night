CREATE TABLE featured_photos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  photo_id    UUID REFERENCES photos(id) ON DELETE SET NULL,
  position    INTEGER NOT NULL CHECK (position >= 1 AND position <= 9),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT unique_user_position UNIQUE (user_id, position),
  CONSTRAINT unique_user_photo UNIQUE (user_id, photo_id)
);

CREATE INDEX idx_featured_photos_user ON featured_photos (user_id, position);