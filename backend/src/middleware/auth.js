const admin = require('../config/firebase');
const pool = require('../config/db');
module.exports = async function auth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization header' });
  }
  const token = authHeader.split('Bearer ')[1];
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.firebaseUid = decoded.uid;
    req.firebaseEmail = decoded.email;
    const { rows } = await pool.query(
      'SELECT * FROM users WHERE firebase_uid = $1',
      [decoded.uid]
    );
    if (rows.length > 0) req.user = rows[0];
    next();
  } catch (err) {
    console.error('Auth error:', err.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};
