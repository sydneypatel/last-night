const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const auth = require('../middleware/auth');

// Block a user (also removes any follow relationship both ways)
router.post('/:id', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const blockedId = req.params.id;
  if (blockedId === req.user.id) return res.status(400).json({ error: 'Cannot block yourself' });
  try {
    const { rows: target } = await pool.query('SELECT 1 FROM users WHERE id = $1', [blockedId]);
    if (target.length === 0) return res.status(404).json({ error: 'User not found' });

    await pool.query(
      `INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [req.user.id, blockedId]
    );
    // Remove follows in both directions
    await pool.query(
      `DELETE FROM follows
       WHERE (follower_id = $1 AND following_id = $2)
          OR (follower_id = $2 AND following_id = $1)`,
      [req.user.id, blockedId]
    );
    res.status(201).json({ blocked: true });
  } catch (err) { next(err); }
});

// Unblock a user
router.delete('/:id', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    await pool.query(
      'DELETE FROM blocks WHERE blocker_id = $1 AND blocked_id = $2',
      [req.user.id, req.params.id]
    );
    res.json({ unblocked: true });
  } catch (err) { next(err); }
});

// List users I've blocked (for the "blocked users" settings screen)
router.get('/', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.username, u.display_name, u.avatar_url
       FROM blocks b JOIN users u ON u.id = b.blocked_id
       WHERE b.blocker_id = $1
       ORDER BY b.created_at DESC`,
      [req.user.id]
    );
    res.json({ users: rows });
  } catch (err) { next(err); }
});

module.exports = router;