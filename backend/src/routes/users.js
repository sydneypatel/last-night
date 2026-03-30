const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const auth = require('../middleware/auth');

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
      `SELECT id, username, display_name, avatar_url FROM users WHERE LOWER(username) LIKE $1 AND id != $2 LIMIT 20`,
      [`${q.toLowerCase()}%`, req.user.id]
    );
    res.json({ users: rows });
  } catch (err) { next(err); }
});

router.get('/:username', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, username, display_name, avatar_url, bio, created_at FROM users WHERE LOWER(username) = $1`,
      [req.params.username.toLowerCase()]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ user: rows[0] });
  } catch (err) { next(err); }
});

module.exports = router;
