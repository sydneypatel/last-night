const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const auth = require('../middleware/auth');

function getNextSunrise(timezone) {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowStr = tomorrow.toLocaleDateString('en-US', { timeZone: timezone });
  return new Date(tomorrowStr + ' 06:30:00');
}

function getNextSundayNight(timezone) {
  const now = new Date();
  const daysUntilSunday = (7 - now.getDay()) % 7 || 7;
  const nextSunday = new Date(now);
  nextSunday.setDate(now.getDate() + daysUntilSunday);
  const sundayStr = nextSunday.toLocaleDateString('en-US', { timeZone: timezone });
  return new Date(sundayStr + ' 23:59:00');
}

router.get('/', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
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
    res.json({ groups: rows });
  } catch (err) { next(err); }
});

router.post('/', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { name, unlockMode = 'sunrise', unlockAt, timezone = req.user.timezone } = req.body;
  if (!name) return res.status(400).json({ error: 'name is required' });
  const validModes = ['sunrise', 'custom', 'sunday_night'];
  if (!validModes.includes(unlockMode)) return res.status(400).json({ error: 'invalid unlockMode' });
  if (unlockMode === 'custom' && !unlockAt) return res.status(400).json({ error: 'unlockAt is required for custom mode' });

  // Calculate unlock time based on mode
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
    res.status(201).json({ group });
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

router.get('/:id', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows: memberCheck } = await pool.query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (memberCheck.length === 0) return res.status(403).json({ error: 'Not a member' });
    const { rows: groupRows } = await pool.query('SELECT * FROM groups WHERE id = $1', [req.params.id]);
    if (groupRows.length === 0) return res.status(404).json({ error: 'Group not found' });
    const { rows: members } = await pool.query(
      `SELECT u.id, u.username, u.display_name, u.avatar_url, gm.role, gm.joined_at
       FROM group_members gm
       JOIN users u ON u.id = gm.user_id
       WHERE gm.group_id = $1
       ORDER BY gm.joined_at ASC`,
      [req.params.id]
    );
    res.json({ group: groupRows[0], members });
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

module.exports = router;