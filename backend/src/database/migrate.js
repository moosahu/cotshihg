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

    // Patch: questionnaire_sets table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS questionnaire_sets (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        description TEXT,
        specialization TEXT,
        timing VARCHAR(20) DEFAULT 'general',
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT NOW()
      )
    `);

    // Patch: add timing column to questionnaire_sets if missing
    await pool.query(`
      ALTER TABLE questionnaire_sets ADD COLUMN IF NOT EXISTS timing VARCHAR(20) DEFAULT 'general'
    `);

    // Patch: questionnaire_questions table (admin-managed)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS questionnaire_questions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        set_id UUID REFERENCES questionnaire_sets(id) ON DELETE CASCADE,
        question_text TEXT NOT NULL,
        question_type VARCHAR(20) DEFAULT 'text' CHECK (question_type IN ('text', 'rating', 'choice')),
        options JSONB,
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

    // Seed: default questionnaire sets (only if table is empty)
    const sCount = await pool.query(`SELECT COUNT(*) FROM questionnaire_sets`);
    if (parseInt(sCount.rows[0].count) === 0) {
      const sets = [
        // ── قبل الجلسة ────────────────────────────────────────────
        {
          name: 'استبيان ما قبل الجلسة الشامل', description: 'أسئلة عامة لتعميق الفهم قبل الجلسة', spec: null, timing: 'before',
          questions: [
            { text: 'ما هو التحدي الأكبر الذي تواجهه حالياً؟', type: 'text', order: 1 },
            { text: 'ما هي النتيجة المثالية التي ترغب في الخروج بها من هذه الجلسة؟', type: 'text', order: 2 },
            { text: 'ما الذي تحاول تحقيقه ولم تتمكن من ذلك حتى الآن؟', type: 'text', order: 3 },
            { text: 'على مقياس من 1 إلى 5، ما مدى التزامك لتحقيق هذا الهدف؟', type: 'rating', order: 4 },
            { text: 'ما هي أول خطوة صغيرة ستتخذها بعد هذه الجلسة؟', type: 'text', order: 5 },
          ],
        },
        {
          name: 'استبيان الوعي الذاتي والقيم', description: 'اكتشاف القيم ونقاط القوة الشخصية', spec: null, timing: 'before',
          questions: [
            { text: 'ما هي قيمك الشخصية أو المهنية التي تريد التركيز عليها؟', type: 'text', order: 1 },
            { text: 'ما هو أعظم إنجاز حققته في الستة أشهر الماضية؟', type: 'text', order: 2 },
            { text: 'ما هي نقاط القوة التي تعتمد عليها عادةً؟', type: 'text', order: 3 },
            { text: 'ما الذي سيختلف في حياتك أو عملك إذا حققت هدفك؟', type: 'text', order: 4 },
          ],
        },
        {
          name: 'استبيان الوضع المالي قبل الجلسة', description: 'تقييم الوضع المالي الحالي والأهداف المالية', spec: 'كوتش مالي', timing: 'before',
          questions: [
            { text: 'كيف تصف وضعك المالي الحالي بشكل عام؟', type: 'text', order: 1 },
            { text: 'ما هو هدفك المالي الرئيسي خلال السنة القادمة؟', type: 'text', order: 2 },
            { text: 'هل لديك ميزانية شهرية محددة؟', type: 'choice', order: 3, options: ['نعم وأطبقها', 'نعم لكن لا أطبقها', 'لا توجد ميزانية'] },
            { text: 'على مقياس 1-5، كيف تقيّم مستوى ادخارك الحالي؟', type: 'rating', order: 4 },
            { text: 'ما أكبر تحدٍّ مالي تواجهه الآن؟', type: 'text', order: 5 },
          ],
        },
        {
          name: 'استبيان الصحة والعافية قبل الجلسة', description: 'تقييم الصحة الجسدية والنفسية والعادات اليومية', spec: 'كوتش صحي', timing: 'before',
          questions: [
            { text: 'كيف تصف مستوى طاقتك اليومية بشكل عام؟', type: 'choice', order: 1, options: ['ممتازة', 'جيدة', 'متوسطة', 'منخفضة'] },
            { text: 'كم ساعة تنام في المتوسط يومياً؟', type: 'choice', order: 2, options: ['أقل من 5 ساعات', '5-6 ساعات', '7-8 ساعات', 'أكثر من 8 ساعات'] },
            { text: 'ما هو هدفك الصحي الرئيسي الذي تريد تحقيقه؟', type: 'text', order: 3 },
            { text: 'على مقياس 1-5، كيف تقيّم مستوى نشاطك البدني الأسبوعي؟', type: 'rating', order: 4 },
            { text: 'ما العادة الصحية التي تجد صعوبة في الالتزام بها؟', type: 'text', order: 5 },
          ],
        },
        {
          name: 'استبيان التطوير المهني قبل الجلسة', description: 'تقييم المسار المهني والأهداف الوظيفية', spec: 'كوتش مهني', timing: 'before',
          questions: [
            { text: 'ما وضعك المهني الحالي؟', type: 'choice', order: 1, options: ['موظف', 'صاحب عمل', 'أعمال حرة', 'باحث عن عمل', 'طالب'] },
            { text: 'أين تريد أن تكون مهنياً بعد 3 سنوات؟', type: 'text', order: 2 },
            { text: 'ما المهارة التي تريد تطويرها بشكل أكبر؟', type: 'text', order: 3 },
            { text: 'على مقياس 1-5، كيف تقيّم رضاك عن مسارك المهني الحالي؟', type: 'rating', order: 4 },
            { text: 'ما أكبر عقبة تمنعك من التقدم في مسيرتك المهنية؟', type: 'text', order: 5 },
          ],
        },
        {
          name: 'استبيان العلاقات قبل الجلسة', description: 'تقييم جودة العلاقات الشخصية والاجتماعية', spec: 'كوتش علاقات', timing: 'before',
          questions: [
            { text: 'كيف تصف جودة علاقاتك الشخصية بشكل عام؟', type: 'choice', order: 1, options: ['ممتازة', 'جيدة', 'تحتاج تطوير', 'تحتاج مساعدة عاجلة'] },
            { text: 'ما أكبر تحدٍّ تواجهه في علاقاتك الحالية؟', type: 'text', order: 2 },
            { text: 'ما الذي تريد تحسينه في طريقة تواصلك مع الآخرين؟', type: 'text', order: 3 },
            { text: 'على مقياس 1-5، كيف تقيّم قدرتك على التعبير عن مشاعرك؟', type: 'rating', order: 4 },
            { text: 'ما العلاقة التي تريد تطويرها أو إصلاحها بشكل أكبر؟', type: 'text', order: 5 },
          ],
        },
        {
          name: 'استبيان التطوير الشخصي قبل الجلسة', description: 'استكشاف العوائق الذهنية والمعتقدات المحدودة', spec: 'كوتش حياة', timing: 'before',
          questions: [
            { text: 'ما المعتقد السلبي الذي يعيق تقدمك حالياً؟', type: 'text', order: 1 },
            { text: 'ما الفرق بين حياتك المثالية وحياتك الحالية؟', type: 'text', order: 2 },
            { text: 'على مقياس 1-5، كيف تقيّم رضاك العام عن حياتك الآن؟', type: 'rating', order: 3 },
            { text: 'ما مجال الحياة الذي تريد تطويره أولاً؟', type: 'choice', order: 4, options: ['الصحة', 'العلاقات', 'المال', 'العمل', 'النمو الشخصي'] },
            { text: 'ما الشخص الذي تريد أن تكونه بعد سنة من الآن؟', type: 'text', order: 5 },
          ],
        },

        // ── أثناء الجلسة ───────────────────────────────────────────
        {
          name: 'متابعة الجلسة الشامل', description: 'أسئلة للمتابعة والتعمق أثناء الجلسة', spec: null, timing: 'during',
          questions: [
            { text: 'ما الذي تشعر به الآن؟', type: 'text', order: 1 },
            { text: 'ما أكثر شيء يشغل تفكيرك في هذه اللحظة؟', type: 'text', order: 2 },
            { text: 'ما الذي لم تقله بعد وتريد مشاركته؟', type: 'text', order: 3 },
            { text: 'هل تتضح الصورة أكثر مع تقدم الجلسة؟', type: 'choice', order: 4, options: ['نعم بشكل كبير', 'إلى حد ما', 'لا تزال ضبابية'] },
          ],
        },
        {
          name: 'متابعة التقدم المالي', description: 'مراجعة التقدم المالي أثناء جلسات الكوتشينج المالي', spec: 'كوتش مالي', timing: 'during',
          questions: [
            { text: 'ما الخطوات المالية التي اتخذتها منذ آخر جلسة؟', type: 'text', order: 1 },
            { text: 'هل التزمت بالميزانية المتفق عليها؟', type: 'choice', order: 2, options: ['نعم بالكامل', 'جزئياً', 'لا'] },
            { text: 'على مقياس 1-5، كيف تقيّم تقدمك المالي هذا الأسبوع؟', type: 'rating', order: 3 },
            { text: 'ما أكبر عائق مالي واجهته منذ آخر جلسة؟', type: 'text', order: 4 },
          ],
        },
        {
          name: 'متابعة أهداف الصحة', description: 'مراجعة التقدم الصحي أثناء جلسات الكوتشينج الصحي', spec: 'كوتش صحي', timing: 'during',
          questions: [
            { text: 'هل التزمت بخطة التمارين والتغذية المتفق عليها؟', type: 'choice', order: 1, options: ['نعم بالكامل', 'جزئياً', 'لا'] },
            { text: 'كيف تصف مستوى طاقتك هذا الأسبوع مقارنة بالأسبوع الماضي؟', type: 'choice', order: 2, options: ['أفضل بكثير', 'أفضل قليلاً', 'نفس الشيء', 'أسوأ'] },
            { text: 'على مقياس 1-5، كيف تقيّم تقدمك نحو هدفك الصحي؟', type: 'rating', order: 3 },
            { text: 'ما التحدي الأكبر في الالتزام بالعادات الصحية؟', type: 'text', order: 4 },
          ],
        },
        {
          name: 'متابعة المسار المهني', description: 'مراجعة التقدم المهني أثناء جلسات كوتشينج الأعمال', spec: 'كوتش مهني', timing: 'during',
          questions: [
            { text: 'ما الإجراءات المهنية التي نفّذتها منذ آخر جلسة؟', type: 'text', order: 1 },
            { text: 'هل اقتربت من هدفك المهني المحدد؟', type: 'choice', order: 2, options: ['نعم بشكل ملحوظ', 'خطوات صغيرة', 'لا تقدم', 'تراجع'] },
            { text: 'على مقياس 1-5، كيف تقيّم مستوى إنتاجيتك هذا الأسبوع؟', type: 'rating', order: 3 },
            { text: 'ما أكبر درس تعلمته من تجربة الأسبوع الماضي؟', type: 'text', order: 4 },
          ],
        },
        {
          name: 'متابعة جلسة العلاقات', description: 'مراجعة التقدم في تطوير العلاقات', spec: 'كوتش علاقات', timing: 'during',
          questions: [
            { text: 'ما الإجراءات التي اتخذتها لتحسين علاقاتك منذ آخر جلسة؟', type: 'text', order: 1 },
            { text: 'هل شهدت تحسناً في التواصل مع الآخرين؟', type: 'choice', order: 2, options: ['نعم تحسن كبير', 'تحسن بسيط', 'لا تغيير', 'تراجع'] },
            { text: 'على مقياس 1-5، كيف تقيّم جودة علاقاتك هذا الأسبوع؟', type: 'rating', order: 3 },
            { text: 'ما الموقف الذي تعاملت معه بشكل مختلف هذا الأسبوع؟', type: 'text', order: 4 },
          ],
        },

        // ── بعد الجلسة ─────────────────────────────────────────────
        {
          name: 'تقييم الجلسة وجودتها', description: 'تقييم شامل لجودة الجلسة ومدى الاستفادة', spec: null, timing: 'after',
          questions: [
            { text: 'على مقياس 1-5، كيف تقيّم جودة هذه الجلسة بشكل عام؟', type: 'rating', order: 1 },
            { text: 'ما أكثر شيء استفدت منه في هذه الجلسة؟', type: 'text', order: 2 },
            { text: 'هل تحققت أهداف الجلسة التي حددتها في البداية؟', type: 'choice', order: 3, options: ['نعم بالكامل', 'جزئياً', 'لم تتحقق'] },
            { text: 'على مقياس 1-5، كيف تقيّم أداء الكوتش وطريقة توجيهه؟', type: 'rating', order: 4 },
            { text: 'ما الذي تتمنى تغييره أو تحسينه في الجلسة القادمة؟', type: 'text', order: 5 },
          ],
        },
        {
          name: 'خطة العمل بعد الجلسة', description: 'تحديد الخطوات العملية للتطبيق بعد الجلسة', spec: null, timing: 'after',
          questions: [
            { text: 'ما أهم قرار أو التزام خرجت به من هذه الجلسة؟', type: 'text', order: 1 },
            { text: 'ما الخطوات الثلاث الأولى ستطبقها خلال الأسبوع القادم؟', type: 'text', order: 2 },
            { text: 'ما العائق الذي قد يمنعك من التطبيق، وكيف ستتعامل معه؟', type: 'text', order: 3 },
            { text: 'على مقياس 1-5، كيف تقيّم استعدادك للتطبيق الفوري؟', type: 'rating', order: 4 },
            { text: 'متى ستراجع تقدمك في تنفيذ خطة العمل؟', type: 'choice', order: 5, options: ['بعد 3 أيام', 'بعد أسبوع', 'في الجلسة القادمة'] },
          ],
        },
        {
          name: 'متابعة ما بعد الجلسة المالية', description: 'متابعة تطبيق الخطة المالية بعد الجلسة', spec: 'كوتش مالي', timing: 'after',
          questions: [
            { text: 'ما الإجراء المالي الأول ستنفذه خلال 48 ساعة؟', type: 'text', order: 1 },
            { text: 'ما الهدف المالي المحدد الذي تريد تحقيقه قبل الجلسة القادمة؟', type: 'text', order: 2 },
            { text: 'على مقياس 1-5، ما مدى ثقتك بتطبيق ما تعلمته اليوم؟', type: 'rating', order: 3 },
          ],
        },
        {
          name: 'متابعة ما بعد الجلسة الصحية', description: 'متابعة الالتزام بالعادات الصحية بعد الجلسة', spec: 'كوتش صحي', timing: 'after',
          questions: [
            { text: 'ما العادة الصحية الجديدة ستبدأ بها اليوم؟', type: 'text', order: 1 },
            { text: 'ما التحدي الصحي الأكبر الذي تواجهه في التطبيق؟', type: 'text', order: 2 },
            { text: 'على مقياس 1-5، ما مدى التزامك بتطبيق الخطة الصحية المتفق عليها؟', type: 'rating', order: 3 },
          ],
        },
        {
          name: 'متابعة ما بعد الجلسة المهنية', description: 'تحديد خطوات التطبيق بعد جلسة كوتشينج الأعمال', spec: 'كوتش مهني', timing: 'after',
          questions: [
            { text: 'ما المهارة أو الإجراء المهني الذي ستطبقه هذا الأسبوع؟', type: 'text', order: 1 },
            { text: 'كيف ستقيس تقدمك المهني قبل الجلسة القادمة؟', type: 'text', order: 2 },
            { text: 'على مقياس 1-5، ما مدى وضوح مسارك المهني بعد هذه الجلسة؟', type: 'rating', order: 3 },
          ],
        },
      ];

      for (const s of sets) {
        const setRes = await pool.query(
          `INSERT INTO questionnaire_sets (name, description, specialization, timing) VALUES ($1, $2, $3, $4) RETURNING id`,
          [s.name, s.description, s.spec || null, s.timing]
        );
        const setId = setRes.rows[0].id;
        for (const q of s.questions) {
          await pool.query(
            `INSERT INTO questionnaire_questions (set_id, question_text, question_type, options, order_index)
             VALUES ($1, $2, $3, $4, $5)`,
            [setId, q.text, q.type, q.options ? JSON.stringify(q.options) : null, q.order]
          );
        }
      }
      console.log(`🌱 Default questionnaire sets seeded (${sets.length} sets)`);
    }

    console.log('✅ DB patches applied');
  } catch (err) {
    console.error('⚠️  Patch error (non-fatal):', err.message);
  }
}

module.exports = runMigration;
