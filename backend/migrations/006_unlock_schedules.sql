CREATE TABLE unlock_schedules (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE UNIQUE,

  -- Cron expression for EventBridge rule
  -- e.g. "cron(30 12 * * ? *)" for 12:30 UTC daily (sunrise varies by season/location)
  -- For 'sunday_night' mode: "cron(59 23 ? * SUN *)"
  -- For 'custom' mode: one-time rule, active = false after firing
  cron_expr       TEXT NOT NULL,

  timezone        TEXT NOT NULL DEFAULT 'America/New_York',
  active          BOOLEAN NOT NULL DEFAULT TRUE,
  next_run_at     TIMESTAMPTZ NOT NULL,
  last_ran_at     TIMESTAMPTZ,

  -- EventBridge rule name so we can disable/update it via AWS SDK
  eventbridge_rule_name TEXT UNIQUE,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Lambda polls this to find schedules due to run
CREATE INDEX idx_unlock_schedules_next_run ON unlock_schedules (next_run_at)
  WHERE active = TRUE;

CREATE TRIGGER unlock_schedules_updated_at
  BEFORE UPDATE ON unlock_schedules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
