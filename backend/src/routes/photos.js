const express = require('express');
const router = express.Router();
const { PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { v4: uuidv4 } = require('uuid');
const pool = require('../config/db');
const s3 = require('../config/s3');
const auth = require('../middleware/auth');
const BUCKET = process.env.S3_BUCKET_NAME;
const CLOUDFRONT = process.env.CLOUDFRONT_DOMAIN;

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
    const isVideo = contentType === 'video/quicktime' || contentType === 'video/mp4';
    const ext = isVideo ? 'mov' : 'jpg';
    const s3Key = `photos/${groupId}/${req.user.id}/${photoId}.${ext}`;
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
  const { groupId, s3Key, thumbnailKey, metadata = {}, mediaType = 'photo', durationSeconds } = req.body;
  if (!groupId || !s3Key || !thumbnailKey) return res.status(400).json({ error: 'groupId, s3Key, and thumbnailKey are required' });
  try {
    const { rows: groupRows } = await pool.query(
      'SELECT unlock_at FROM groups WHERE id = $1',
      [groupId]
    );
    const group = groupRows[0];
    const alreadyUnlocked = group?.unlock_at && new Date(group.unlock_at) <= new Date();

    const { rows } = await pool.query(
      `INSERT INTO photos (group_id, user_id, s3_key, thumbnail_key, metadata, locked, unlocked_at, media_type, duration_seconds)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [groupId, req.user.id, s3Key, thumbnailKey, JSON.stringify(metadata),
       alreadyUnlocked ? false : true,
       alreadyUnlocked ? new Date() : null,
       mediaType,
       durationSeconds || null]
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
         AND p.user_id NOT IN (
           SELECT blocked_id FROM blocks WHERE blocker_id = $2
           UNION
           SELECT blocker_id FROM blocks WHERE blocked_id = $2
         )
       ORDER BY p.captured_at DESC`,
      [req.params.groupId, req.user.id]
    );
    const photosWithUrls = await Promise.all(
      photos.map(async (photo) => {
        let url;
        if (photo.locked) {
          url = await getSignedUrl(
            s3,
            new GetObjectCommand({ Bucket: BUCKET, Key: photo.thumbnail_key }),
            { expiresIn: 3600 }
          );
        } else {
          url = CLOUDFRONT
            ? `${CLOUDFRONT}/${photo.s3_key}`
            : await getSignedUrl(s3, new GetObjectCommand({ Bucket: BUCKET, Key: photo.s3_key }), { expiresIn: 3600 });
        }

        const thumbnailUrl = CLOUDFRONT
          ? `${CLOUDFRONT}/${photo.thumbnail_key}`
          : await getSignedUrl(s3, new GetObjectCommand({ Bucket: BUCKET, Key: photo.thumbnail_key }), { expiresIn: 3600 });

        return { ...photo, url, thumbnailUrl, s3_key: photo.locked ? null : photo.s3_key };
      })
    );
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

router.delete('/:id', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows } = await pool.query(
      'SELECT * FROM photos WHERE id = $1',
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Photo not found' });
    if (rows[0].user_id !== req.user.id) return res.status(403).json({ error: 'Not your photo' });

    // Delete from S3
    const { DeleteObjectCommand } = require('@aws-sdk/client-s3');
    await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: rows[0].s3_key }));
    if (rows[0].thumbnail_key) {
      await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: rows[0].thumbnail_key }));
    }

    // Delete from DB
    await pool.query('DELETE FROM photos WHERE id = $1', [req.params.id]);
    res.json({ deleted: true });
  } catch (err) { next(err); }
});

router.post('/:id/rotate-url', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows } = await pool.query('SELECT * FROM photos WHERE id = $1', [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Photo not found' });
    const photo = rows[0];
    if (photo.user_id !== req.user.id) return res.status(403).json({ error: 'Not your photo' });
    if (photo.locked) return res.status(403).json({ error: 'Photo is locked' });

    const uploadUrl = await getSignedUrl(
      s3,
      new PutObjectCommand({ Bucket: BUCKET, Key: photo.s3_key, ContentType: 'image/jpeg' }),
      { expiresIn: 300 }
    );
    res.json({ uploadUrl, s3Key: photo.s3_key });
  } catch (err) { next(err); }
});

module.exports = router;
