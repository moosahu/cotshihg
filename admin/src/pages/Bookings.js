import React, { useState, useEffect } from 'react';
import DataTable from '../components/DataTable';
import api from '../services/api';
import toast from 'react-hot-toast';

const statusColors = { completed: '#2ECC71', confirmed: '#1A6B72', pending: '#F5A623', cancelled: '#E53935', in_progress: '#FF6B35' };
const statusLabels = { completed: 'مكتملة', confirmed: 'مؤكدة', pending: 'معلق', cancelled: 'ملغية', in_progress: 'جارية' };
const typeLabels = { video: 'فيديو', voice: 'صوتي', chat: 'دردشة' };

// ── Slot generation (same logic as Flutter booking page) ──────────────────────
function generateSlots(availability, bookedSlots) {
  const slotsSet = {};
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  function pad(n) { return String(n).padStart(2, '0'); }
  function dateKey(d) { return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`; }

  function addTimeRange(dk, startRaw, endRaw) {
    const [sh0, sm0] = startRaw.substring(0, 5).split(':').map(Number);
    const [eh, em] = endRaw.substring(0, 5).split(':').map(Number);
    let sh = sh0, sm = sm0;
    while (sh * 60 + sm + 60 <= eh * 60 + em) {
      if (!slotsSet[dk]) slotsSet[dk] = new Set();
      slotsSet[dk].add(`${pad(sh)}:${pad(sm)}`);
      sm += 60;
      if (sm >= 60) { sh += Math.floor(sm / 60); sm = sm % 60; }
    }
  }

  // 1. Specific-date slots
  for (const a of availability) {
    if (a.specific_date) {
      const parsed = new Date(a.specific_date);
      const dateObj = new Date(parsed.getFullYear(), parsed.getMonth(), parsed.getDate());
      if (dateObj < today) continue;
      const dk = dateKey(dateObj);
      addTimeRange(dk, a.start_time, a.end_time);
    }
  }

  // 2. Recurring day-of-week slots for next 30 days
  for (let i = 1; i <= 30; i++) {
    const date = new Date(now);
    date.setDate(now.getDate() + i);
    const dow = date.getDay(); // 0=Sun
    const dk = dateKey(date);
    if (slotsSet[dk]) continue; // specific-date takes priority
    const matching = availability.filter(a => !a.specific_date && a.day_of_week === dow);
    for (const a of matching) addTimeRange(dk, a.start_time, a.end_time);
  }

  // Convert sets to sorted arrays and filter out booked
  const result = {};
  for (const [dk, times] of Object.entries(slotsSet)) {
    const filtered = [...times].filter(t => !bookedSlots.has(`${dk}|${t}`)).sort();
    if (filtered.length > 0) result[dk] = filtered;
  }
  return result;
}

// ── Create Booking Modal ──────────────────────────────────────────────────────
function CreateBookingModal({ onClose, onCreated }) {
  const [clients, setClients] = useState([]);
  const [coaches, setCoaches] = useState([]);
  const [clientId, setClientId] = useState('');
  const [coachId, setCoachId] = useState('');
  const [slotsByDate, setSlotsByDate] = useState({});
  const [selectedDate, setSelectedDate] = useState('');
  const [selectedTime, setSelectedTime] = useState('');
  const [sessionType, setSessionType] = useState('video');
  const [price, setPrice] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('app');
  const [loadingSlots, setLoadingSlots] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [coachData, setCoachData] = useState(null);

  useEffect(() => {
    Promise.all([api.getUsers(), api.getTherapists()]).then(([u, t]) => {
      setClients((u.data || []).filter(u => u.role === 'client'));
      setCoaches(t.data || []);
    }).catch(() => {});
  }, []);

  const handleCoachChange = async (id) => {
    setCoachId(id);
    setSlotsByDate({});
    setSelectedDate('');
    setSelectedTime('');
    setPrice('');
    setCoachData(null);
    if (!id) return;

    setLoadingSlots(true);
    try {
      const coach = coaches.find(c => c.therapist_id === id || c.id === id);
      setCoachData(coach);

      const [availRes, bookedRes] = await Promise.all([
        api.getCoachAvailability(id),
        api.getCoachBookedSlots(id),
      ]);
      const avail = availRes.data || [];
      const bookedRaw = bookedRes.data || [];

      const bookedSet = new Set();
      for (const slot of bookedRaw) {
        const dt = new Date(slot);
        const pad = n => String(n).padStart(2, '0');
        const dk = `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())}`;
        const tk = `${pad(dt.getHours())}:${pad(dt.getMinutes())}`;
        bookedSet.add(`${dk}|${tk}`);
      }

      setSlotsByDate(generateSlots(avail, bookedSet));
    } catch {
      toast.error('تعذّر تحميل المواعيد');
    } finally {
      setLoadingSlots(false);
    }
  };

  const handleDateChange = (date) => {
    setSelectedDate(date);
    setSelectedTime('');
  };

  const handleSessionTypeChange = (type) => {
    setSessionType(type);
    if (coachData) {
      const priceMap = {
        video: coachData.session_price_video,
        voice: coachData.session_price_voice,
        chat: coachData.session_price_chat,
      };
      setPrice(priceMap[type] || coachData.session_price || '');
    }
  };

  // Pre-fill price when coach and type both set
  useEffect(() => {
    if (!coachData) return;
    const priceMap = {
      video: coachData.session_price_video,
      voice: coachData.session_price_voice,
      chat: coachData.session_price_chat,
    };
    setPrice(priceMap[sessionType] || coachData.session_price || '');
  }, [coachData, sessionType]);

  const handleSubmit = async () => {
    if (!clientId || !coachId || !selectedDate || !selectedTime || !sessionType || !price || !paymentMethod) {
      toast.error('يرجى تعبئة جميع الحقول');
      return;
    }
    setSubmitting(true);
    try {
      const scheduledAt = new Date(`${selectedDate}T${selectedTime}:00`).toISOString();
      await api.createBooking({ client_id: clientId, therapist_id: coachId, scheduled_at: scheduledAt, session_type: sessionType, price: parseFloat(price), payment_method: paymentMethod });
      toast.success('تم إنشاء الحجز بنجاح');
      onCreated();
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSubmitting(false);
    }
  };

  const availableDates = Object.keys(slotsByDate).sort();

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
      <div style={{ background: '#fff', borderRadius: 16, padding: 32, width: 520, maxHeight: '90vh', overflowY: 'auto', direction: 'rtl' }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 24 }}>إنشاء حجز جديد</h2>

        {/* Client */}
        <label style={labelStyle}>العميل</label>
        <select style={selectStyle} value={clientId} onChange={e => setClientId(e.target.value)}>
          <option value=''>اختر عميلاً...</option>
          {clients.map(c => <option key={c.id} value={c.id}>{c.name} — {c.email}</option>)}
        </select>

        {/* Coach */}
        <label style={labelStyle}>الكوتش</label>
        <select style={selectStyle} value={coachId} onChange={e => handleCoachChange(e.target.value)}>
          <option value=''>اختر كوتشاً...</option>
          {coaches.map(c => <option key={c.therapist_id || c.id} value={c.therapist_id || c.id}>{c.name}</option>)}
        </select>

        {/* Session type */}
        <label style={labelStyle}>نوع الجلسة</label>
        <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
          {['video', 'voice', 'chat'].map(t => (
            <button key={t} onClick={() => handleSessionTypeChange(t)}
              style={{ flex: 1, padding: '8px 0', borderRadius: 8, border: `2px solid ${sessionType === t ? '#1A6B72' : '#E5E7EB'}`, background: sessionType === t ? '#1A6B72' : '#fff', color: sessionType === t ? '#fff' : '#374151', fontWeight: 600, cursor: 'pointer', fontSize: 13 }}>
              {typeLabels[t]}
            </button>
          ))}
        </div>

        {/* Slots */}
        {coachId && (
          loadingSlots
            ? <p style={{ color: '#8A94A6', fontSize: 13, marginBottom: 16 }}>جاري تحميل المواعيد...</p>
            : availableDates.length === 0
              ? <p style={{ color: '#E53935', fontSize: 13, marginBottom: 16 }}>لا توجد مواعيد متاحة لهذا الكوتش</p>
              : <>
                <label style={labelStyle}>التاريخ</label>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 16 }}>
                  {availableDates.map(d => (
                    <button key={d} onClick={() => handleDateChange(d)}
                      style={{ padding: '6px 12px', borderRadius: 8, border: `2px solid ${selectedDate === d ? '#1A6B72' : '#E5E7EB'}`, background: selectedDate === d ? '#1A6B72' : '#fff', color: selectedDate === d ? '#fff' : '#374151', cursor: 'pointer', fontSize: 12, fontWeight: 600 }}>
                      {d}
                    </button>
                  ))}
                </div>

                {selectedDate && <>
                  <label style={labelStyle}>الوقت</label>
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 16 }}>
                    {(slotsByDate[selectedDate] || []).map(t => (
                      <button key={t} onClick={() => setSelectedTime(t)}
                        style={{ padding: '6px 14px', borderRadius: 8, border: `2px solid ${selectedTime === t ? '#1A6B72' : '#E5E7EB'}`, background: selectedTime === t ? '#1A6B72' : '#fff', color: selectedTime === t ? '#fff' : '#374151', cursor: 'pointer', fontSize: 13, fontWeight: 600 }}>
                        {t}
                      </button>
                    ))}
                  </div>
                </>}
              </>
        )}

        {/* Price */}
        <label style={labelStyle}>السعر (ر.س)</label>
        <input type='number' style={inputStyle} value={price} onChange={e => setPrice(e.target.value)} placeholder='0' />

        {/* Payment method */}
        <label style={labelStyle}>طريقة الدفع</label>
        <div style={{ display: 'flex', gap: 8, marginBottom: 24 }}>
          <button onClick={() => setPaymentMethod('app')}
            style={{ flex: 1, padding: '10px 0', borderRadius: 8, border: `2px solid ${paymentMethod === 'app' ? '#1A6B72' : '#E5E7EB'}`, background: paymentMethod === 'app' ? '#1A6B72' : '#fff', color: paymentMethod === 'app' ? '#fff' : '#374151', fontWeight: 600, cursor: 'pointer', fontSize: 13 }}>
            عبر التطبيق
          </button>
          <button onClick={() => setPaymentMethod('manual')}
            style={{ flex: 1, padding: '10px 0', borderRadius: 8, border: `2px solid ${paymentMethod === 'manual' ? '#1A6B72' : '#E5E7EB'}`, background: paymentMethod === 'manual' ? '#1A6B72' : '#fff', color: paymentMethod === 'manual' ? '#fff' : '#374151', fontWeight: 600, cursor: 'pointer', fontSize: 13 }}>
            يدوي (كاش/تحويل)
          </button>
        </div>

        {paymentMethod === 'app' && (
          <p style={{ fontSize: 12, color: '#F5A623', background: '#FFF8E7', padding: '8px 12px', borderRadius: 8, marginBottom: 16 }}>
            سيُشعَر العميل بإتمام الدفع عبر التطبيق
          </p>
        )}
        {paymentMethod === 'manual' && (
          <p style={{ fontSize: 12, color: '#2ECC71', background: '#F0FFF4', padding: '8px 12px', borderRadius: 8, marginBottom: 16 }}>
            الحجز سيُؤكَّد فوراً — تأكد من استلام الدفع
          </p>
        )}

        {/* Actions */}
        <div style={{ display: 'flex', gap: 8 }}>
          <button onClick={handleSubmit} disabled={submitting}
            style={{ flex: 1, padding: '12px 0', borderRadius: 10, background: '#1A6B72', color: '#fff', fontWeight: 700, fontSize: 14, border: 'none', cursor: submitting ? 'not-allowed' : 'pointer', opacity: submitting ? 0.7 : 1 }}>
            {submitting ? 'جاري الإنشاء...' : 'إنشاء الحجز'}
          </button>
          <button onClick={onClose}
            style={{ padding: '12px 20px', borderRadius: 10, background: '#F3F4F6', color: '#374151', fontWeight: 600, fontSize: 14, border: 'none', cursor: 'pointer' }}>
            إلغاء
          </button>
        </div>
      </div>
    </div>
  );
}

const labelStyle = { display: 'block', fontSize: 13, fontWeight: 600, color: '#374151', marginBottom: 6 };
const selectStyle = { width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid #E5E7EB', fontSize: 13, marginBottom: 16, direction: 'rtl' };
const inputStyle = { width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid #E5E7EB', fontSize: 13, marginBottom: 16, boxSizing: 'border-box' };

// ── Main Page ─────────────────────────────────────────────────────────────────
export default function Bookings() {
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);

  const load = () => {
    setLoading(true);
    api.getBookings()
      .then(res => setBookings(res.data || []))
      .catch(err => toast.error(err.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const handleCancel = async (id, isPaid) => {
    if (isPaid) {
      const choice = window.confirm(
        'هذا الحجز مدفوع — هل تريد استرداد المبلغ للعميل أيضاً؟\n\nاضغط "موافق" لإلغاء الحجز واسترداد المبلغ.\nاضغط "إلغاء" لإلغاء الحجز فقط بدون استرداد.'
      );
      // choice = true → cancel + refund, false → cancel only
      try {
        await api.cancelBooking(id, choice);
        toast.success(choice ? 'تم إلغاء الحجز واسترداد المبلغ ✓' : 'تم إلغاء الحجز بدون استرداد');
        load();
      } catch (err) {
        toast.error(err.message);
      }
    } else {
      if (!window.confirm('هل تريد إلغاء هذا الحجز؟')) return;
      try {
        await api.cancelBooking(id, false);
        toast.success('تم إلغاء الحجز');
        load();
      } catch (err) {
        toast.error(err.message);
      }
    }
  };

  const canCancel = (status) => ['pending', 'confirmed', 'in_progress'].includes(status);

  const columns = [
    { key: 'id', label: 'رقم الحجز', render: v => v ? v.slice(0, 8).toUpperCase() : '—' },
    { key: 'client_name', label: 'العميل', render: v => v || '—' },
    { key: 'therapist_name', label: 'الكوتش', render: v => v || '—' },
    { key: 'session_type', label: 'النوع', render: v => typeLabels[v] || v || '—' },
    {
      key: 'scheduled_at', label: 'التاريخ',
      render: v => v ? new Date(v).toLocaleDateString('ar-SA') : '—'
    },
    { key: 'price', label: <span>المبلغ <i className="icon-saudi_riyal_new" /></span>, render: v => v ? <span>{v} <i className="icon-saudi_riyal_new" /></span> : '—' },
    {
      key: 'payment_status', label: 'الدفع',
      render: (v, row) => {
        if (!v || v === 'pending') return <span style={{ color: '#8A94A6', fontSize: 12 }}>غير مدفوع</span>;
        const colors = { paid: '#2ECC71', refunded: '#9C27B0', failed: '#E53935' };
        const labels = { paid: 'مدفوع', refunded: 'مسترد', failed: 'فاشل' };
        return (
          <span style={{ padding: '3px 8px', borderRadius: 6, fontSize: 11, fontWeight: 600, background: `${colors[v] || '#8A94A6'}20`, color: colors[v] || '#8A94A6' }}>
            {labels[v] || v}
            {v === 'paid' && row.price ? ` · ${row.price}` : ''}
          </span>
        );
      }
    },
    {
      key: 'status', label: 'الحالة',
      render: v => (
        <span style={{ padding: '4px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, background: `${statusColors[v] || '#8A94A6'}20`, color: statusColors[v] || '#8A94A6' }}>
          {statusLabels[v] || v}
        </span>
      )
    },
    {
      key: 'id', label: 'إجراء',
      render: (id, row) => canCancel(row.status) ? (
        <button
          onClick={() => handleCancel(id, row.payment_status === 'paid')}
          style={{ padding: '4px 12px', borderRadius: 6, border: '1px solid #E53935', background: 'transparent', color: '#E53935', cursor: 'pointer', fontSize: 12, fontWeight: 600 }}
        >
          إلغاء
        </button>
      ) : '—'
    },
  ];

  if (loading) return <div style={{ padding: 40, textAlign: 'center', color: '#8A94A6' }}>جاري التحميل...</div>;

  return (
    <div>
      <div style={{ marginBottom: 24, display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 700 }}>الجلسات</h1>
          <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>عرض وإدارة جميع الجلسات</p>
        </div>
        <button
          onClick={() => setShowCreate(true)}
          style={{ padding: '10px 20px', borderRadius: 10, background: '#1A6B72', color: '#fff', fontWeight: 700, fontSize: 14, border: 'none', cursor: 'pointer' }}
        >
          + حجز جديد
        </button>
      </div>
      <DataTable title={`إجمالي الجلسات: ${bookings.length}`} columns={columns} data={bookings} />
      {showCreate && (
        <CreateBookingModal
          onClose={() => setShowCreate(false)}
          onCreated={() => { setShowCreate(false); load(); }}
        />
      )}
    </div>
  );
}
