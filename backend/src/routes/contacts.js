const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const auth = require('../middleware/auth');

// Save hashed phone number for current user
router.patch('/phone', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { phoneHash } = req.body;
  if (!phoneHash) return res.status(400).json({ error: 'phoneHash is required' });
  try {
    await pool.query(
      'UPDATE users SET phone_hash = $1 WHERE id = $2',
      [phoneHash, req.user.id]
    );
    res.json({ saved: true });
  } catch (err) { next(err); }
});

// Match hashed contacts against users in DB
router.post('/match', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { hashes } = req.body;
  if (!Array.isArray(hashes) || hashes.length === 0) return res.status(400).json({ error: 'hashes array is required' });
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.username, u.display_name, u.avatar_url
       FROM users u
       WHERE u.phone_hash = ANY($1::text[])
       AND u.id != $2
       AND u.id NOT IN (
         SELECT blocked_id FROM blocks WHERE blocker_id = $3
         UNION
         SELECT blocker_id FROM blocks WHERE blocked_id = $3
       )`,
      [hashes, req.user.id, req.user.id]
    );
    res.json({ matches: rows });
  } catch (err) { next(err); }
});

module.exports = router;