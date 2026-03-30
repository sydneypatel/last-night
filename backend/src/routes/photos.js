const express = require('express');
const router = express.Router();
const { PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { v4: uuidv4 } = require('uuid');
const pool = require('../config/db');
const s3 = require('../config/s3');
const auth = require('../middleware/auth');
const BUCKET = process.env.S3_BUCKET_NAME;

router.post('/upload-url', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { groupId, contentType = 'image/jpeg' } = req.body;
  if (!groupId) return res.status(400).json({ error: 'groupId is required' });
  try {
    const { rows } = await pool.query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, req.user.id]
    );
    if (rows.length === 0) return res.status(403).json({ error: 'Not a member' });
    const photoId = uuidv4();
    const s3Key = `photos/${groupId}/${req.user.id}/${photoId}.jpg`;
    const thumbnailKey = `thumbnails/${groupId}/${req.user.id}/${photoId}.jpg`;
    const uploadUrl = await getSignedUrl(
      s3,
      new PutObjectCommand({ Bucket: BUCKET, Key: s3Key, ContentType: contentType }),
      { expiresIn: 300 }
    );
    res.json({ uploadUrl, photoId, s3Key, thumbnailKey });
  } catch (err) { next(err); }
});

router.post('/confirm', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { groupId, s3Key, thumbnailKey, metadata = {} } = req.body;
  if (!groupId || !s3Key || !thumbnailKey) return res.status(400).json({ error: 'groupId, s3Key, and thumbnailKey are required' });
  try {
    const { rows } = await pool.query(
      `INSERT INTO photos (group_id, user_id, s3_key, thumbnail_key, metadata) VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [groupId, req.user.id, s3Key, thumbnailKey, JSON.stringify(metadata)]
    );
    res.status(201).json({ photo: rows[0] });
  } catch (err) { next(err); }
});

router.get('/group/:groupId', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows: memberCheck } = await pool.query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [req.params.groupId, req.user.id]
    );
    if (memberCheck.length === 0) return res.status(403).json({ error: 'Not a member' });
    const { rows: photos } = await pool.query(
      `SELECT p.*, u.username, u.display_name, u.avatar_url
       FROM photos p
       JOIN users u ON u.id = p.user_id
       WHERE p.group_id = $1
       ORDER BY p.captured_at DESC`,
      [req.params.groupId]
    );
    const photosWithUrls = await Promise.all(photos.map(async (photo) => {
      const keyToServe = photo.locked ? photo.thumbnail_key : photo.s3_key;
      const url = await getSignedUrl(
        s3,
        new GetObjectCommand({ Bucket: BUCKET, Key: keyToServe }),
        { expiresIn: 3600 }
      );
      return { ...photo, url, s3_key: photo.locked ? null : photo.s3_key };
    }));
    res.json({ photos: photosWithUrls });
  } catch (err) { next(err); }
});

router.post('/:id/save', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows: photoRows } = await pool.query('SELECT * FROM photos WHERE id = $1', [req.params.id]);
    if (photoRows.length === 0) return res.status(404).json({ error: 'Photo not found' });
    if (photoRows[0].locked) return res.status(403).json({ error: 'Photo is still locked' });
    const { rows } = await pool.query(
      `INSERT INTO personal_library (user_id, photo_id) VALUES ($1, $2) ON CONFLICT (user_id, photo_id) DO NOTHING RETURNING *`,
      [req.user.id, req.params.id]
    );
    res.status(201).json({ saved: true, entry: rows[0] || null });
  } catch (err) { next(err); }
});

module.exports = router;
