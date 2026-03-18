import React, { useState } from 'react';
import DataTable from '../components/DataTable';
import toast from 'react-hot-toast';

const mockTherapists = Array.from({ length: 18 }, (_, i) => ({
  id: i + 1,
  name: ['د. سارة الأحمد', 'د. خالد العمر', 'د. ريم السالم', 'د. محمد العلي', 'د. نورا خالد'][i % 5],
  specialization: ['تطوير ذاتي', 'قيادة', 'إنتاجية', 'علاقات', 'مهني'][i % 5],
  sessions: Math.floor(Math.random() * 200) + 10,
  rating: (4 + Math.random()).toFixed(1),
  price: [150, 200, 250, 300][i % 4],
  approved: i % 4 !== 0,
}));

const columns = [
  { key: 'id', label: '#' },
  { key: 'name', label: 'الاسم' },
  { key: 'specialization', label: 'التخصص' },
  { key: 'sessions', label: 'الجلسات' },
  { key: 'rating', label: 'التقييم', render: v => `⭐ ${v}` },
  { key: 'price', label: 'السعر (ر.س)' },
  {
    key: 'approved', label: 'الحالة',
    render: v => <span style={{ padding: '4px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, background: v ? '#e8f8ee' : '#fff8e1', color: v ? '#2ECC71' : '#F5A623' }}>{v ? 'معتمد' : 'قيد المراجعة'}</span>
  },
  {
    key: 'actions', label: 'إجراء',
    render: (_, row) => (
      <div style={{ display: 'flex', gap: 8 }}>
        <button onClick={() => toast.success(`تم ${row.approved ? 'إيقاف' : 'اعتماد'} ${row.name}`)} style={{ padding: '6px 12px', borderRadius: 8, border: `1px solid ${row.approved ? '#E53935' : '#2ECC71'}`, background: 'none', color: row.approved ? '#E53935' : '#2ECC71', fontSize: 12, cursor: 'pointer' }}>{row.approved ? 'إيقاف' : 'اعتماد'}</button>
      </div>
    )
  },
];

export default function Therapists() {
  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>الكوتشز</h1>
        <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>إدارة واعتماد الكوتشز</p>
      </div>
      <DataTable title={`إجمالي الكوتشز: ${mockTherapists.length}`} columns={columns} data={mockTherapists} />
    </div>
  );
}
