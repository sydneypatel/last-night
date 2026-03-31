const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const auth = require('../middleware/auth');

router.post('/register', auth, async (req, res, next) => {
  try {
    if (req.user) return res.json({ user: req.user });
    const { username, displayName, timezone = 'America/New_York' } = req.body;
    if (!username || !displayName) return res.status(400).json({ error: 'username and displayName are required' });
    if (!/^[a-zA-Z0-9_]{3,20}$/.test(username)) return res.status(400).json({ error: 'Username must be 3-20 characters, letters, numbers, and underscores only' });
    const { rows } = await pool.query(
      `INSERT INTO users (firebase_uid, username, display_name, timezone) VALUES ($1, $2, $3, $4) RETURNING *`,
      [req.firebaseUid, username.toLowerCase(), displayName, timezone]
    );
    res.status(201).json({ user: rows[0] });
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Username already taken' });
    next(err);
  }
});

router.post('/sync', auth, async (req, res) => {
  if (!req.user) return res.status(404).json({ error: 'User not found' });
  res.json({ user: req.user });
});

router.patch('/profile', auth, async (req, res, next) => {
  if (!req.user) return res.status(404).json({ error: 'User not found' });
  try {
    const { displayName, avatarUrl, timezone, bio } = req.body;
    const { rows } = await pool.query(
      `UPDATE users SET display_name = COALESCE($1, display_name), avatar_url = COALESCE($2, avatar_url), timezone = COALESCE($3, timezone), bio = COALESCE($4, bio) WHERE id = $5 RETURNING *`,
      [displayName, avatarUrl, timezone, bio, req.user.id]
    );
    res.json({ user: rows[0] });
  } catch (err) { next(err); }
});

router.delete('/account', auth, async (req, res, next) => {
  if (!req.user) return res.status(404).json({ error: 'User not found' });
  try {
    // Delete from our DB
    await pool.query('DELETE FROM users WHERE id = $1', [req.user.id]);
    // Also delete from Firebase Auth
    const admin = require('../config/firebase');
    await admin.auth().deleteUser(req.firebaseUid);
    res.json({ deleted: true });
  } catch (err) { next(err); }
});

module.exports = router;
