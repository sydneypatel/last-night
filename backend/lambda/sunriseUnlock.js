const { Pool } = require('pg');
const fetch = require('node-fetch');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  max: 2,
});

async function getApnsToken() {
  const keyContent = process.env.APNS_KEY_CONTENT.replace(/\\n/g, '\n');

  const pemBody = keyContent
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const keyBuffer = Buffer.from(pemBody, 'base64');

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBuffer,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  );

  const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: process.env.APNS_KEY_ID })).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const payload = Buffer.from(JSON.stringify({ iss: process.env.APNS_TEAM_ID, iat: now })).toString('base64url');
  const signingInput = `${header}.${payload}`;

  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    Buffer.from(signingInput)
  );

  const sigBase64 = Buffer.from(signature).toString('base64url');
  return `${signingInput}.${sigBase64}`;
}

// environment: 'sandbox' or 'production'
async function sendPush(deviceToken, environment, title, body, data = {}) {
  const token = await getApnsToken();
  const host = environment === 'production'
    ? 'api.push.apple.com'
    : 'api.sandbox.push.apple.com';
  const url = `https://${host}/3/device/${deviceToken}`;

  const payload = {
    aps: {
      alert: { title, body },
      sound: 'default',
      badge: 1,
    },
    ...data,
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'authorization': `bearer ${token}`,
      'apns-topic': process.env.APNS_BUNDLE_ID,
      'apns-push-type': 'alert',
      'content-type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const err = await res.json();
    console.error(`APNs error (${environment}):`, err);
  }
}

// Computes tomorrow 6:30 AM in the group's local timezone, returned as a UTC Date
function getNextSunriseInTimezone(timezone) {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowStr = tomorrow.toLocaleDateString('en-US', { timeZone: timezone });
  return new Date(`${tomorrowStr} 06:30:00 ${timezone}`);
}

exports.handler = async (event) => {
  console.log('Sunrise unlock Lambda triggered:', new Date().toISOString());
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const { rows: groupsToUnlock } = await client.query(`
      SELECT g.id, g.name, g.unlock_mode, g.unlock_at, g.timezone
      FROM groups g
      WHERE g.is_active = TRUE
        AND g.unlock_at IS NOT NULL
        AND g.unlock_at <= NOW()
        AND EXISTS (
          SELECT 1 FROM photos p
          WHERE p.group_id = g.id AND p.locked = TRUE
        )
    `);

    console.log(`Found ${groupsToUnlock.length} groups to unlock`);

    if (groupsToUnlock.length === 0) {
      await client.query('COMMIT');
      return { statusCode: 200, body: 'No groups to unlock' };
    }

    const unlockedGroups = [];

    for (const group of groupsToUnlock) {
      const { rowCount } = await client.query(`
        UPDATE photos
        SET locked = FALSE, unlocked_at = NOW()
        WHERE group_id = $1 AND locked = TRUE
        RETURNING id
      `, [group.id]);

      console.log(`Unlocked ${rowCount} photos in group: ${group.name}`);

      const { rows: members } = await client.query(`
        SELECT u.id, u.display_name, dt.token, dt.environment
        FROM group_members gm
        JOIN users u ON u.id = gm.user_id
        LEFT JOIN device_tokens dt ON dt.user_id = u.id
        WHERE gm.group_id = $1
      `, [group.id]);

      for (const member of members) {
        if (member.token) {
          try {
            await sendPush(
              member.token,
              member.environment || 'production',
              `${group.name} 📸`,
              `last night's photos just unlocked!`,
              { type: 'photos_unlocked', groupId: group.id }
            );
          } catch (pushErr) {
            console.error(`Push failed for ${member.display_name}:`, pushErr);
          }
        }
      }

      unlockedGroups.push({
        groupId: group.id,
        groupName: group.name,
        photosUnlocked: rowCount,
        memberCount: members.length,
      });

      if (group.unlock_mode === 'sunrise') {
        const nextUnlock = getNextSunriseInTimezone(group.timezone);
        await client.query(`
          UPDATE groups SET unlock_at = $1 WHERE id = $2
        `, [nextUnlock.toISOString(), group.id]);
      }
    }

    await client.query('COMMIT');

    console.log('Unlock complete:', JSON.stringify(unlockedGroups));
    return {
      statusCode: 200,
      body: JSON.stringify({ unlockedGroups }),
    };

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Lambda error:', err);
    throw err;
  } finally {
    client.release();
  }
};