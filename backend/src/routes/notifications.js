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

module.exports = router;
