const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  max: 2,
});

exports.handler = async (event) => {
  console.log('Sunrise unlock Lambda triggered:', new Date().toISOString());
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Find all groups that should unlock now:
    // 1. sunrise mode — unlock_at is before now (set by a separate daily scheduler)
    // 2. custom mode — unlock_at is before now
    // 3. sunday_night mode — unlock_at is before now
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
      // Unlock all locked photos in this group
      const { rowCount } = await client.query(`
        UPDATE photos
        SET locked = FALSE, unlocked_at = NOW()
        WHERE group_id = $1 AND locked = TRUE
        RETURNING id
      `, [group.id]);

      console.log(`Unlocked ${rowCount} photos in group: ${group.name}`);

      // Get all members to notify
      const { rows: members } = await client.query(`
        SELECT u.id, u.display_name
        FROM group_members gm
        JOIN users u ON u.id = gm.user_id
        WHERE gm.group_id = $1
      `, [group.id]);

      unlockedGroups.push({
        groupId: group.id,
        groupName: group.name,
        photosUnlocked: rowCount,
        memberCount: members.length,
      });

      // For sunrise mode, set the next unlock_at to tomorrow's sunrise
      if (group.unlock_mode === 'sunrise') {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(6, 30, 0, 0); // Default 6:30 AM — refine with sunrise API later

        await client.query(`
          UPDATE groups SET unlock_at = $1 WHERE id = $2
        `, [tomorrow.toISOString(), group.id]);
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