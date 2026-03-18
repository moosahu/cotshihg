import React from 'react';
import DataTable from '../components/DataTable';

const statusColors = { 'مكتملة': '#2ECC71', 'مؤكدة': '#1A6B72', 'معلقة': '#F5A623', 'ملغية': '#E53935', 'جارية': '#FF6B35' };

const mockBookings = Array.from({ length: 30 }, (_, i) => ({
  id: `BK${String(i + 1).padStart(4, '0')}`,
  client: ['أحمد محمد', 'سارة علي', 'خالد أحمد', 'نورة سالم', 'محمد عبدالله'][i % 5],
  therapist: ['د. سارة', 'د. خالد', 'د. ريم', 'د. محمد', 'د. نورا'][i % 5],
  type: ['فيديو', 'صوتي', 'دردشة'][i % 3],
  date: `2024-0${(i % 9) + 1}-${String((i % 28) + 1).padStart(2, '0')}`,
  amount: [150, 200, 250, 300][i % 4],
  status: ['مكتملة', 'مؤكدة', 'معلقة', 'ملغية', 'جارية'][i % 5],
}));

const columns = [
  { key: 'id', label: 'رقم الحجز' },
  { key: 'client', label: 'العميل' },
  { key: 'therapist', label: 'الكوتش' },
  { key: 'type', label: 'النوع' },
  { key: 'date', label: 'التاريخ' },
  { key: 'amount', label: 'المبلغ (ر.س)' },
  {
    key: 'status', label: 'الحالة',
    render: v => <span style={{ padding: '4px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, background: `${statusColors[v]}20`, color: statusColors[v] }}>{v}</span>
  },
];

export default function Bookings() {
  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>الحجوزات</h1>
        <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>عرض وإدارة جميع الحجوزات</p>
      </div>
      <DataTable title={`إجمالي الحجوزات: ${mockBookings.length}`} columns={columns} data={mockBookings} />
    </div>
  );
}
