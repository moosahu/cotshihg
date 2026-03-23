import React, { useState, useEffect } from 'react';
import DataTable from '../components/DataTable';
import api from '../services/api';
import toast from 'react-hot-toast';

const statusColors = { completed: '#2ECC71', confirmed: '#1A6B72', pending: '#F5A623', cancelled: '#E53935', in_progress: '#FF6B35' };
const statusLabels = { completed: 'مكتملة', confirmed: 'مؤكدة', pending: 'معلقة', cancelled: 'ملغية', in_progress: 'جارية' };
const typeLabels = { video: 'فيديو', voice: 'صوتي', chat: 'دردشة' };

export default function Bookings() {
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);

  const load = () => {
    setLoading(true);
    api.getBookings()
      .then(res => setBookings(res.data || []))
      .catch(err => toast.error(err.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const handleCancel = async (id) => {
    if (!window.confirm('هل تريد إلغاء هذا الحجز؟')) return;
    try {
      await api.cancelBooking(id);
      toast.success('تم إلغاء الحجز');
      load();
    } catch (err) {
      toast.error(err.message);
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
    { key: 'price', label: 'المبلغ (﷼)', render: v => v ?? '—' },
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
          onClick={() => handleCancel(id)}
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
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>الحجوزات</h1>
        <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>عرض وإدارة جميع الحجوزات</p>
      </div>
      <DataTable title={`إجمالي الحجوزات: ${bookings.length}`} columns={columns} data={bookings} />
    </div>
  );
}
