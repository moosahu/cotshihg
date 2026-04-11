const cron = require('node-cron');
const pool = require('../config/database');
const cloudinary = require('cloudinary').v2;

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key:    process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

/**
 * Deletes chat messages + Cloudinary files older than 24 hours.
 * Runs every hour.
 */
function startCleanupJob() {
  cron.schedule('0 * * * *', async () => {
    try {
      // 1. Delete Cloudinary files linked to old messages
      const expiredFiles = await pool.query(
        `SELECT sf.id, sf.file_path, sf.mime_type
         FROM session_files sf
         JOIN messages m ON m.media_url = sf.file_path
         WHERE m.created_at < NOW() - INTERVAL '24 hours'`
      );

      for (const file of expiredFiles.rows) {
        try {
          const match = file.file_path.match(/\/upload\/(?:v\d+\/)?(.+?)(?:\.[^.]+)?$/);
          if (match) {
            const isPdf = file.mime_type === 'application/pdf';
            await cloudinary.uploader.destroy(match[1], { resource_type: isPdf ? 'raw' : 'image' });
          }
        } catch (_) {}
        await pool.query('DELETE FROM session_files WHERE id=$1', [file.id]);
      }

      // 2. Delete messages older than 24 hours
      const deleted = await pool.query(
        `DELETE FROM messages WHERE created_at < NOW() - INTERVAL '24 hours'`
      );

      if (deleted.rowCount > 0) {
        console.log(`🗑️ Cleanup: deleted ${deleted.rowCount} messages, ${expiredFiles.rowCount} files`);
      }
    } catch (err) {
      console.error('❌ Cleanup job error:', err.message);
    }
  });

  console.log('🕐 Chat cleanup job scheduled (every hour)');
}

module.exports = { startCleanupJob };
