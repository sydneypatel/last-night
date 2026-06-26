const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const auth = require('../middleware/auth');

// Admin user IDs — add/swap here to change who can review reports
const ADMIN_IDS = [
  '3b81c5c2-7ab3-47ab-9ab9-9dfe0c8778cf', // syd
  '927f49bc-45d2-4fd9-855b-58da1815c67c', // djpaulyd (katie)
];

function isAdmin(userId) {
  return ADMIN_IDS.includes(userId);
}

// Report a photo
router.post('/photo/:id', auth, async (req, res, next) => {
  if (!req.user) return res.status(401).json({ error: 'Not registered' });
  const { reason } = req.body;
  if (!reason) return res.status(400).json({ error: 'reason is required' });
  try {
    const { rows: photoRows } = await pool.query('SELECT 1 FROM photos WHERE id = $1', [req.params.id]);
    if (photoRows.length === 0) return res.status(404).json({ error: 'Photo not found' });

    await pool.query(
      `INSERT INTO reports (photo_id, reporter_id, reason)
       VALUES ($1, $2, $3)
       ON CONFLICT (photo_id, reporter_id) DO NOTHING`,
      [req.params.id, req.user.id, reason]
    );

    // Notify admins
    try {
      const { rows: adminTokenRows } = await pool.query(
        `SELECT token FROM device_tokens WHERE user_id = ANY($1::uuid[])`,
        [ADMIN_IDS]
      );
      const tokens = adminTokenRows.map(r => r.token);
      if (tokens.length > 0) {
        const admin = require('../config/firebaseAdmin');
        await admin.messaging().sendEachForMulticast({
          tokens,
          notification: {
            title: 'new report',
            body: `a photo was reported for: ${reason}`,
          },
          data: {
            type: 'admin_report',
            photoId: req.params.id,
          },
        });
      }
    } catch (pushErr) {
      console.error('Admin push failed (non-fatal):', pushErr);
    }
        
    res.status(201).json({ reported: true });
  } catch (err) { next(err); }
});

// Admin: list pending reports
router.get('/admin/pending', auth, async (req, res, next) => {
  if (!req.user || !isAdmin(req.user.id)) return res.status(403).json({ error: 'Not authorized' });
  try {
    const { rows } = await pool.query(
      `SELECT r.id, r.reason, r.created_at,
              r.photo_id, p.s3_key, p.group_id,
              owner.username AS photo_owner_username,
              reporter.username AS reporter_username
       FROM reports r
       JOIN photos p ON p.id = r.photo_id
       JOIN users owner ON owner.id = p.user_id
       JOIN users reporter ON reporter.id = r.reporter_id
       WHERE r.status = 'pending'
       ORDER BY r.created_at ASC`
    );
    // Attach signed/CDN URLs for the reported photos
    const { GetObjectCommand } = require('@aws-sdk/client-s3');
    const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
    const s3 = require('../config/s3');
    const CLOUDFRONT = process.env.CLOUDFRONT_DOMAIN;

    const withUrls = await Promise.all(rows.map(async (r) => {
      const url = CLOUDFRONT
        ? `${CLOUDFRONT}/${r.s3_key}`
        : await getSignedUrl(s3, new GetObjectCommand({ Bucket: process.env.S3_BUCKET_NAME, Key: r.s3_key }), { expiresIn: 3600 });
      return { ...r, url };
    }));
    res.json({ reports: withUrls });
  } catch (err) { next(err); }
});

// Admin: dismiss a report (keep photo)
router.post('/admin/:id/dismiss', auth, async (req, res, next) => {
  if (!req.user || !isAdmin(req.user.id)) return res.status(403).json({ error: 'Not authorized' });
  try {
    await pool.query(
      `UPDATE reports SET status = 'resolved', resolved_at = now() WHERE id = $1`,
      [req.params.id]
    );
    res.json({ dismissed: true });
  } catch (err) { next(err); }
});

// Admin: remove the reported photo (full delete: S3 + DB)
router.post('/admin/:id/remove', auth, async (req, res, next) => {
  if (!req.user || !isAdmin(req.user.id)) return res.status(403).json({ error: 'Not authorized' });
  try {
    const { rows } = await pool.query(
      `SELECT p.id, p.s3_key, p.thumbnail_key
       FROM reports r JOIN photos p ON p.id = r.photo_id
       WHERE r.id = $1`,
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Report or photo not found' });
    const photo = rows[0];

    // Delete from S3
    const { DeleteObjectCommand } = require('@aws-sdk/client-s3');
    const s3 = require('../config/s3');
    const BUCKET = process.env.S3_BUCKET_NAME;
    await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: photo.s3_key }));
    if (photo.thumbnail_key) {
      await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: photo.thumbnail_key }));
    }

    // Delete the photo (reports cascade-delete via FK)
    await pool.query('DELETE FROM photos WHERE id = $1', [photo.id]);
    res.json({ removed: true });
  } catch (err) { next(err); }
});

module.exports = router;