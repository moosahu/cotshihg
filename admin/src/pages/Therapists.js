import React, { useState, useEffect } from 'react';
import DataTable from '../components/DataTable';
import api from '../services/api';
import toast from 'react-hot-toast';

export default function Therapists() {
  const [therapists, setTherapists] = useState([]);
  const [loading, setLoading] = useState(true);
  const [pricingModal, setPricingModal] = useState(null);
  const [savingPrice, setSavingPrice] = useState(false);
  const [discountModal, setDiscountModal] = useState(null); // { therapistId, name, discount }
  const [savingDiscount, setSavingDiscount] = useState(false);

  useEffect(() => {
    api.getTherapists()
      .then(res => setTherapists(res.data || []))
      .catch(err => toast.error(err.message))
      .finally(() => setLoading(false));
  }, []);

  const handleApprove = async (therapistId, name) => {
    try {
      const res = await api.toggleApproveTherapist(therapistId);
      setTherapists(prev => prev.map(t =>
        t.therapist_id === therapistId ? { ...t, is_approved: res.data.is_approved } : t
      ));
      toast.success(`تم ${res.data.is_approved ? 'اعتماد' : 'إيقاف'} ${name}`);
    } catch (err) {
      toast.error(err.message);
    }
  };

  const openDiscount = (row) => {
    setDiscountModal({
      therapistId: row.therapist_id,
      name: row.name,
      discount: row.discount_percent ?? 0,
    });
  };

  const saveDiscount = async () => {
    setSavingDiscount(true);
    try {
      await api.updateTherapistDiscount(discountModal.therapistId, {
        discount_percent: parseInt(discountModal.discount) || 0,
      });
      setTherapists(prev => prev.map(t =>
        t.therapist_id === discountModal.therapistId
          ? { ...t, discount_percent: discountModal.discount }
          : t
      ));
      toast.success('تم تحديث الخصم');
      setDiscountModal(null);
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSavingDiscount(false);
    }
  };

  const openPricing = (row) => {
    setPricingModal({
      therapistId: row.therapist_id,
      name: row.name,
      chat: row.session_price_chat ?? '',
      voice: row.session_price_voice ?? '',
      video: row.session_price_video ?? '',
    });
  };

  const savePricing = async () => {
    setSavingPrice(true);
    try {
      await api.updateTherapistPricing(pricingModal.therapistId, {
        session_price_chat: parseFloat(pricingModal.chat) || 0,
        session_price_voice: parseFloat(pricingModal.voice) || 0,
        session_price_video: parseFloat(pricingModal.video) || 0,
      });
      setTherapists(prev => prev.map(t =>
        t.therapist_id === pricingModal.therapistId
          ? { ...t, session_price_chat: pricingModal.chat, session_price_voice: pricingModal.voice, session_price_video: pricingModal.video }
          : t
      ));
      toast.success('تم تحديث الأسعار');
      setPricingModal(null);
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSavingPrice(false);
    }
  };

  const columns = [
    { key: 'name', label: 'الاسم', render: v => v || '—' },
    { key: 'phone', label: 'الجوال' },
    {
      key: 'specializations', label: 'التخصص',
      render: v => Array.isArray(v) && v.length > 0 ? v[0] : '—'
    },
    { key: 'total_sessions', label: 'الجلسات', render: v => v ?? 0 },
    { key: 'rating', label: 'التقييم', render: v => v ? `⭐ ${parseFloat(v).toFixed(1)}` : '—' },
    {
      key: 'discount_percent', label: 'الخصم',
      render: v => v > 0
        ? <span style={{ padding: '3px 10px', borderRadius: 8, background: '#fff3e0', color: '#e65100', fontWeight: 700, fontSize: 13 }}>{v}% خصم</span>
        : <span style={{ color: '#ccc', fontSize: 13 }}>لا يوجد</span>
    },
    {
      key: 'session_price_video', label: 'الأسعار (ر.س)',
      render: (v, row) => (
        <div style={{ fontSize: 12, lineHeight: 1.8 }}>
          <div>📹 فيديو: <b>{row.session_price_video ?? '—'}</b></div>
          <div>🎙 صوتي: <b>{row.session_price_voice ?? '—'}</b></div>
          <div>💬 نصي: <b>{row.session_price_chat ?? '—'}</b></div>
        </div>
      )
    },
    {
      key: 'is_approved', label: 'الحالة',
      render: v => (
        <span style={{ padding: '4px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, background: v ? '#e8f8ee' : '#fff8e1', color: v ? '#2ECC71' : '#F5A623' }}>
          {v ? 'معتمد' : 'قيد المراجعة'}
        </span>
      )
    },
    {
      key: 'actions', label: 'إجراءات',
      render: (_, row) => row.therapist_id ? (
        <div style={{ display: 'flex', gap: 6 }}>
          <button
            onClick={() => handleApprove(row.therapist_id, row.name)}
            style={{ padding: '5px 10px', borderRadius: 8, border: `1px solid ${row.is_approved ? '#E53935' : '#2ECC71'}`, background: 'none', color: row.is_approved ? '#E53935' : '#2ECC71', fontSize: 12, cursor: 'pointer' }}
          >
            {row.is_approved ? 'إيقاف' : 'اعتماد'}
          </button>
          <button
            onClick={() => openPricing(row)}
            style={{ padding: '5px 10px', borderRadius: 8, border: '1px solid #1A6B72', background: 'none', color: '#1A6B72', fontSize: 12, cursor: 'pointer' }}
          >
            💰 الأسعار
          </button>
          <button
            onClick={() => openDiscount(row)}
            style={{ padding: '5px 10px', borderRadius: 8, border: '1px solid #e65100', background: 'none', color: '#e65100', fontSize: 12, cursor: 'pointer' }}
          >
            🏷️ خصم
          </button>
        </div>
      ) : <span style={{ color: '#8A94A6', fontSize: 12 }}>لم يكمل الملف</span>
    },
  ];

  if (loading) return <div style={{ padding: 40, textAlign: 'center', color: '#8A94A6' }}>جاري التحميل...</div>;

  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>الكوتشز</h1>
        <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>إدارة واعتماد الكوتشز وتحديد أسعار الجلسات</p>
      </div>
      <DataTable title={`إجمالي الكوتشز: ${therapists.length}`} columns={columns} data={therapists} />

      {/* Discount Modal */}
      {discountModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: '#fff', borderRadius: 16, padding: 32, width: 340, direction: 'rtl' }}>
            <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 4 }}>تحديد نسبة الخصم</h2>
            <p style={{ color: '#8A94A6', fontSize: 13, marginBottom: 24 }}>{discountModal.name}</p>
            <label style={{ fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 8 }}>نسبة الخصم %</label>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}>
              <input
                type="number"
                min="0"
                max="100"
                value={discountModal.discount}
                onChange={e => setDiscountModal(prev => ({ ...prev, discount: e.target.value }))}
                style={{ flex: 1, padding: '10px 14px', border: '1px solid #E0E0E0', borderRadius: 8, fontSize: 18, fontWeight: 700, textAlign: 'center' }}
              />
              <span style={{ fontSize: 22, color: '#e65100', fontWeight: 700 }}>%</span>
            </div>
            <p style={{ color: '#8A94A6', fontSize: 12, marginBottom: 24 }}>
              {discountModal.discount > 0 ? `العميل يدفع ${100 - parseInt(discountModal.discount)}% من السعر الأصلي` : 'لا يوجد خصم حالياً'}
            </p>
            <div style={{ display: 'flex', gap: 10 }}>
              <button
                onClick={saveDiscount}
                disabled={savingDiscount}
                style={{ flex: 1, padding: '10px 0', background: '#e65100', color: '#fff', border: 'none', borderRadius: 10, fontSize: 14, fontWeight: 600, cursor: 'pointer' }}
              >
                {savingDiscount ? 'جاري الحفظ...' : 'حفظ الخصم'}
              </button>
              <button
                onClick={() => setDiscountModal(null)}
                style={{ flex: 1, padding: '10px 0', background: '#f5f5f5', color: '#333', border: 'none', borderRadius: 10, fontSize: 14, cursor: 'pointer' }}
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Pricing Modal */}
      {pricingModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div style={{ background: '#fff', borderRadius: 16, padding: 32, width: 360, direction: 'rtl' }}>
            <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 4 }}>تحديد أسعار الجلسات</h2>
            <p style={{ color: '#8A94A6', fontSize: 13, marginBottom: 24 }}>{pricingModal.name}</p>

            {[
              { key: 'video', label: '📹 مكالمة فيديو', field: 'video' },
              { key: 'voice', label: '🎙 مكالمة صوتية', field: 'voice' },
              { key: 'chat', label: '💬 محادثة نصية', field: 'chat' },
            ].map(({ key, label, field }) => (
              <div key={key} style={{ marginBottom: 16 }}>
                <label style={{ fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 6 }}>{label}</label>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <input
                    type="number"
                    min="0"
                    value={pricingModal[field]}
                    onChange={e => setPricingModal(prev => ({ ...prev, [field]: e.target.value }))}
                    style={{ flex: 1, padding: '8px 12px', border: '1px solid #E0E0E0', borderRadius: 8, fontSize: 14, textAlign: 'right' }}
                    placeholder="0"
                  />
                  <span style={{ color: '#8A94A6', fontSize: 13 }}>ر.س</span>
                </div>
              </div>
            ))}

            <div style={{ display: 'flex', gap: 10, marginTop: 24 }}>
              <button
                onClick={savePricing}
                disabled={savingPrice}
                style={{ flex: 1, padding: '10px 0', background: '#1A6B72', color: '#fff', border: 'none', borderRadius: 10, fontSize: 14, fontWeight: 600, cursor: 'pointer' }}
              >
                {savingPrice ? 'جاري الحفظ...' : 'حفظ الأسعار'}
              </button>
              <button
                onClick={() => setPricingModal(null)}
                style={{ flex: 1, padding: '10px 0', background: '#f5f5f5', color: '#333', border: 'none', borderRadius: 10, fontSize: 14, cursor: 'pointer' }}
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
