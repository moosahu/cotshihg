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
    // Patch 0: add UNIQUE constraint to therapists.user_id if missing
    await pool.query(`
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.table_constraints
          WHERE table_name='therapists' AND constraint_type='UNIQUE'
          AND constraint_name='therapists_user_id_key'
        ) THEN
          ALTER TABLE therapists ADD CONSTRAINT therapists_user_id_key UNIQUE (user_id);
        END IF;
      END $$;
    `);

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

    // Patch: session_files table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS session_files (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
        uploaded_by UUID REFERENCES users(id),
        file_name VARCHAR(255) NOT NULL,
        file_path VARCHAR(500) NOT NULL,
        file_size INTEGER,
        mime_type VARCHAR(100),
        created_at TIMESTAMP DEFAULT NOW()
      )
    `);

    // Patch: questionnaire_templates table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS questionnaire_templates (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        therapist_id UUID REFERENCES therapists(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        questions JSONB NOT NULL DEFAULT '[]',
        is_default BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);

    // Patch: questionnaire_assignments table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS questionnaire_assignments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        template_id UUID REFERENCES questionnaire_templates(id) ON DELETE CASCADE,
        booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
        client_id UUID REFERENCES users(id),
        status VARCHAR(50) DEFAULT 'pending',
        answers JSONB DEFAULT '{}',
        assigned_at TIMESTAMP DEFAULT NOW(),
        completed_at TIMESTAMP,
        UNIQUE(template_id, booking_id)
      )
    `);

    // Patch: discount_percent column on therapists
    await pool.query(`
      ALTER TABLE therapists ADD COLUMN IF NOT EXISTS discount_percent INTEGER DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100)
    `);

    // Patch: payment columns on bookings
    await pool.query(`
      ALTER TABLE bookings
        ADD COLUMN IF NOT EXISTS payment_status VARCHAR(20) DEFAULT 'pending',
        ADD COLUMN IF NOT EXISTS payment_id TEXT
    `);

    // Patch: payments table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS payments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
        user_id UUID REFERENCES users(id),
        amount DECIMAL(10,2) NOT NULL,
        currency VARCHAR(10) DEFAULT 'SAR',
        provider VARCHAR(50) DEFAULT 'stripe',
        provider_payment_id TEXT,
        status VARCHAR(20) DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);

    // Patch: questionnaire_questions table (admin-managed)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS questionnaire_questions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        question_text TEXT NOT NULL,
        question_type VARCHAR(20) DEFAULT 'text' CHECK (question_type IN ('text', 'rating', 'choice')),
        options JSONB,
        specialization TEXT,
        order_index INTEGER DEFAULT 0,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT NOW()
      )
    `);

    // Patch: questionnaire_responses table (client one-time answers)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS questionnaire_responses (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        client_id UUID REFERENCES users(id) ON DELETE CASCADE,
        question_id UUID REFERENCES questionnaire_questions(id) ON DELETE CASCADE,
        answer TEXT,
        created_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(client_id, question_id)
      )
    `);

    // Seed: default questionnaire questions (only if table is empty)
    const qCount = await pool.query(`SELECT COUNT(*) FROM questionnaire_questions`);
    if (parseInt(qCount.rows[0].count) === 0) {
      const defaultQuestions = [
        // التحديات والأهداف
        { text: 'ما هو التحدي الأكبر الذي تواجهه حالياً؟', type: 'text', spec: null, order: 1 },
        { text: 'ما هي النتيجة المثالية التي ترغب في الخروج بها من هذه الجلسة؟', type: 'text', spec: null, order: 2 },
        { text: 'ما الذي تحاول تحقيقه ولم تتمكن من ذلك حتى الآن؟', type: 'text', spec: null, order: 3 },
        // الوعي الذاتي والقيم
        { text: 'ما هي قيمك الشخصية أو المهنية التي تريد التركيز عليها؟', type: 'text', spec: null, order: 4 },
        { text: 'ما هو أعظم إنجاز حققته في الستة أشهر الماضية؟', type: 'text', spec: null, order: 5 },
        { text: 'ما هي نقاط القوة التي تعتمد عليها عادةً؟', type: 'text', spec: null, order: 6 },
        // الالتزام والتغيير
        { text: 'على مقياس من 1 إلى 10، ما مدى التزامك لتحقيق هذا الهدف؟', type: 'rating', spec: null, order: 7 },
        { text: 'ما الذي سيختلف في حياتك أو عملك إذا حققت هدفك؟', type: 'text', spec: null, order: 8 },
        { text: 'ما هي أول خطوة صغيرة ستتخذها بعد هذه الجلسة؟', type: 'text', spec: null, order: 9 },
      ];
      for (const q of defaultQuestions) {
        await pool.query(
          `INSERT INTO questionnaire_questions (question_text, question_type, specialization, order_index)
           VALUES ($1, $2, $3, $4)`,
          [q.text, q.type, q.spec, q.order]
        );
      }
      console.log('🌱 Default questionnaire questions seeded');
    }

    console.log('✅ DB patches applied');
  } catch (err) {
    console.error('⚠️  Patch error (non-fatal):', err.message);
  }
}

module.exports = runMigration;
