import React from 'react';
import DataTable from '../components/DataTable';
import StatCard from '../components/StatCard';

const mockPayments = Array.from({ length: 25 }, (_, i) => ({
  id: `PAY${String(i + 1).padStart(5, '0')}`,
  user: ['أحمد محمد', 'سارة علي', 'خالد أحمد', 'نورة سالم'][i % 4],
  amount: [150, 200, 250, 300][i % 4],
  method: ['مدى', 'فيزا', 'أبل باي'][i % 3],
  date: `2024-0${(i % 9) + 1}-${String((i % 28) + 1).padStart(2, '0')}`,
  status: i % 8 === 0 ? 'مسترد' : 'ناجح',
}));

const columns = [
  { key: 'id', label: 'رقم العملية' },
  { key: 'user', label: 'المستخدم' },
  { key: 'amount', label: 'المبلغ (ر.س)' },
  { key: 'method', label: 'طريقة الدفع' },
  { key: 'date', label: 'التاريخ' },
  {
    key: 'status', label: 'الحالة',
    render: v => <span style={{ padding: '4px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, background: v === 'ناجح' ? '#e8f8ee' : '#fdecea', color: v === 'ناجح' ? '#2ECC71' : '#E53935' }}>{v}</span>
  },
];

export default function Payments() {
  const total = mockPayments.filter(p => p.status === 'ناجح').reduce((s, p) => s + p.amount, 0);

  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>المدفوعات</h1>
        <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>سجل جميع المعاملات المالية</p>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard title="إجمالي الإيرادات" value={`${total.toLocaleString()} ر.س`} change={12.5} icon="💰" color="#1A6B72" />
        <StatCard title="المعاملات الناجحة" value={String(mockPayments.filter(p => p.status === 'ناجح').length)} change={5.2} icon="✅" color="#2ECC71" />
        <StatCard title="المبالغ المستردة" value={String(mockPayments.filter(p => p.status === 'مسترد').length)} change={-2.1} icon="↩️" color="#E53935" />
      </div>
      <DataTable title="سجل المعاملات" columns={columns} data={mockPayments} />
    </div>
  );
}
