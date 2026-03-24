import React, { useState, useEffect } from 'react';
import toast from 'react-hot-toast';
import api from '../services/api';

const TYPE_LABELS = { text: 'نصي', rating: 'تقييم (1-5)', choice: 'اختيار متعدد' };
const SPECIALIZATIONS = ['للكل', 'كوتش مالي', 'كوتش صحي', 'كوتش مهني', 'كوتش تعليمي', 'كوتش إداري', 'كوتش علاقات', 'كوتش حياة'];

const EMPTY = { question_text: '', question_type: 'text', options: '', order_index: 0, specialization: '' };

export default function Questionnaire() {
  const [questions, setQuestions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState(null); // null | { ...question } (new or edit)
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.getQuestionnaireQuestions()
      .then(res => setQuestions(res.data || []))
      .catch(err => toast.error(err.message))
      .finally(() => setLoading(false));
  }, []);

  const openNew = () => setModal({ ...EMPTY });
  const openEdit = (q) => setModal({
    ...q,
    options: Array.isArray(q.options) ? q.options.join('\n') : (q.options || ''),
    specialization: q.specialization || '',
  });

  const save = async () => {
    if (!modal.question_text.trim()) return toast.error('أدخل نص السؤال');
    setSaving(true);
    try {
      const payload = {
        question_text: modal.question_text.trim(),
        question_type: modal.question_type,
        order_index: parseInt(modal.order_index) || 0,
        specialization: modal.specialization || null,
        options: modal.question_type === 'choice'
          ? modal.options.split('\n').map(s => s.trim()).filter(Boolean)
          : null,
      };
      if (modal.id) {
        const res = await api.updateQuestion(modal.id, payload);
        setQuestions(prev => prev.map(q => q.id === modal.id ? res.data : q));
        toast.success('تم التحديث');
      } else {
        const res = await api.createQuestion(payload);
        setQuestions(prev => [...prev, res.data]);
        toast.success('تمت الإضافة');
      }
      setModal(null);
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSaving(false);
    }
  };

  const toggle = async (q) => {
    try {
      const res = await api.updateQuestion(q.id, { is_active: !q.is_active });
      setQuestions(prev => prev.map(x => x.id === q.id ? res.data : x));
    } catch (err) {
      toast.error(err.message);
    }
  };

  const remove = async (id) => {
    if (!window.confirm('حذف هذا السؤال؟')) return;
    try {
      await api.deleteQuestion(id);
      setQuestions(prev => prev.filter(q => q.id !== id));
      toast.success('تم الحذف');
    } catch (err) {
      toast.error(err.message);
    }
  };

  if (loading) return <div style={{ padding: 40, textAlign: 'center', color: '#8A94A6' }}>جاري التحميل...</div>;

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 700 }}>الاستبيان</h1>
          <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>أسئلة يملأها العميل مرة واحدة قبل جلساته</p>
        </div>
        <button
          onClick={openNew}
          style={{ padding: '10px 20px', background: '#1A6B72', color: '#fff', border: 'none', borderRadius: 10, fontSize: 14, fontWeight: 600, cursor: 'pointer' }}
        >
          + إضافة سؤال
        </button>
      </div>

      {questions.length === 0 ? (
        <div className="card" style={{ textAlign: 'center', padding: 48, color: '#8A94A6' }}>
          لا توجد أسئلة بعد — اضغط "إضافة سؤال" للبدء
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {questions.map((q, i) => (
            <div key={q.id} className="card" style={{ display: 'flex', alignItems: 'center', gap: 16, opacity: q.is_active ? 1 : 0.5 }}>
              <div style={{ width: 32, height: 32, borderRadius: 8, background: '#1A6B7215', color: '#1A6B72', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, flexShrink: 0 }}>
                {i + 1}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 600, fontSize: 15 }}>{q.question_text}</div>
                <div style={{ fontSize: 12, color: '#8A94A6', marginTop: 4 }}>
                  {TYPE_LABELS[q.question_type] || q.question_type}
                  {' · '}
                  <span style={{ color: q.specialization ? '#1A6B72' : '#F5A623', fontWeight: 600 }}>
                    {q.specialization || 'للكل'}
                  </span>
                  {Array.isArray(q.options) && q.options.length > 0 && ` — ${q.options.join(' / ')}`}
                </div>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button onClick={() => toggle(q)} style={{ padding: '5px 12px', borderRadius: 8, border: `1px solid ${q.is_active ? '#E53935' : '#2ECC71'}`, background: 'none', color: q.is_active ? '#E53935' : '#2ECC71', fontSize: 12, cursor: 'pointer' }}>
                  {q.is_active ? 'تعطيل' : 'تفعيل'}
                </button>
                <button onClick={() => openEdit(q)} style={{ padding: '5px 12px', borderRadius: 8, border: '1px solid #1A6B72', background: 'none', color: '#1A6B72', fontSize: 12, cursor: 'pointer' }}>
                  تعديل
                </button>
                <button onClick={() => remove(q.id)} style={{ padding: '5px 12px', borderRadius: 8, border: '1px solid #E53935', background: 'none', color: '#E53935', fontSize: 12, cursor: 'pointer' }}>
                  حذف
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal */}
      {modal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: '#fff', borderRadius: 16, padding: 32, width: 440, direction: 'rtl', maxHeight: '90vh', overflowY: 'auto' }}>
            <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 24 }}>{modal.id ? 'تعديل السؤال' : 'سؤال جديد'}</h2>

            <label style={{ fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 6 }}>نص السؤال</label>
            <textarea
              rows={3}
              value={modal.question_text}
              onChange={e => setModal(p => ({ ...p, question_text: e.target.value }))}
              style={{ width: '100%', padding: '10px 12px', border: '1px solid #E0E0E0', borderRadius: 8, fontSize: 14, resize: 'vertical', marginBottom: 16 }}
              placeholder="مثال: ما هو هدفك الرئيسي من الكوتشينج؟"
            />

            <label style={{ fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 6 }}>نوع الإجابة</label>
            <select
              value={modal.question_type}
              onChange={e => setModal(p => ({ ...p, question_type: e.target.value }))}
              style={{ width: '100%', padding: '10px 12px', border: '1px solid #E0E0E0', borderRadius: 8, fontSize: 14, marginBottom: 16 }}
            >
              <option value="text">نصي (إجابة حرة)</option>
              <option value="rating">تقييم (1 إلى 5)</option>
              <option value="choice">اختيار متعدد</option>
            </select>

            {modal.question_type === 'choice' && (
              <>
                <label style={{ fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 6 }}>الخيارات (كل خيار في سطر)</label>
                <textarea
                  rows={4}
                  value={modal.options}
                  onChange={e => setModal(p => ({ ...p, options: e.target.value }))}
                  style={{ width: '100%', padding: '10px 12px', border: '1px solid #E0E0E0', borderRadius: 8, fontSize: 14, resize: 'vertical', marginBottom: 16 }}
                  placeholder={'خيار أول\nخيار ثاني\nخيار ثالث'}
                />
              </>
            )}

            <label style={{ fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 6 }}>التخصص</label>
            <select
              value={modal.specialization}
              onChange={e => setModal(p => ({ ...p, specialization: e.target.value === 'للكل' ? '' : e.target.value }))}
              style={{ width: '100%', padding: '10px 12px', border: '1px solid #E0E0E0', borderRadius: 8, fontSize: 14, marginBottom: 16 }}
            >
              {SPECIALIZATIONS.map(s => (
                <option key={s} value={s === 'للكل' ? '' : s}>{s}</option>
              ))}
            </select>

            <label style={{ fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 6 }}>الترتيب</label>
            <input
              type="number"
              min="0"
              value={modal.order_index}
              onChange={e => setModal(p => ({ ...p, order_index: e.target.value }))}
              style={{ width: '100%', padding: '10px 12px', border: '1px solid #E0E0E0', borderRadius: 8, fontSize: 14, marginBottom: 24 }}
            />

            <div style={{ display: 'flex', gap: 10 }}>
              <button onClick={save} disabled={saving} style={{ flex: 1, padding: '10px 0', background: '#1A6B72', color: '#fff', border: 'none', borderRadius: 10, fontSize: 14, fontWeight: 600, cursor: 'pointer' }}>
                {saving ? 'جاري الحفظ...' : 'حفظ'}
              </button>
              <button onClick={() => setModal(null)} style={{ flex: 1, padding: '10px 0', background: '#f5f5f5', color: '#333', border: 'none', borderRadius: 10, fontSize: 14, cursor: 'pointer' }}>
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
