const fs = require('fs');
const path = require('path');
const pool = require('../config/database');

async function runMigration() {
  try {
    // Check if users table already exists
    const check = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'users'
      )
    `);

    if (check.rows[0].exists) {
      console.log('✅ Database already initialized — skipping migration');
      await runPatches();
      return;
    }

    console.log('🔄 Running database migration...');
    const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    await pool.query(schema);
    console.log('✅ Database migration completed successfully');
  } catch (err) {
    console.error('❌ Migration error:', err.message);
  }
}

// Run patches on existing DB (safe to run multiple times)
async function runPatches() {
  try {
    // Patch 1: add 'coach' to users role constraint
    await pool.query(`
      ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
      ALTER TABLE users ADD CONSTRAINT users_role_check
        CHECK (role IN ('client', 'therapist', 'coach', 'admin'));
    `);

    // Patch 2: end stale active sessions older than 2 hours
    const stale = await pool.query(`
      UPDATE sessions SET status='ended', ended_at=NOW()
      WHERE status='active' AND started_at < NOW() - INTERVAL '2 hours'
      RETURNING booking_id
    `);
    for (const row of stale.rows) {
      await pool.query(
        `UPDATE bookings SET status='completed', updated_at=NOW() WHERE id=$1`,
        [row.booking_id]
      );
    }
    if (stale.rows.length > 0) {
      console.log(`🧹 Cleaned up ${stale.rows.length} stale sessions on startup`);
    }

    // Patch 3: cancel stale pending instant bookings older than 30 minutes
    await pool.query(`
      UPDATE bookings SET status='cancelled', updated_at=NOW()
      WHERE booking_type='instant' AND status='pending'
      AND created_at < NOW() - INTERVAL '30 minutes'
    `);

    console.log('✅ DB patches applied');
  } catch (err) {
    console.error('⚠️  Patch error (non-fatal):', err.message);
  }
}

module.exports = runMigration;
