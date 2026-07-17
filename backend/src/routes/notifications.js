const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const auth = require('../middleware/auth');
const admin = require('../config/firebaseAdmin');

router.post('/device-token', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { token, environment = 'fcm' } = req.body;
  if (!token) return res.status(400).json({ error: 'token is required' });
  try {
    await pool.query(
      `INSERT INTO device_tokens (user_id, token, environment)
       VALUES ($1, $2, $3)
       ON CONFLICT (token) DO UPDATE SET user_id = $1, environment = $3`,
      [req.user.id, token, environment]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

router.post('/live-activity-token', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { groupId, token } = req.body;
  if (!groupId || !token) return res.status(400).json({ error: 'groupId and token are required' });
  try {
    await pool.query(
      `INSERT INTO live_activity_tokens (user_id, group_id, token)
       VALUES ($1, $2, $3)
       ON CONFLICT (token) DO UPDATE SET user_id = $1, group_id = $2`,
      [req.user.id, groupId, token]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

router.delete('/device-token', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { token } = req.body;
  if (!token) return res.status(400).json({ error: 'token is required' });
  try {
    await pool.query(
      'DELETE FROM device_tokens WHERE token = $1 AND user_id = $2',
      [token, req.user.id]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

module.exports = router;
