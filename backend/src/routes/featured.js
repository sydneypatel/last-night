const express = require('express');
const router = express.Router();
const { GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const pool = require('../config/db');
const s3 = require('../config/s3');
const auth = require('../middleware/auth');

const BUCKET = process.env.S3_BUCKET_NAME;
const CLOUDFRONT = process.env.CLOUDFRONT_DOMAIN;

async function attachUrl(photo) {
  if (!photo.s3_key) return { ...photo, url: null };
  const url = CLOUDFRONT
    ? `${CLOUDFRONT}/${photo.s3_key}`
    : await getSignedUrl(
        s3,
        new GetObjectCommand({ Bucket: BUCKET, Key: photo.s3_key }),
        { expiresIn: 3600 }
      );
  return { ...photo, url };
}

/**
 * GET /featured/me/library
 * Photos the user has saved to their personal library — for picking featured photos.
 * Returns saved photos regardless of who took them, as long as still unlocked.
 * MUST be before /:username to avoid route conflict
 */
router.get('/me/library', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows } = await pool.query(
      `SELECT p.*, pl.saved_at, g.name AS group_name
       FROM personal_library pl
       JOIN photos p ON p.id = pl.photo_id
       JOIN groups g ON g.id = p.group_id
       WHERE pl.user_id = $1 AND p.locked = FALSE
       ORDER BY pl.saved_at DESC`,
      [req.user.id]
    );
    const withUrls = await Promise.all(rows.map(attachUrl));
    res.json({ photos: withUrls });
  } catch (err) { next(err); }
});

/**
 * PUT /featured/me/:position
 * Set a photo in a specific slot (1-9). Send photoId: null to clear the slot.
 * Photo must be in the user's personal library and unlocked.
 * MUST be before /:username to avoid route conflict
 */
router.put('/me/:position', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });

  const position = parseInt(req.params.position);
  if (isNaN(position) || position < 1 || position > 9) {
    return res.status(400).json({ error: 'Position must be between 1 and 9' });
  }

  const { photoId } = req.body;

  try {
    if (!photoId) {
      await pool.query(
        'DELETE FROM featured_photos WHERE user_id = $1 AND position = $2',
        [req.user.id, position]
      );
      return res.json({ position, photo: null });
    }

    const { rows: photoRows } = await pool.query(
      `SELECT p.id
       FROM personal_library pl
       JOIN photos p ON p.id = pl.photo_id
       WHERE pl.user_id = $1 AND pl.photo_id = $2 AND p.locked = FALSE`,
      [req.user.id, photoId]
    );
    if (photoRows.length === 0) {
      return res.status(403).json({ error: 'Photo not in your library or still locked' });
    }

    const { rows } = await pool.query(
      `INSERT INTO featured_photos (user_id, photo_id, position)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, position) DO UPDATE SET photo_id = $2
       RETURNING *`,
      [req.user.id, photoId, position]
    );

    res.json({ position, featured: rows[0] });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Photo already featured in another slot' });
    }
    next(err);
  }
});

/**
 * GET /featured/:username
 * Get a user's featured 3x3 grid (public)
 * MUST be after /me routes
 */
router.get('/:username', auth, async (req, res, next) => {
  try {
    const { rows: userRows } = await pool.query(
      'SELECT id FROM users WHERE LOWER(username) = $1',
      [req.params.username.toLowerCase()]
    );
    if (userRows.length === 0) return res.status(404).json({ error: 'User not found' });
    const userId = userRows[0].id;

    const { rows } = await pool.query(
      `SELECT fp.position, p.id, p.s3_key, p.locked, p.captured_at
       FROM featured_photos fp
       LEFT JOIN photos p ON p.id = fp.photo_id
       WHERE fp.user_id = $1
       ORDER BY fp.position ASC`,
      [userId]
    );

    const grid = Array.from({ length: 9 }, (_, i) => {
      const slot = rows.find(r => r.position === i + 1);
      return { position: i + 1, photo: slot?.id ? slot : null };
    });

    const gridWithUrls = await Promise.all(
      grid.map(async (slot) => {
        if (!slot.photo || slot.photo.locked) return slot;
        const withUrl = await attachUrl(slot.photo);
        return { ...slot, photo: withUrl };
      })
    );

    res.json({ grid: gridWithUrls });
  } catch (err) { next(err); }
});

module.exports = router;
