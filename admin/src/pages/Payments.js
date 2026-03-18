import React, { useState, useEffect } from 'react';
import DataTable from '../components/DataTable';
import StatCard from '../components/StatCard';
import api from '../services/api';
import toast from 'react-hot-toast';

export default function Payments() {
  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.getPayments()
      .then(res => setPayments(res.data || []))
      .catch(err => toast.error(err.message))
      .finally(() => setLoading(false));
  }, []);

  const total = payments.filter(p => p.status === 'completed').reduce((s, p) => s + parseFloat(p.amount || 0), 0);

  const columns = [
    { key: 'id', label: 'رقم العملية', render: v => v ? v.slice(0, 8).toUpperCase() : '—' },
    { key: 'user_name', label: 'المستخدم', render: v => v || '—' },
    { key: 'amount', label: 'المبلغ (ر.س)' },
    { key: 'method', label: 'طريقة الدفع', render: v => v || '—' },
    {
      key: 'created_at', label: 'التاريخ',
      render: v => v ? new Date(v).toLocaleDateString('ar-SA') : '—'
    },
    {
      key: 'status', label: 'الحالة',
      render: v => (
        <span style={{ padding: '4px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, background: v === 'completed' ? '#e8f8ee' : '#fdecea', color: v === 'completed' ? '#2ECC71' : '#E53935' }}>
          {v === 'completed' ? 'ناجح' : v === 'refunded' ? 'مسترد' : v || '—'}
        </span>
      )
    },
  ];

  if (loading) return <div style={{ padding: 40, textAlign: 'center', color: '#8A94A6' }}>جاري التحميل...</div>;

  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>المدفوعات</h1>
        <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>سجل جميع المعاملات المالية</p>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard title="إجمالي الإيرادات" value={`${total.toLocaleString()} ر.س`} change={null} icon="💰" color="#1A6B72" />
        <StatCard title="المعاملات الناجحة" value={String(payments.filter(p => p.status === 'completed').length)} change={null} icon="✅" color="#2ECC71" />
        <StatCard title="المبالغ المستردة" value={String(payments.filter(p => p.status === 'refunded').length)} change={null} icon="↩️" color="#E53935" />
      </div>
      <DataTable title="سجل المعاملات" columns={columns} data={payments} />
    </div>
  );
}
