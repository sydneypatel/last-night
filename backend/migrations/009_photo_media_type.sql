CREATE TYPE media_type AS ENUM ('photo', 'video');

ALTER TABLE photos
  ADD COLUMN media_type media_type NOT NULL DEFAULT 'photo',
  ADD COLUMN duration_seconds NUMERIC(4,1);