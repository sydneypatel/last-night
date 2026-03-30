CREATE TABLE photos (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- S3 object keys (not full URLs — we generate presigned URLs at request time)
  s3_key          TEXT NOT NULL UNIQUE,      -- full resolution, private until unlocked
  thumbnail_key   TEXT NOT NULL UNIQUE,      -- blurred low-res, always readable for placeholder

  locked          BOOLEAN NOT NULL DEFAULT TRUE,
  captured_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  unlocked_at     TIMESTAMPTZ,               -- set by the unlock Lambda

  -- Flexible metadata: filter params, EXIF, dimensions, etc.
  -- e.g. { "filter": "digicam_warm", "width": 3024, "height": 4032, "exif": {...} }
  metadata        JSONB NOT NULL DEFAULT '{}'::JSONB,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Fetch all photos for a group (most common query — ordered by capture time)
CREATE INDEX idx_photos_group_id_captured ON photos (group_id, captured_at DESC);

-- Fetch photos by a specific user in a group
CREATE INDEX idx_photos_user_group ON photos (user_id, group_id);

-- Lambda queries: find all locked photos for groups that should unlock now
CREATE INDEX idx_photos_locked ON photos (locked) WHERE locked = TRUE;
