import React, { useState, useEffect } from 'react';
import DataTable from '../components/DataTable';
import StatCard from '../components/StatCard';
import api from '../services/api';
import toast from 'react-hot-toast';

export default function Payments() {
  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refunding, setRefunding] = useState(null);

  const load = () => {
    api.getPayments()
      .then(res => setPayments(res.data || []))
      .catch(err => toast.error(err.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const handleRefund = async (id, provider) => {
    const msg = provider === 'manual'
      ? 'هل تريد تأكيد استرداد هذا المبلغ؟ (دفع يدوي — سيُحدَّث السجل فقط)'
      : 'هل تريد استرداد هذا المبلغ عبر Paymob؟';
    if (!window.confirm(msg)) return;
    setRefunding(id);
    try {
      await api.refundPayment(id);
      toast.success('تم استرداد المبلغ بنجاح ✓');
      load();
    } catch (err) {
      toast.error(err.message);
    } finally {
      setRefunding(null);
    }
  };

  const paid = payments.filter(p => p.status === 'paid');
  const totalRevenue = paid.reduce((s, p) => s + parseFloat(p.amount || 0), 0);

  const statusLabel = (s) => {
    const map = { paid: 'مدفوع', pending: 'معلق', failed: 'فاشل', refunded: 'مسترد' };
    return map[s] || s || '—';
  };
  const statusColor = (s) => {
    const colors = { paid: '#e8f8ee', pending: '#fff8e1', failed: '#fdecea', refunded: '#f3e5f5' };
    const text = { paid: '#2ECC71', pending: '#F59E0B', failed: '#E53935', refunded: '#9C27B0' };
    return { background: colors[s] || '#f5f5f5', color: text[s] || '#666' };
  };

  const sessionTypeLabel = (t) => {
    const map = { video: 'فيديو', voice: 'صوتي', chat: 'نصي' };
    return map[t] || t || '—';
  };

  const columns = [
    {
      key: 'id', label: 'رقم العملية',
      render: (v, row) => (
        <div>
          <div style={{ fontFamily: 'monospace', fontSize: 13, fontWeight: 600 }}>
            {v ? v.toString().slice(0, 8).toUpperCase() : '—'}
          </div>
          {row.provider_payment_id && (
            <div style={{ fontSize: 11, color: '#8A94A6', marginTop: 2 }}>
              {row.provider_payment_id.slice(0, 20)}...
            </div>
          )}
        </div>
      )
    },
    { key: 'user_name', label: 'المستخدم', render: v => v || '—' },
    {
      key: 'amount', label: 'المبلغ',
      render: (v, row) => (
        <span style={{ fontWeight: 700, color: '#1A6B72' }}>
          {parseFloat(v || 0).toLocaleString()} <i className="icon-saudi_riyal_new" />
        </span>
      )
    },
    {
      key: 'provider', label: 'طريقة الدفع',
      render: v => (
        <span style={{ textTransform: 'capitalize', fontWeight: 600 }}>
          {v === 'paymob' ? '💳 Paymob' : v === 'stripe' ? '💳 Stripe' : v || '—'}
        </span>
      )
    },
    {
      key: 'session_type', label: 'نوع الجلسة',
      render: v => sessionTypeLabel(v)
    },
    {
      key: 'scheduled_at', label: 'موعد الجلسة',
      render: v => v ? new Date(v).toLocaleDateString('ar-SA', { year: 'numeric', month: 'short', day: 'numeric' }) : '—'
    },
    {
      key: 'created_at', label: 'تاريخ الدفع',
      render: v => v ? new Date(v).toLocaleDateString('ar-SA', { year: 'numeric', month: 'short', day: 'numeric' }) : '—'
    },
    {
      key: 'status', label: 'الحالة',
      render: v => (
        <span style={{ padding: '4px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, ...statusColor(v) }}>
          {statusLabel(v)}
        </span>
      )
    },
    {
      key: 'id', label: 'إجراء',
      render: (id, row) => row.status === 'paid' ? (
        <button
          onClick={() => handleRefund(id, row.provider)}
          disabled={refunding === id}
          style={{
            padding: '4px 12px', borderRadius: 6, border: '1px solid #9C27B0',
            background: 'transparent', color: '#9C27B0', cursor: 'pointer',
            fontSize: 12, fontWeight: 600, opacity: refunding === id ? 0.6 : 1
          }}
        >
          {refunding === id ? '...' : 'استرداد'}
        </button>
      ) : '—'
    },
  ];

  if (loading) return <div style={{ padding: 40, textAlign: 'center', color: '#8A94A6' }}>جاري التحميل...</div>;

  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>المدفوعات</h1>
        <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>سجل جميع المعاملات المالية عبر Paymob</p>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard title="إجمالي الإيرادات" value={<span>{totalRevenue.toLocaleString()} <i className="icon-saudi_riyal_new" /></span>} change={null} icon="💰" color="#1A6B72" />
        <StatCard title="المعاملات الناجحة" value={String(paid.length)} change={null} icon="✅" color="#2ECC71" />
        <StatCard title="معلقة" value={String(payments.filter(p => p.status === 'pending').length)} change={null} icon="⏳" color="#F59E0B" />
        <StatCard title="فاشلة" value={String(payments.filter(p => p.status === 'failed').length)} change={null} icon="❌" color="#E53935" />
      </div>
      <DataTable title="سجل المعاملات" columns={columns} data={payments} />
    </div>
  );
}
