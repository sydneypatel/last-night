const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const auth = require('../middleware/auth');
const admin = require('../config/firebaseAdmin');

async function sendFCM(tokens, title, body, data = {}) {
  if (!tokens || tokens.length === 0) return;
  const stringData = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v)])
  );
  try {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: stringData,
    });
  } catch (err) {
    console.error('FCM error (non-fatal):', err);
  }
}

router.get('/me', auth, async (req, res) => {
  if (!req.user) return res.status(404).json({ error: 'User not found' });
  res.json({ user: req.user });
});

router.get('/search', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { q } = req.query;
  if (!q || q.length < 2) return res.status(400).json({ error: 'Query must be at least 2 characters' });
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.username, u.display_name, u.avatar_url,
              EXISTS(SELECT 1 FROM follows f WHERE f.follower_id = $2 AND f.following_id = u.id) AS is_following
       FROM users u
       WHERE (LOWER(u.username) LIKE $1 OR LOWER(u.display_name) LIKE $1) AND u.id != $2
       ORDER BY
         CASE WHEN LOWER(u.username) LIKE $1 THEN 0 ELSE 1 END,
         u.username
       LIMIT 20`,
      [`${q.toLowerCase()}%`, req.user.id]
    );
    res.json({ users: rows });
  } catch (err) { next(err); }
});

router.get('/:username', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.username, u.display_name, u.avatar_url, u.bio, u.created_at,
              (SELECT COUNT(*) FROM follows WHERE following_id = u.id) AS follower_count,
              (SELECT COUNT(*) FROM follows WHERE follower_id = u.id) AS following_count,
              EXISTS(SELECT 1 FROM follows f WHERE f.follower_id = $2 AND f.following_id = u.id) AS is_following
       FROM users u
       WHERE LOWER(u.username) = $1`,
      [req.params.username.toLowerCase(), req.user?.id || null]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ user: rows[0] });
  } catch (err) { next(err); }
});

router.post('/:id/follow', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const targetId = req.params.id;
  if (targetId === req.user.id) return res.status(400).json({ error: 'Cannot follow yourself' });
  try {
    const { rows: targetCheck } = await pool.query('SELECT 1 FROM users WHERE id = $1', [targetId]);
    if (targetCheck.length === 0) return res.status(404).json({ error: 'User not found' });

    await pool.query(
      `INSERT INTO follows (follower_id, following_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [req.user.id, targetId]
    );

    // Notify the person being followed
    try {
      const { rows: tokenRows } = await pool.query(
        'SELECT token FROM device_tokens WHERE user_id = $1',
        [targetId]
      );
      const tokens = tokenRows.map(r => r.token);
      await sendFCM(
        tokens,
        'new follower',
        `${req.user.display_name} started following you`,
        { type: 'new_follower', userId: req.user.id }
      );
    } catch (pushErr) {
      console.error('Follow push failed (non-fatal):', pushErr);
    }

    res.status(201).json({ following: true });
  } catch (err) { next(err); }
});

router.delete('/:id/follow', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    await pool.query(
      'DELETE FROM follows WHERE follower_id = $1 AND following_id = $2',
      [req.user.id, req.params.id]
    );
    res.json({ following: false });
  } catch (err) { next(err); }
});

router.get('/:id/followers', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.username, u.display_name, u.avatar_url
       FROM follows f
       JOIN users u ON u.id = f.follower_id
       WHERE f.following_id = $1
       ORDER BY f.created_at DESC`,
      [req.params.id]
    );
    res.json({ users: rows });
  } catch (err) { next(err); }
});

router.get('/:id/following', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.username, u.display_name, u.avatar_url
       FROM follows f
       JOIN users u ON u.id = f.following_id
       WHERE f.follower_id = $1
       ORDER BY f.created_at DESC`,
      [req.params.id]
    );
    res.json({ users: rows });
  } catch (err) { next(err); }
});

router.get('/by-id/:id', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, username, display_name, avatar_url, bio FROM users WHERE id = $1',
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ user: rows[0] });
  } catch (err) { next(err); }
});

module.exports = router;
