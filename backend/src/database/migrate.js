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

    // Patch: cancelled_by column on bookings
    await pool.query(`
      ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancelled_by VARCHAR(20)
    `);

    // Patch: payments table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS payments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
        user_id UUID REFERENCES users(id),
        amount DECIMAL(10,2) NOT NULL,
        currency VARCHAR(10) DEFAULT 'SAR',
        provider VARCHAR(50) DEFAULT 'paymob',
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

    // Patch: add set_id column to questionnaire_questions if missing
    await pool.query(`
      ALTER TABLE questionnaire_questions ADD COLUMN IF NOT EXISTS set_id UUID REFERENCES questionnaire_sets(id) ON DELETE CASCADE
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

    // Patch: set_assignments — coach sends admin questionnaire set to client per booking
    await pool.query(`
      CREATE TABLE IF NOT EXISTS set_assignments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        set_id UUID REFERENCES questionnaire_sets(id) ON DELETE CASCADE,
        booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
        client_id UUID REFERENCES users(id) ON DELETE CASCADE,
        coach_id UUID REFERENCES users(id),
        status VARCHAR(20) DEFAULT 'pending',
        answers JSONB DEFAULT '{}',
        assigned_at TIMESTAMP DEFAULT NOW(),
        completed_at TIMESTAMP,
        UNIQUE(set_id, booking_id)
      )
    `);

    // Seed: default questionnaire sets
    // Run if table is empty OR if no questions have set_id yet (partial/failed seed)
    const sCount = await pool.query(`SELECT COUNT(*) FROM questionnaire_sets`);
    const qCount = await pool.query(`SELECT COUNT(*) FROM questionnaire_questions WHERE set_id IS NOT NULL`);
    if (parseInt(sCount.rows[0].count) === 0 || parseInt(qCount.rows[0].count) === 0) {
      // Clear any partial seed data before reseeding
      await pool.query(`DELETE FROM questionnaire_sets`);
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

        // ── كوتش تعليمي ────────────────────────────────────────────
        {
          name: 'استبيان التطوير التعليمي قبل الجلسة', description: 'تقييم الوضع الأكاديمي والأهداف التعليمية', spec: 'كوتش تعليمي', timing: 'before',
          questions: [
            { text: 'ما وضعك الدراسي أو التعليمي الحالي؟', type: 'choice', order: 1, options: ['طالب جامعي', 'طالب ثانوي', 'خريج يبحث عن عمل', 'متخصص يريد التطوير', 'أخرى'] },
            { text: 'ما أكبر تحدٍّ تعليمي تواجهه حالياً؟', type: 'text', order: 2 },
            { text: 'ما هدفك التعليمي الرئيسي خلال الستة أشهر القادمة؟', type: 'text', order: 3 },
            { text: 'على مقياس 1-5، كيف تقيّم مستوى تركيزك وانتاجيتك في الدراسة؟', type: 'rating', order: 4 },
            { text: 'كيف تصف أسلوبك في التعلم؟', type: 'choice', order: 5, options: ['بصري (أتعلم بالصور والمخططات)', 'سمعي (أتعلم بالاستماع)', 'تطبيقي (أتعلم بالممارسة)', 'قرائي (أتعلم بالقراءة)'] },
            { text: 'ما أكبر عائق يمنعك من التحصيل الدراسي الذي تطمح إليه؟', type: 'text', order: 6 },
          ],
        },
        {
          name: 'متابعة الجلسة التعليمية', description: 'مراجعة التقدم الأكاديمي أثناء الجلسة', spec: 'كوتش تعليمي', timing: 'during',
          questions: [
            { text: 'ما الخطوات الدراسية التي نفّذتها منذ آخر جلسة؟', type: 'text', order: 1 },
            { text: 'هل التزمت بخطة الدراسة المتفق عليها؟', type: 'choice', order: 2, options: ['نعم بالكامل', 'جزئياً', 'لا، واجهت صعوبات'] },
            { text: 'على مقياس 1-5، كيف تقيّم مستوى فهمك للمادة التي درستها؟', type: 'rating', order: 3 },
            { text: 'ما الموضوع أو المهارة التي تحتاج مزيداً من الدعم فيها؟', type: 'text', order: 4 },
          ],
        },
        {
          name: 'خطة ما بعد الجلسة التعليمية', description: 'تحديد الخطوات الأكاديمية بعد الجلسة', spec: 'كوتش تعليمي', timing: 'after',
          questions: [
            { text: 'ما الموضوع أو المهارة التي ستركز عليها هذا الأسبوع؟', type: 'text', order: 1 },
            { text: 'كم ساعة يومياً ستخصص للدراسة؟', type: 'choice', order: 2, options: ['أقل من ساعة', '1-2 ساعة', '2-4 ساعات', 'أكثر من 4 ساعات'] },
            { text: 'ما الاستراتيجية الجديدة في الدراسة ستجربها؟', type: 'text', order: 3 },
            { text: 'على مقياس 1-5، ما مدى ثقتك بتحقيق هدفك التعليمي؟', type: 'rating', order: 4 },
          ],
        },

        // ── كوتش إداري / قيادي ─────────────────────────────────────
        {
          name: 'استبيان القيادة والإدارة قبل الجلسة', description: 'تقييم الكفاءات القيادية والتحديات الإدارية', spec: 'كوتش إداري', timing: 'before',
          questions: [
            { text: 'ما دورك الإداري الحالي؟', type: 'choice', order: 1, options: ['مدير فريق', 'مدير قسم', 'مدير عام', 'رائد أعمال', 'مشرف'] },
            { text: 'كم عدد الأشخاص الذين تديرهم أو تشرف عليهم؟', type: 'choice', order: 2, options: ['1-5 أشخاص', '6-15 شخصاً', '16-50 شخصاً', 'أكثر من 50'] },
            { text: 'ما أكبر تحدٍّ قيادي تواجهه مع فريقك حالياً؟', type: 'text', order: 3 },
            { text: 'على مقياس 1-5، كيف تقيّم فاعلية تواصلك مع فريقك؟', type: 'rating', order: 4 },
            { text: 'ما أسلوب قيادتك الغالب؟', type: 'choice', order: 5, options: ['ديمقراطي (يشرك الفريق)', 'تحويلي (يلهم ويحفز)', 'توجيهي (يوجه ويتابع)', 'تفويضي (يفوّض ويثق)'] },
            { text: 'ما القرار أو التحدي الإداري الذي تريد مناقشته اليوم؟', type: 'text', order: 6 },
          ],
        },
        {
          name: 'متابعة الجلسة الإدارية', description: 'مراجعة القرارات والتحديات القيادية أثناء الجلسة', spec: 'كوتش إداري', timing: 'during',
          questions: [
            { text: 'ما القرارات أو الإجراءات الإدارية التي اتخذتها منذ آخر جلسة؟', type: 'text', order: 1 },
            { text: 'كيف استجاب فريقك للتغييرات التي طبّقتها؟', type: 'choice', order: 2, options: ['بشكل إيجابي جداً', 'إيجابي إلى حد ما', 'مقاومة بسيطة', 'مقاومة كبيرة'] },
            { text: 'على مقياس 1-5، كيف تقيّم مستوى إنجازية فريقك هذا الأسبوع؟', type: 'rating', order: 3 },
            { text: 'ما الموقف القيادي الأصعب الذي واجهته؟ وكيف تعاملت معه؟', type: 'text', order: 4 },
          ],
        },
        {
          name: 'خطة ما بعد الجلسة الإدارية', description: 'تحديد الخطوات القيادية والإدارية بعد الجلسة', spec: 'كوتش إداري', timing: 'after',
          questions: [
            { text: 'ما أهم قرار إداري ستتخذه خلال الأسبوع القادم؟', type: 'text', order: 1 },
            { text: 'ما الإجراء القيادي الذي ستطبقه مع فريقك فوراً؟', type: 'text', order: 2 },
            { text: 'على مقياس 1-5، ما مدى وضوح رؤيتك القيادية بعد هذه الجلسة؟', type: 'rating', order: 3 },
            { text: 'كيف ستقيس تأثير تغييراتك القيادية على الفريق؟', type: 'text', order: 4 },
          ],
        },

        // ── كوتش حياة — تكملة ─────────────────────────────────────
        {
          name: 'متابعة جلسة التطوير الشخصي', description: 'مراجعة التحولات والأفكار أثناء جلسة كوتشينج الحياة', spec: 'كوتش حياة', timing: 'during',
          questions: [
            { text: 'ما الخطوات التي اتخذتها نحو هدفك الشخصي منذ آخر جلسة؟', type: 'text', order: 1 },
            { text: 'هل طبّقت ما تعهدت به في الجلسة الماضية؟', type: 'choice', order: 2, options: ['نعم بالكامل', 'جزئياً', 'لا، واجهت عوائق'] },
            { text: 'على مقياس 1-5، كيف تقيّم مستوى رضاك عن حياتك هذا الأسبوع؟', type: 'rating', order: 3 },
            { text: 'ما التحوّل أو الإدراك الجديد الذي اكتشفته في نفسك؟', type: 'text', order: 4 },
          ],
        },
        {
          name: 'خطة ما بعد جلسة الحياة', description: 'الالتزامات والخطوات بعد جلسة كوتشينج الحياة', spec: 'كوتش حياة', timing: 'after',
          questions: [
            { text: 'ما الالتزام الشخصي الأهم الذي خرجت به من هذه الجلسة؟', type: 'text', order: 1 },
            { text: 'ما عادة واحدة ستبدأ بها أو ستتوقف عنها من الآن؟', type: 'text', order: 2 },
            { text: 'على مقياس 1-5، ما مدى استعدادك للتغيير والتطبيق الفوري؟', type: 'rating', order: 3 },
            { text: 'كيف ستحتفل بنفسك عند تحقيق هدفك؟', type: 'text', order: 4 },
          ],
        },

        // ── استبيانات عامة إضافية ──────────────────────────────────
        {
          name: 'استبيان جودة الحياة', description: 'تقييم شامل لمجالات الحياة المختلفة (عجلة الحياة)', spec: null, timing: 'before',
          questions: [
            { text: 'على مقياس 1-5، كيف تقيّم رضاك عن صحتك الجسدية؟', type: 'rating', order: 1 },
            { text: 'على مقياس 1-5، كيف تقيّم رضاك عن علاقاتك الاجتماعية؟', type: 'rating', order: 2 },
            { text: 'على مقياس 1-5، كيف تقيّم رضاك عن وضعك المالي؟', type: 'rating', order: 3 },
            { text: 'على مقياس 1-5، كيف تقيّم رضاك عن مسارك المهني؟', type: 'rating', order: 4 },
            { text: 'على مقياس 1-5، كيف تقيّم رضاك عن نموك الشخصي؟', type: 'rating', order: 5 },
            { text: 'على مقياس 1-5، كيف تقيّم رضاك عن وقت فراغك وترفيهك؟', type: 'rating', order: 6 },
            { text: 'ما المجال الذي تريد تطويره أولاً بناءً على إجاباتك؟', type: 'text', order: 7 },
          ],
        },
        {
          name: 'استبيان تحديد الأهداف الذكية', description: 'تحديد الأهداف وفق منهجية SMART', spec: null, timing: 'before',
          questions: [
            { text: 'ما هدفك الرئيسي الذي تريد تحقيقه؟', type: 'text', order: 1 },
            { text: 'لماذا هذا الهدف مهم بالنسبة لك؟', type: 'text', order: 2 },
            { text: 'كيف ستعرف أنك حققت هدفك؟ (ما المقياس؟)', type: 'text', order: 3 },
            { text: 'ما الموعد النهائي الذي تريد تحقيق الهدف فيه؟', type: 'choice', order: 4, options: ['خلال أسبوع', 'خلال شهر', 'خلال 3 أشهر', 'خلال 6 أشهر', 'خلال سنة'] },
            { text: 'ما الموارد أو الدعم الذي تحتاجه لتحقيق هدفك؟', type: 'text', order: 5 },
            { text: 'على مقياس 1-5، ما مدى واقعية هدفك وقدرتك على تحقيقه؟', type: 'rating', order: 6 },
          ],
        },
        {
          name: 'استبيان إدارة الوقت والإنتاجية', description: 'تقييم عادات إدارة الوقت والإنتاجية الشخصية', spec: null, timing: 'before',
          questions: [
            { text: 'كيف تصف علاقتك بإدارة وقتك الحالية؟', type: 'choice', order: 1, options: ['ممتازة ومنظمة', 'جيدة لكن تحتاج تحسين', 'متذبذبة', 'ضعيفة جداً'] },
            { text: 'ما أكبر سارق للوقت في يومك؟', type: 'choice', order: 2, options: ['وسائل التواصل الاجتماعي', 'الاجتماعات غير المنتجة', 'عدم التخطيط المسبق', 'المقاطعات المستمرة', 'أخرى'] },
            { text: 'هل تستخدم أداة أو نظام لتنظيم مهامك؟', type: 'choice', order: 3, options: ['نعم، بشكل منتظم', 'أحياناً', 'لا'] },
            { text: 'على مقياس 1-5، كيف تقيّم مستوى إنتاجيتك اليومية؟', type: 'rating', order: 4 },
            { text: 'ما الوقت من اليوم الذي تكون فيه أكثر إنتاجية؟', type: 'choice', order: 5, options: ['الصباح الباكر', 'منتصف الصباح', 'بعد الظهر', 'المساء', 'الليل'] },
            { text: 'ما الهدف المتعلق بإدارة الوقت الذي تريد تحقيقه؟', type: 'text', order: 6 },
          ],
        },
        {
          name: 'استبيان الاتزان العاطفي والذكاء الوجداني', description: 'تقييم مستوى الوعي العاطفي وإدارة المشاعر', spec: null, timing: 'before',
          questions: [
            { text: 'كيف تتعامل عادةً مع الضغط والتوتر؟', type: 'choice', order: 1, options: ['بهدوء وتفكير منطقي', 'أحتاج وقتاً للهدوء ثم أتصرف', 'أتفاعل بعاطفة ثم أندم', 'أتجنب المشكلة'] },
            { text: 'على مقياس 1-5، كيف تقيّم قدرتك على التعرف على مشاعرك وفهمها؟', type: 'rating', order: 2 },
            { text: 'ما المشاعر التي تجد صعوبة في التعامل معها؟', type: 'choice', order: 3, options: ['الغضب', 'القلق والخوف', 'الحزن', 'الإحباط', 'الإحساس بالذنب'] },
            { text: 'كيف تؤثر مشاعرك على قراراتك اليومية؟', type: 'text', order: 4 },
            { text: 'على مقياس 1-5، كيف تقيّم قدرتك على التعاطف مع الآخرين وفهم مشاعرهم؟', type: 'rating', order: 5 },
          ],
        },
        {
          name: 'تقييم ما بعد الجلسة للعلاقات', description: 'متابعة التغييرات في العلاقات بعد الجلسة', spec: 'كوتش علاقات', timing: 'after',
          questions: [
            { text: 'ما المحادثة أو الخطوة التي ستتخذها في علاقاتك خلال 48 ساعة؟', type: 'text', order: 1 },
            { text: 'ما الحد الشخصي الجديد الذي ستضعه أو تحترمه؟', type: 'text', order: 2 },
            { text: 'على مقياس 1-5، ما مدى ثقتك بتحسين علاقاتك بعد هذه الجلسة؟', type: 'rating', order: 3 },
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

    // Patch: add specific_date to therapist_availability for one-time slots
    await pool.query(`
      ALTER TABLE therapist_availability ADD COLUMN IF NOT EXISTS specific_date DATE
    `);

    // Patch: commission system — coach_rate + bank details on therapists
    await pool.query(`
      ALTER TABLE therapists ADD COLUMN IF NOT EXISTS coach_rate INTEGER DEFAULT 70 CHECK (coach_rate >= 0 AND coach_rate <= 100)
    `);
    await pool.query(`
      ALTER TABLE therapists
        ADD COLUMN IF NOT EXISTS iban VARCHAR(34),
        ADD COLUMN IF NOT EXISTS bank_name VARCHAR(100),
        ADD COLUMN IF NOT EXISTS account_holder VARCHAR(150)
    `);

    // Patch: payout_requests table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS payout_requests (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        therapist_id UUID REFERENCES therapists(id) ON DELETE CASCADE,
        amount DECIMAL(10,2) NOT NULL,
        iban VARCHAR(34),
        bank_name VARCHAR(100),
        account_holder VARCHAR(150),
        status VARCHAR(20) DEFAULT 'pending',
        admin_note TEXT,
        requested_at TIMESTAMP DEFAULT NOW(),
        paid_at TIMESTAMP
      )
    `);

    // Patch: commission breakdown columns on payments
    await pool.query(`
      ALTER TABLE payments
        ADD COLUMN IF NOT EXISTS payment_method VARCHAR(30),
        ADD COLUMN IF NOT EXISTS paymob_fee DECIMAL(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS coach_amount DECIMAL(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS platform_amount DECIMAL(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS payout_status VARCHAR(20) DEFAULT 'pending',
        ADD COLUMN IF NOT EXISTS payout_date TIMESTAMP
    `);

    // Patch: notifications table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(200) NOT NULL,
        body TEXT,
        type VARCHAR(50),
        booking_id UUID,
        is_read BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT NOW()
      )
    `);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC)`);
    // Patch: add booking_id column if missing (table may have been created before this column was added)
    await pool.query(`ALTER TABLE notifications ADD COLUMN IF NOT EXISTS booking_id UUID`);
    await pool.query(`ALTER TABLE notifications ADD COLUMN IF NOT EXISTS type VARCHAR(50)`);
    await pool.query(`ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false`);

    // Patch: announcements table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS announcements (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title VARCHAR(200) NOT NULL,
        body TEXT,
        image_url TEXT,
        button_text VARCHAR(100),
        button_url TEXT,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT NOW()
      )
    `);

    console.log('✅ DB patches applied');
  } catch (err) {
    console.error('⚠️  Patch error (non-fatal):', err.message);
  }
}

module.exports = runMigration;
