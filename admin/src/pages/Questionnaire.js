import React, { useState, useEffect } from 'react';
import toast from 'react-hot-toast';
import api from '../services/api';

const TYPE_LABELS = { text: 'نصي', rating: 'تقييم (1-5)', choice: 'اختيار متعدد' };
const SPECIALIZATIONS = ['للكل', 'كوتش مالي', 'كوتش صحي', 'كوتش مهني', 'كوتش تعليمي', 'كوتش إداري', 'كوتش علاقات', 'كوتش حياة'];
const TIMING_LABELS = { general: 'عام', before: 'قبل الجلسة', during: 'أثناء الجلسة', after: 'بعد الجلسة' };
const TIMING_COLORS = { general: '#8A94A6', before: '#1A6B72', during: '#F5A623', after: '#2ECC71' };

const EMPTY_SET = { name: '', description: '', specialization: '', timing: 'general' };
const EMPTY_Q = { question_text: '', question_type: 'text', options: '', order_index: 0 };

export default function Questionnaire() {
  const [sets, setSets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedSet, setSelectedSet] = useState(null); // null = sets view, object = questions view
  const [questions, setQuestions] = useState([]);
  const [qLoading, setQLoading] = useState(false);
  const [setModal, setSetModal] = useState(null);
  const [qModal, setQModal] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    loadSets();
  }, []);

  const loadSets = () => {
    setLoading(true);
    api.getQuestionnaireSets()
      .then(res => setSets(res.data || []))
      .catch(err => toast.error(err.message))
      .finally(() => setLoading(false));
  };

  const openSet = async (set) => {
    setSelectedSet(set);
    setQLoading(true);
    try {
      const res = await api.getSetQuestions(set.id);
      setQuestions(res.data || []);
    } catch (err) {
      toast.error(err.message);
    } finally {
      setQLoading(false);
    }
  };

  // ── Sets CRUD ──
  const saveSet = async () => {
    if (!setModal.name.trim()) return toast.error('أدخل اسم الاستبيان');
    setSaving(true);
    try {
      const payload = {
        name: setModal.name.trim(),
        description: setModal.description.trim() || null,
        specialization: setModal.specialization || null,
        timing: setModal.timing || 'general',
      };
      if (setModal.id) {
        const res = await api.updateQuestionnaireSet(setModal.id, payload);
        setSets(prev => prev.map(s => s.id === setModal.id ? { ...s, ...res.data } : s));
        if (selectedSet?.id === setModal.id) setSelectedSet(s => ({ ...s, ...res.data }));
        toast.success('تم التحديث');
      } else {
        const res = await api.createQuestionnaireSet(payload);
        setSets(prev => [...prev, res.data]);
        toast.success('تمت الإضافة');
      }
      setSetModal(null);
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSaving(false);
    }
  };

  const toggleSet = async (set) => {
    try {
      const res = await api.updateQuestionnaireSet(set.id, { is_active: !set.is_active });
      setSets(prev => prev.map(s => s.id === set.id ? { ...s, ...res.data } : s));
    } catch (err) {
      toast.error(err.message);
    }
  };

  const removeSet = async (id) => {
    if (!window.confirm('حذف هذا الاستبيان وجميع أسئلته؟')) return;
    try {
      await api.deleteQuestionnaireSet(id);
      setSets(prev => prev.filter(s => s.id !== id));
      toast.success('تم الحذف');
    } catch (err) {
      toast.error(err.message);
    }
  };

  // ── Questions CRUD ──
  const saveQuestion = async () => {
    if (!qModal.question_text.trim()) return toast.error('أدخل نص السؤال');
    setSaving(true);
    try {
      const payload = {
        question_text: qModal.question_text.trim(),
        question_type: qModal.question_type,
        order_index: parseInt(qModal.order_index) || 0,
        options: qModal.question_type === 'choice'
          ? qModal.options.split('\n').map(s => s.trim()).filter(Boolean)
          : null,
      };
      if (qModal.id) {
        const res = await api.updateQuestion(qModal.id, payload);
        setQuestions(prev => prev.map(q => q.id === qModal.id ? res.data : q));
        toast.success('تم التحديث');
      } else {
        const res = await api.createSetQuestion(selectedSet.id, payload);
        setQuestions(prev => [...prev, res.data]);
        setSets(prev => prev.map(s => s.id === selectedSet.id
          ? { ...s, question_count: (parseInt(s.question_count) || 0) + 1 }
          : s));
        toast.success('تمت الإضافة');
      }
      setQModal(null);
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSaving(false);
    }
  };

  const toggleQuestion = async (q) => {
    try {
      const res = await api.updateQuestion(q.id, { is_active: !q.is_active });
      setQuestions(prev => prev.map(x => x.id === q.id ? res.data : x));
    } catch (err) {
      toast.error(err.message);
    }
  };

  const removeQuestion = async (id) => {
    if (!window.confirm('حذف هذا السؤال؟')) return;
    try {
      await api.deleteQuestion(id);
      setQuestions(prev => prev.filter(q => q.id !== id));
      setSets(prev => prev.map(s => s.id === selectedSet.id
        ? { ...s, question_count: Math.max(0, (parseInt(s.question_count) || 1) - 1) }
        : s));
      toast.success('تم الحذف');
    } catch (err) {
      toast.error(err.message);
    }
  };

  // ── Questions view ──
  if (selectedSet) {
    return (
      <div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 24 }}>
          <button
            onClick={() => setSelectedSet(null)}
            style={{ padding: '8px 16px', background: '#f5f5f5', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 14 }}
          >
            ← رجوع
          </button>
          <div style={{ flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <h1 style={{ fontSize: 20, fontWeight: 700, margin: 0 }}>{selectedSet.name}</h1>
              <span style={{ padding: '2px 10px', borderRadius: 12, fontSize: 12, fontWeight: 600, background: TIMING_COLORS[selectedSet.timing] + '20', color: TIMING_COLORS[selectedSet.timing] }}>
                {TIMING_LABELS[selectedSet.timing] || selectedSet.timing}
              </span>
              {selectedSet.specialization && (
                <span style={{ padding: '2px 10px', borderRadius: 12, fontSize: 12, background: '#1A6B7215', color: '#1A6B72' }}>
                  {selectedSet.specialization}
                </span>
              )}
            </div>
            {selectedSet.description && (
              <p style={{ color: '#8A94A6', fontSize: 13, margin: '4px 0 0' }}>{selectedSet.description}</p>
            )}
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              onClick={() => setSetModal({ ...selectedSet, specialization: selectedSet.specialization || '' })}
              style={{ padding: '8px 16px', background: 'none', border: '1px solid #1A6B72', color: '#1A6B72', borderRadius: 8, cursor: 'pointer', fontSize: 13 }}
            >
              تعديل الاستبيان
            </button>
            <button
              onClick={() => setQModal({ ...EMPTY_Q })}
              style={{ padding: '8px 16px', background: '#1A6B72', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 13, fontWeight: 600 }}
            >
              + إضافة سؤال
            </button>
          </div>
        </div>

        {qLoading ? (
          <div style={{ textAlign: 'center', padding: 40, color: '#8A94A6' }}>جاري التحميل...</div>
        ) : questions.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: 48, color: '#8A94A6' }}>
            لا توجد أسئلة — اضغط "+ إضافة سؤال" للبدء
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {questions.map((q, i) => (
              <div key={q.id} className="card" style={{ display: 'flex', alignItems: 'center', gap: 16, opacity: q.is_active ? 1 : 0.5 }}>
                <div style={{ width: 32, height: 32, borderRadius: 8, background: '#1A6B7215', color: '#1A6B72', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, flexShrink: 0, fontSize: 14 }}>
                  {i + 1}
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 600, fontSize: 15 }}>{q.question_text}</div>
                  <div style={{ fontSize: 12, color: '#8A94A6', marginTop: 4 }}>
                    {TYPE_LABELS[q.question_type] || q.question_type}
                    {Array.isArray(q.options) && q.options.length > 0 && ` — ${q.options.join(' / ')}`}
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button onClick={() => toggleQuestion(q)} style={{ padding: '4px 10px', borderRadius: 6, border: `1px solid ${q.is_active ? '#E53935' : '#2ECC71'}`, background: 'none', color: q.is_active ? '#E53935' : '#2ECC71', fontSize: 12, cursor: 'pointer' }}>
                    {q.is_active ? 'تعطيل' : 'تفعيل'}
                  </button>
                  <button onClick={() => setQModal({ ...q, options: Array.isArray(q.options) ? q.options.join('\n') : (q.options || '') })} style={{ padding: '4px 10px', borderRadius: 6, border: '1px solid #1A6B72', background: 'none', color: '#1A6B72', fontSize: 12, cursor: 'pointer' }}>
                    تعديل
                  </button>
                  <button onClick={() => removeQuestion(q.id)} style={{ padding: '4px 10px', borderRadius: 6, border: '1px solid #E53935', background: 'none', color: '#E53935', fontSize: 12, cursor: 'pointer' }}>
                    حذف
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Question Modal */}
        {qModal && (
          <Modal title={qModal.id ? 'تعديل السؤال' : 'سؤال جديد'} onClose={() => setQModal(null)}>
            <label style={labelStyle}>نص السؤال</label>
            <textarea rows={3} value={qModal.question_text}
              onChange={e => setQModal(p => ({ ...p, question_text: e.target.value }))}
              style={inputStyle} placeholder="مثال: كيف تقيّم تقدمك هذا الأسبوع؟" />

            <label style={labelStyle}>نوع الإجابة</label>
            <select value={qModal.question_type}
              onChange={e => setQModal(p => ({ ...p, question_type: e.target.value }))}
              style={inputStyle}>
              <option value="text">نصي (إجابة حرة)</option>
              <option value="rating">تقييم (1 إلى 5)</option>
              <option value="choice">اختيار متعدد</option>
            </select>

            {qModal.question_type === 'choice' && (
              <>
                <label style={labelStyle}>الخيارات (كل خيار في سطر)</label>
                <textarea rows={4} value={qModal.options}
                  onChange={e => setQModal(p => ({ ...p, options: e.target.value }))}
                  style={inputStyle} placeholder={'خيار أول\nخيار ثاني\nخيار ثالث'} />
              </>
            )}

            <label style={labelStyle}>الترتيب</label>
            <input type="number" min="0" value={qModal.order_index}
              onChange={e => setQModal(p => ({ ...p, order_index: e.target.value }))}
              style={{ ...inputStyle, marginBottom: 24 }} />

            <ModalActions onSave={saveQuestion} onCancel={() => setQModal(null)} saving={saving} />
          </Modal>
        )}

        {/* Set Edit Modal (re-used) */}
        {setModal && (
          <SetModal modal={setModal} setModal={setSetModal} onSave={saveSet} saving={saving} />
        )}
      </div>
    );
  }

  // ── Sets list view ──
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 700 }}>قاعة الاستبيانات</h1>
          <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>استبيانات قبل وأثناء وبعد الجلسة — العميل يختار ويملأ</p>
        </div>
        <button
          onClick={() => setSetModal({ ...EMPTY_SET })}
          style={{ padding: '10px 20px', background: '#1A6B72', color: '#fff', border: 'none', borderRadius: 10, fontSize: 14, fontWeight: 600, cursor: 'pointer' }}
        >
          + إضافة استبيان
        </button>
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', padding: 40, color: '#8A94A6' }}>جاري التحميل...</div>
      ) : sets.length === 0 ? (
        <div className="card" style={{ textAlign: 'center', padding: 48, color: '#8A94A6' }}>
          لا توجد استبيانات — اضغط "+ إضافة استبيان" للبدء
        </div>
      ) : (
        <>
          {/* Group by timing */}
          {['before', 'during', 'after', 'general'].map(timing => {
            const group = sets.filter(s => (s.timing || 'general') === timing);
            if (group.length === 0) return null;
            return (
              <div key={timing} style={{ marginBottom: 28 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                  <span style={{ width: 10, height: 10, borderRadius: '50%', background: TIMING_COLORS[timing], display: 'inline-block' }} />
                  <h2 style={{ fontSize: 15, fontWeight: 700, color: '#333', margin: 0 }}>{TIMING_LABELS[timing]}</h2>
                  <span style={{ fontSize: 12, color: '#8A94A6' }}>{group.length} استبيانات</span>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: 14 }}>
                  {group.map((set) => (
                    <div key={set.id} className="card" style={{ opacity: set.is_active ? 1 : 0.55, cursor: 'pointer', transition: 'box-shadow 0.2s' }}
                      onClick={() => openSet(set)}
                      onMouseEnter={e => e.currentTarget.style.boxShadow = '0 4px 16px rgba(26,107,114,0.15)'}
                      onMouseLeave={e => e.currentTarget.style.boxShadow = ''}>
                      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 8 }}>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontWeight: 700, fontSize: 15, marginBottom: 6 }}>{set.name}</div>
                          {set.description && (
                            <div style={{ fontSize: 13, color: '#8A94A6', marginBottom: 8 }}>{set.description}</div>
                          )}
                          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                            <span style={{ padding: '2px 10px', borderRadius: 12, fontSize: 12, background: '#1A6B7215', color: '#1A6B72', fontWeight: 600 }}>
                              {set.question_count || 0} سؤال
                            </span>
                            {set.specialization && (
                              <span style={{ padding: '2px 10px', borderRadius: 12, fontSize: 12, background: '#F5A62315', color: '#F5A623', fontWeight: 600 }}>
                                {set.specialization}
                              </span>
                            )}
                            {!set.specialization && (
                              <span style={{ padding: '2px 10px', borderRadius: 12, fontSize: 12, background: '#8A94A615', color: '#8A94A6' }}>
                                للكل
                              </span>
                            )}
                          </div>
                        </div>
                      </div>
                      <div style={{ display: 'flex', gap: 8, marginTop: 14, borderTop: '1px solid #f0f0f0', paddingTop: 12 }}
                        onClick={e => e.stopPropagation()}>
                        <button onClick={() => toggleSet(set)} style={{ flex: 1, padding: '5px 0', borderRadius: 6, border: `1px solid ${set.is_active ? '#E53935' : '#2ECC71'}`, background: 'none', color: set.is_active ? '#E53935' : '#2ECC71', fontSize: 12, cursor: 'pointer' }}>
                          {set.is_active ? 'تعطيل' : 'تفعيل'}
                        </button>
                        <button onClick={() => setSetModal({ ...set, specialization: set.specialization || '' })} style={{ flex: 1, padding: '5px 0', borderRadius: 6, border: '1px solid #1A6B72', background: 'none', color: '#1A6B72', fontSize: 12, cursor: 'pointer' }}>
                          تعديل
                        </button>
                        <button onClick={() => removeSet(set.id)} style={{ flex: 1, padding: '5px 0', borderRadius: 6, border: '1px solid #E53935', background: 'none', color: '#E53935', fontSize: 12, cursor: 'pointer' }}>
                          حذف
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })}
        </>
      )}

      {setModal && (
        <SetModal modal={setModal} setModal={setSetModal} onSave={saveSet} saving={saving} />
      )}
    </div>
  );
}

