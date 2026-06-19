const express = require('express');
const router = express.Router();
const { GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const pool = require('../config/db');
const s3 = require('../config/s3');
const auth = require('../middleware/auth');
const BUCKET = process.env.S3_BUCKET_NAME;

router.get('/', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    const { rows } = await pool.query(
      `SELECT p.*, pl.saved_at, u.username, u.display_name, g.name AS group_name FROM personal_library pl JOIN photos p ON p.id = pl.photo_id JOIN users u ON u.id = p.user_id JOIN groups g ON g.id = p.group_id WHERE pl.user_id = $1 ORDER BY pl.saved_at DESC`,      [req.user.id]
    );
    const withUrls = await Promise.all(rows.map(async (photo) => {
      const url = await getSignedUrl(s3, new GetObjectCommand({ Bucket: BUCKET, Key: photo.s3_key }), { expiresIn: 3600 });
      return { ...photo, url };
    }));
    res.json({ photos: withUrls });
  } catch (err) { next(err); }
});

router.delete('/:photoId', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  try {
    await pool.query('DELETE FROM personal_library WHERE user_id = $1 AND photo_id = $2', [req.user.id, req.params.photoId]);
    res.json({ removed: true });
  } catch (err) { next(err); }
});

module.exports = router;
