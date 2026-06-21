const { Pool } = require('pg');
const admin = require('firebase-admin');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  max: 2,
});

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    }),
  });
}

async function sendFCM(tokens, title, body, data) {
  if (!tokens || tokens.length === 0) return;
  data = data || {};
  var stringData = {};
  Object.keys(data).forEach(function(k) { stringData[k] = String(data[k]); });
  try {
    var response = await admin.messaging().sendEachForMulticast({
      tokens: tokens,
      notification: { title: title, body: body },
      data: stringData,
    });
    console.log('FCM: ' + response.successCount + ' sent, ' + response.failureCount + ' failed');
  } catch (err) {
    console.error('FCM error:', err);
  }
}

function getNextSunriseInTimezone(timezone) {
  var now = new Date();
  var tomorrow = new Date(now);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);

  var parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(tomorrow);

  var year = parts.find(function(p) { return p.type === 'year'; }).value;
  var month = parts.find(function(p) { return p.type === 'month'; }).value;
  var day = parts.find(function(p) { return p.type === 'day'; }).value;

  var target = new Date(year + '-' + month + '-' + day + 'T06:30:00');
  var localTime = new Date(tomorrow.toLocaleString('en-US', { timeZone: timezone }));
  var utcOffset = localTime - tomorrow;
  return new Date(target.getTime() - utcOffset);
}

exports.handler = async function(event) {
  console.log('Sunrise unlock Lambda triggered:', new Date().toISOString());
  var client = await pool.connect();

  try {
    await client.query('BEGIN');

    var result = await client.query(
      'SELECT g.id, g.name, g.unlock_mode, g.unlock_at, g.timezone ' +
      'FROM groups g ' +
      'WHERE g.is_active = TRUE ' +
      'AND g.unlock_at IS NOT NULL ' +
      'AND g.unlock_at <= NOW() ' +
      'AND EXISTS (SELECT 1 FROM photos p WHERE p.group_id = g.id AND p.locked = TRUE)'
    );
    var groupsToUnlock = result.rows;

    console.log('Found ' + groupsToUnlock.length + ' groups to unlock');

    if (groupsToUnlock.length === 0) {
      await client.query('COMMIT');
      return { statusCode: 200, body: 'No groups to unlock' };
    }

    var unlockedGroups = [];

    for (var i = 0; i < groupsToUnlock.length; i++) {
      var group = groupsToUnlock[i];

      var updateResult = await client.query(
        'UPDATE photos SET locked = FALSE, unlocked_at = NOW() WHERE group_id = $1 AND locked = TRUE RETURNING id',
        [group.id]
      );
      var rowCount = updateResult.rowCount;

      console.log('Unlocked ' + rowCount + ' photos in group: ' + group.name);

      var membersResult = await client.query(
        'SELECT u.id, u.display_name, dt.token ' +
        'FROM group_members gm ' +
        'JOIN users u ON u.id = gm.user_id ' +
        'LEFT JOIN device_tokens dt ON dt.user_id = u.id ' +
        'WHERE gm.group_id = $1 AND dt.token IS NOT NULL',
        [group.id]
      );
      var members = membersResult.rows;
      var tokens = members.map(function(m) { return m.token; }).filter(Boolean);

      await sendFCM(tokens, group.name + ' \uD83D\uDCF8', "last night's photos just unlocked!", { type: 'photos_unlocked', groupId: group.id });

      unlockedGroups.push({
        groupId: group.id,
        groupName: group.name,
        photosUnlocked: rowCount,
        memberCount: members.length,
      });

      if (group.unlock_mode === 'sunrise') {
        var nextUnlock = getNextSunriseInTimezone(group.timezone);
        console.log('Rescheduling ' + group.name + ' to unlock at: ' + nextUnlock.toISOString());
        await client.query('UPDATE groups SET unlock_at = $1 WHERE id = $2', [nextUnlock.toISOString(), group.id]);
      }
    }

    await client.query('COMMIT');
    console.log('Unlock complete:', JSON.stringify(unlockedGroups));
    return { statusCode: 200, body: JSON.stringify({ unlockedGroups: unlockedGroups }) };

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Lambda error:', err);
    throw err;
  } finally {
    client.release();
  }
};
