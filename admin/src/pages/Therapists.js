import React, { useState, useEffect } from 'react';
import DataTable from '../components/DataTable';
import api from '../services/api';
import toast from 'react-hot-toast';

export default function Therapists() {
  const [therapists, setTherapists] = useState([]);
  const [loading, setLoading] = useState(true);

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

  const columns = [
    { key: 'name', label: 'الاسم', render: v => v || '—' },
    { key: 'phone', label: 'الجوال' },
    {
      key: 'specializations', label: 'التخصص',
      render: v => Array.isArray(v) && v.length > 0 ? v[0] : '—'
    },
    { key: 'total_sessions', label: 'الجلسات', render: v => v ?? 0 },
    { key: 'rating', label: 'التقييم', render: v => v ? `⭐ ${parseFloat(v).toFixed(1)}` : '—' },
    { key: 'price', label: 'السعر (ر.س)', render: v => v ?? '—' },
    {
      key: 'is_approved', label: 'الحالة',
      render: v => (
        <span style={{ padding: '4px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, background: v ? '#e8f8ee' : '#fff8e1', color: v ? '#2ECC71' : '#F5A623' }}>
          {v ? 'معتمد' : 'قيد المراجعة'}
        </span>
      )
    },
    {
      key: 'actions', label: 'إجراء',
      render: (_, row) => row.therapist_id ? (
        <button
          onClick={() => handleApprove(row.therapist_id, row.name)}
          style={{ padding: '6px 12px', borderRadius: 8, border: `1px solid ${row.is_approved ? '#E53935' : '#2ECC71'}`, background: 'none', color: row.is_approved ? '#E53935' : '#2ECC71', fontSize: 12, cursor: 'pointer' }}
        >
          {row.is_approved ? 'إيقاف' : 'اعتماد'}
        </button>
      ) : <span style={{ color: '#8A94A6', fontSize: 12 }}>لم يكمل الملف</span>
    },
  ];

  if (loading) return <div style={{ padding: 40, textAlign: 'center', color: '#8A94A6' }}>جاري التحميل...</div>;

  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>الكوتشز</h1>
        <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>إدارة واعتماد الكوتشز</p>
      </div>
      <DataTable title={`إجمالي الكوتشز: ${therapists.length}`} columns={columns} data={therapists} />
    </div>
  );
}
