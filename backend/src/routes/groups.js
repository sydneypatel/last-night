const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const auth = require('../middleware/auth');
const admin = require('../config/firebaseAdmin');

// --- Timezone helpers (numeric, environment-independent) ---

function getTzParts(timeZone, date) {
  const dtf = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
    hour12: false,
  });
  const map = {};
  dtf.formatToParts(date).forEach(p => { map[p.type] = p.value; });
  if (map.hour === '24') map.hour = '00';
  return map;
}

function getOffsetMs(timeZone, date) {
  const m = getTzParts(timeZone, date);
  const asUTC = Date.UTC(+m.year, +m.month - 1, +m.day, +m.hour, +m.minute, +m.second);
  return asUTC - date.getTime();
}

// Convert a wall-clock time in timeZone to the correct UTC instant.
// Single offset application — exact for any non-DST-transition time.
function zonedWallClockToUtc(year, month, day, hour, minute, timeZone) {
  const guess = Date.UTC(year, month - 1, day, hour, minute, 0);
  const offset = getOffsetMs(timeZone, new Date(guess));
  return new Date(guess - offset);
}

function getNextSunrise(timezone) {
  const today = getTzParts(timezone, new Date());
  const base = new Date(Date.UTC(+today.year, +today.month - 1, +today.day));
  base.setUTCDate(base.getUTCDate() + 1);
  return zonedWallClockToUtc(base.getUTCFullYear(), base.getUTCMonth() + 1, base.getUTCDate(), 6, 30, timezone);
}

function getNextSundayNight(timezone) {
  const today = getTzParts(timezone, new Date());
  const base = new Date(Date.UTC(+today.year, +today.month - 1, +today.day));
  const weekday = base.getUTCDay();
  const daysUntilSunday = (7 - weekday) % 7 || 7;
  base.setUTCDate(base.getUTCDate() + daysUntilSunday);
  return zonedWallClockToUtc(base.getUTCFullYear(), base.getUTCMonth() + 1, base.getUTCDate(), 23, 59, timezone);
}

async function sendFCM(tokens, title, body, data = {}) {
  if (!tokens || tokens.length === 0) return;
  const stringData = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v)])
  );
  try {
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: stringData,
    });
    console.log(`FCM: ${response.successCount} sent, ${response.failureCount} failed`);
  } catch (err) {
    console.error('FCM error (non-fatal):', err);
  }
}

router.get('/', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  console.log(`[GROUPS] request from user: ${req.user.id} (${req.user.username})`);  
  try {
    const { rows } = await pool.query(
      `SELECT g.*, gm.role, gm.joined_at,
              COUNT(DISTINCT gm2.user_id) AS member_count,
              COUNT(DISTINCT p.id) AS photo_count
       FROM groups g
       JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = $1
       JOIN group_members gm2 ON gm2.group_id = g.id
       LEFT JOIN photos p ON p.group_id = g.id
       WHERE g.is_active = TRUE
       GROUP BY g.id, gm.role, gm.joined_at
       ORDER BY g.created_at DESC`,
      [req.user.id]
    );
    console.log(`[GROUPS] returning ${rows.length} groups for ${req.user.username}`); 

    res.json({ groups: rows });
  } catch (err) {
    console.error('[GROUPS] error:', err.message);
    next(err);
  }
});