// ── Reusable sub-components ──

const labelStyle = { fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 6 };
const inputStyle = { width: '100%', padding: '10px 12px', border: '1px solid #E0E0E0', borderRadius: 8, fontSize: 14, marginBottom: 16, boxSizing: 'border-box' };

function SetModal({ modal, setModal, onSave, saving }) {
  return (
    <Modal title={modal.id ? 'تعديل الاستبيان' : 'استبيان جديد'} onClose={() => setModal(null)}>
      <label style={labelStyle}>اسم الاستبيان</label>
      <input value={modal.name}
        onChange={e => setModal(p => ({ ...p, name: e.target.value }))}
        style={inputStyle} placeholder="مثال: استبيان ما قبل الجلسة" />

      <label style={labelStyle}>وصف (اختياري)</label>
      <input value={modal.description}
        onChange={e => setModal(p => ({ ...p, description: e.target.value }))}
        style={inputStyle} placeholder="وصف مختصر للاستبيان" />

      <label style={labelStyle}>التوقيت</label>
      <select value={modal.timing}
        onChange={e => setModal(p => ({ ...p, timing: e.target.value }))}
        style={inputStyle}>
        <option value="before">قبل الجلسة</option>
        <option value="during">أثناء الجلسة</option>
        <option value="after">بعد الجلسة</option>
        <option value="general">عام</option>
      </select>

      <label style={labelStyle}>التخصص</label>
      <select value={modal.specialization}
        onChange={e => setModal(p => ({ ...p, specialization: e.target.value === 'للكل' ? '' : e.target.value }))}
        style={inputStyle}>
        {['للكل', 'كوتش مالي', 'كوتش صحي', 'كوتش مهني', 'كوتش تعليمي', 'كوتش إداري', 'كوتش علاقات', 'كوتش حياة'].map(s => (
          <option key={s} value={s === 'للكل' ? '' : s}>{s}</option>
        ))}
      </select>

      <ModalActions onSave={onSave} onCancel={() => setModal(null)} saving={saving} />
    </Modal>
  );
}

function Modal({ title, onClose, children }) {
  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
      <div style={{ background: '#fff', borderRadius: 16, padding: 32, width: 460, direction: 'rtl', maxHeight: '90vh', overflowY: 'auto' }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 24 }}>{title}</h2>
        {children}
      </div>
    </div>
  );
}

function ModalActions({ onSave, onCancel, saving }) {
  return (
    <div style={{ display: 'flex', gap: 10 }}>
      <button onClick={onSave} disabled={saving}
        style={{ flex: 1, padding: '10px 0', background: '#1A6B72', color: '#fff', border: 'none', borderRadius: 10, fontSize: 14, fontWeight: 600, cursor: 'pointer' }}>
        {saving ? 'جاري الحفظ...' : 'حفظ'}
      </button>
      <button onClick={onCancel}
        style={{ flex: 1, padding: '10px 0', background: '#f5f5f5', color: '#333', border: 'none', borderRadius: 10, fontSize: 14, cursor: 'pointer' }}>
        إلغاء
      </button>
    </div>
  );
}
