const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const auth = require('../middleware/auth');

router.post('/register', auth, async (req, res, next) => {
  try {
    if (req.user) return res.json({ user: req.user });
    const { username, displayName, timezone = 'America/New_York' } = req.body;
    if (!username || !displayName) return res.status(400).json({ error: 'username and displayName are required' });

    if (!/^[a-zA-Z0-9_.]{3,16}$/.test(username)) {
      return res.status(400).json({ error: 'username must be 3–16 characters: letters, numbers, _ and .' });
    }
    if (/^[._]|[._]$/.test(username)) {
      return res.status(400).json({ error: 'username can\'t start or end with . or _' });
    }

    const { rows } = await pool.query(
      `INSERT INTO users (firebase_uid, username, display_name, timezone) VALUES ($1, $2, $3, $4) RETURNING *`,
      [req.firebaseUid, username.toLowerCase(), displayName, timezone]
    );
    res.status(201).json({ user: rows[0] });
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'username already taken' });
    next(err);
  }
});

router.post('/sync', auth, async (req, res) => {
  if (!req.user) return res.status(404).json({ error: 'user not found' });
  res.json({ user: req.user });
});

router.patch('/profile', auth, async (req, res, next) => {
  if (!req.user) return res.status(404).json({ error: 'user not found' });
  try {
    const { displayName, avatarUrl, timezone, bio } = req.body;
    const { rows } = await pool.query(
      `UPDATE users SET display_name = COALESCE($1, display_name), avatar_url = COALESCE($2, avatar_url), timezone = COALESCE($3, timezone), bio = COALESCE($4, bio) WHERE id = $5 RETURNING *`,
      [displayName, avatarUrl, timezone, bio, req.user.id]
    );
    res.json({ user: rows[0] });
  } catch (err) { next(err); }
});

router.post('/avatar-upload-url', auth, async (req, res, next) => {
  if (!req.user) return res.status(404).json({ error: 'user not found' });
  try {
    const { PutObjectCommand } = require('@aws-sdk/client-s3');
    const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
    const s3 = require('../config/s3');
    const { v4: uuidv4 } = require('uuid');

    const key = `avatars/${req.user.id}/${uuidv4()}.jpg`;
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

router.delete('/account', auth, async (req, res, next) => {
  if (!req.user) return res.status(404).json({ error: 'user not found' });
  try {
    // Fetch all the user's photo S3 keys before deleting DB rows
    const { rows: photos } = await pool.query(
      'SELECT s3_key, thumbnail_key FROM photos WHERE user_id = $1',
      [req.user.id]
    );

    // Delete the user's photo files from S3
    if (photos.length > 0) {
      const { DeleteObjectCommand } = require('@aws-sdk/client-s3');
      const s3 = require('../config/s3');
      const BUCKET = process.env.S3_BUCKET_NAME;
      await Promise.all(photos.flatMap(p => {
        const deletes = [s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: p.s3_key }))];
        if (p.thumbnail_key) {
          deletes.push(s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: p.thumbnail_key })));
        }
        return deletes;
      }));
    }

    // Delete from our DB (photos, follows, group_members, etc. cascade via FKs)
    await pool.query('DELETE FROM users WHERE id = $1', [req.user.id]);

    // Also delete from Firebase Auth
    const admin = require('../config/firebase');
    await admin.auth().deleteUser(req.firebaseUid);

    res.json({ deleted: true });
  } catch (err) { next(err); }
});

module.exports = router;