router.post('/', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { name, unlockMode = 'sunrise', unlockAt, timezone = req.user.timezone } = req.body;
  if (!name) return res.status(400).json({ error: 'name is required' });
  const validModes = ['sunrise', 'custom', 'sunday_night'];
  if (!validModes.includes(unlockMode)) return res.status(400).json({ error: 'invalid unlockMode' });
  if (unlockMode === 'custom' && !unlockAt) return res.status(400).json({ error: 'unlockAt is required for custom mode' });

  let resolvedUnlockAt = unlockAt || null;
  if (unlockMode === 'sunrise') {
    resolvedUnlockAt = getNextSunrise(timezone);
  } else if (unlockMode === 'sunday_night') {
    resolvedUnlockAt = getNextSundayNight(timezone);
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows: groupRows } = await client.query(
      `INSERT INTO groups (name, created_by, unlock_mode, unlock_at, timezone) VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [name, req.user.id, unlockMode, resolvedUnlockAt, timezone]
    );
    const group = groupRows[0];
    await client.query(
      `INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'owner')`,
      [group.id, req.user.id]
    );
    await client.query('COMMIT');
    group.role = 'owner';
    res.status(201).json({ group });
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

router.get('/by-code/:code', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows: groupRows } = await pool.query(
      'SELECT * FROM groups WHERE invite_code = $1 AND is_active = TRUE',
      [req.params.code.toUpperCase()]
    );
    if (groupRows.length === 0) return res.status(404).json({ error: 'Invalid invite code' });
    const group = groupRows[0];
    const { rows: memberRows } = await pool.query(
      'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
      [group.id, req.user.id]
    );
    const isMember = memberRows.length > 0;
    if (isMember) group.role = memberRows[0].role;
    res.json({ group, isMember });
  } catch (err) { next(err); }
});

router.get('/:id', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows: memberCheck } = await pool.query(
      'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (memberCheck.length === 0) return res.status(403).json({ error: 'Not a member' });
    const { rows: groupRows } = await pool.query('SELECT * FROM groups WHERE id = $1', [req.params.id]);
    if (groupRows.length === 0) return res.status(404).json({ error: 'Group not found' });
    const group = groupRows[0];
    group.role = memberCheck[0].role;
    const { rows: members } = await pool.query(
      `SELECT u.id, u.username, u.display_name, u.avatar_url, gm.role, gm.joined_at
      FROM group_members gm
      JOIN users u ON u.id = gm.user_id
      WHERE gm.group_id = $1
        AND u.id NOT IN (
          SELECT blocked_id FROM blocks WHERE blocker_id = $2
          UNION
          SELECT blocker_id FROM blocks WHERE blocked_id = $2
        )
      ORDER BY gm.joined_at ASC`,
      [req.params.id, req.user.id]
    );
    res.json({ group, members });
  } catch (err) { next(err); }
});

router.post('/join', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { inviteCode } = req.body;
  if (!inviteCode) return res.status(400).json({ error: 'inviteCode is required' });
  try {
    const { rows: groupRows } = await pool.query(
      'SELECT * FROM groups WHERE invite_code = $1 AND is_active = TRUE',
      [inviteCode.toUpperCase()]
    );
    if (groupRows.length === 0) return res.status(404).json({ error: 'Invalid invite code' });
    const group = groupRows[0];
    const { rows: existing } = await pool.query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [group.id, req.user.id]
    );
    if (existing.length > 0) return res.status(409).json({ error: 'Already a member' });
    await pool.query(
      `INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'member')`,
      [group.id, req.user.id]
    );

    try {
      const { rows: ownerTokens } = await pool.query(
        `SELECT dt.token FROM device_tokens dt
         JOIN group_members gm ON gm.user_id = dt.user_id
         WHERE gm.group_id = $1 AND gm.role = 'owner'`,
        [group.id]
      );
      const tokens = ownerTokens.map(r => r.token);
      await sendFCM(
        tokens,
        group.name,
        `${req.user.display_name} joined your group`,
        { type: 'member_joined', groupId: group.id }
      );
    } catch (pushErr) {
      console.error('Push notification failed (non-fatal):', pushErr);
    }

    group.role = 'member';
    res.status(201).json({ group });
  } catch (err) { next(err); }
});

router.delete('/:id/leave', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows } = await pool.query(
      'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Not a member' });
    if (rows[0].role === 'owner') return res.status(400).json({ error: 'Owners cannot leave' });
    await pool.query(
      'DELETE FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    res.json({ message: 'Left group successfully' });
  } catch (err) { next(err); }
});

router.delete('/:id', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows } = await pool.query(
      'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Not a member' });
    if (rows[0].role === 'owner') {
      await pool.query('DELETE FROM groups WHERE id = $1', [req.params.id]);
    } else {
      await pool.query(
        'DELETE FROM group_members WHERE group_id = $1 AND user_id = $2',
        [req.params.id, req.user.id]
      );
    }
    res.json({ deleted: true });
  } catch (err) { next(err); }
});

router.post('/:id/cover-upload-url', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows } = await pool.query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (rows.length === 0) return res.status(403).json({ error: 'Not a member' });

    const { PutObjectCommand } = require('@aws-sdk/client-s3');
    const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
    const s3 = require('../config/s3');
    const { v4: uuidv4 } = require('uuid');

    const key = `covers/${req.params.id}/${uuidv4()}.jpg`;
    const uploadUrl = await getSignedUrl(
      s3,
      new PutObjectCommand({
        Bucket: process.env.S3_BUCKET_NAME,
        Key: key,
        ContentType: 'image/jpeg',
      }),
      { expiresIn: 300 }
    );

    res.json({ uploadUrl, key });
  } catch (err) { next(err); }
});

router.patch('/:id/cover', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { coverUrl } = req.body;
  if (!coverUrl) return res.status(400).json({ error: 'coverUrl is required' });
  try {
    const { rows: memberRows } = await pool.query(
      'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (memberRows.length === 0) return res.status(403).json({ error: 'Not a member' });

    const { rows } = await pool.query(
      'UPDATE groups SET cover_photo_url = $1 WHERE id = $2 RETURNING *',
      [coverUrl, req.params.id]
    );
    res.json({ group: rows[0] });
  } catch (err) { next(err); }
});

router.patch('/:id/name', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { name } = req.body;
  if (!name || !name.trim()) return res.status(400).json({ error: 'name is required' });
  try {
    const { rows } = await pool.query(
      'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (rows.length === 0) return res.status(403).json({ error: 'Not a member' });
    const { rows: updated } = await pool.query(
      'UPDATE groups SET name = $1 WHERE id = $2 RETURNING *',
      [name.trim(), req.params.id]
    );
    res.json({ group: updated[0] });
  } catch (err) { next(err); }
});

router.patch('/:id/unlock', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { unlockMode, unlockAt, timezone = req.user.timezone } = req.body;
  const validModes = ['sunrise', 'custom', 'sunday_night'];
  if (!validModes.includes(unlockMode)) return res.status(400).json({ error: 'invalid unlockMode' });
  if (unlockMode === 'custom' && !unlockAt) return res.status(400).json({ error: 'unlockAt is required for custom mode' });
  try {
    const { rows } = await pool.query(
      'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (rows.length === 0) return res.status(403).json({ error: 'Not a member' });
    if (rows[0].role !== 'owner') return res.status(403).json({ error: 'Only owners can change the unlock time' });

    let resolvedUnlockAt = unlockAt || null;
    if (unlockMode === 'sunrise') {
      resolvedUnlockAt = getNextSunrise(timezone);
    } else if (unlockMode === 'sunday_night') {
      resolvedUnlockAt = getNextSundayNight(timezone);
    }

    const { rows: updated } = await pool.query(
      'UPDATE groups SET unlock_mode = $1, unlock_at = $2 WHERE id = $3 RETURNING *',
      [unlockMode, resolvedUnlockAt, req.params.id]
    );
    const updatedGroup = updated[0];
    updatedGroup.role = rows[0].role;
    res.json({ group: updatedGroup });
  } catch (err) { next(err); }
});

router.post('/:id/add-member', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { userId } = req.body;
  if (!userId) return res.status(400).json({ error: 'userId is required' });
  try {
    // The person adding must be a member of the group
    const { rows: adderRows } = await pool.query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (adderRows.length === 0) return res.status(403).json({ error: 'Not a member' });

    // Group must exist and be active
    const { rows: groupRows } = await pool.query(
      'SELECT * FROM groups WHERE id = $1 AND is_active = TRUE',
      [req.params.id]
    );
    if (groupRows.length === 0) return res.status(404).json({ error: 'Group not found' });
    const group = groupRows[0];

    // Target user must exist
    const { rows: targetRows } = await pool.query('SELECT 1 FROM users WHERE id = $1', [userId]);
    if (targetRows.length === 0) return res.status(404).json({ error: 'User not found' });

    // Already a member?
    const { rows: existing } = await pool.query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.id, userId]
    );
    if (existing.length > 0) return res.status(409).json({ error: 'Already a member' });

    // Add them
    await pool.query(
      `INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'member')`,
      [req.params.id, userId]
    );

    // Notify the added user
    try {
      const { rows: tokenRows } = await pool.query(
        'SELECT token FROM device_tokens WHERE user_id = $1',
        [userId]
      );
      const tokens = tokenRows.map(r => r.token);
      await sendFCM(
        tokens,
        group.name,
        `${req.user.display_name} added you to their group`,
        { type: 'added_to_group', groupId: group.id }
      );
    } catch (pushErr) {
      console.error('Add-member push failed (non-fatal):', pushErr);
    }

    res.status(201).json({ added: true });
  } catch (err) { next(err); }
});

module.exports = router;
