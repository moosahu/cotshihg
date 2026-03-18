import React from 'react';
import DataTable from '../components/DataTable';

const mockUsers = Array.from({ length: 25 }, (_, i) => ({
  id: i + 1,
  name: ['أحمد محمد', 'سارة علي', 'خالد أحمد', 'نورة سالم', 'محمد عبدالله'][i % 5],
  phone: `+9665${String(i).padStart(8, '0')}`,
  sessions: Math.floor(Math.random() * 20),
  joined: '2024-0' + ((i % 9) + 1) + '-15',
  status: i % 7 === 0 ? 'محظور' : 'نشط',
}));

const columns = [
  { key: 'id', label: '#' },
  { key: 'name', label: 'الاسم' },
  { key: 'phone', label: 'الجوال' },
  { key: 'sessions', label: 'الجلسات' },
  { key: 'joined', label: 'تاريخ التسجيل' },
  {
    key: 'status', label: 'الحالة',
    render: (v) => <span style={{ padding: '4px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, background: v === 'نشط' ? '#e8f8ee' : '#fdecea', color: v === 'نشط' ? '#2ECC71' : '#E53935' }}>{v}</span>
  },
  {
    key: 'actions', label: 'إجراء',
    render: (_, row) => (
      <div style={{ display: 'flex', gap: 8 }}>
        <button style={{ padding: '6px 12px', borderRadius: 8, border: '1px solid #1A6B72', background: 'none', color: '#1A6B72', fontSize: 12, cursor: 'pointer' }}>عرض</button>
        <button style={{ padding: '6px 12px', borderRadius: 8, border: '1px solid #E53935', background: 'none', color: '#E53935', fontSize: 12, cursor: 'pointer' }}>{row.status === 'نشط' ? 'حظر' : 'رفع الحظر'}</button>
      </div>
    )
  },
];

export default function Users() {
  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>المستخدمون</h1>
        <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>إدارة جميع مستخدمي التطبيق</p>
      </div>
      <DataTable title={`إجمالي المستخدمين: ${mockUsers.length}`} columns={columns} data={mockUsers} />
    </div>
  );
}
