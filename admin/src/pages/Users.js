import React, { useState, useEffect } from 'react';
import DataTable from '../components/DataTable';
import api from '../services/api';
import toast from 'react-hot-toast';

export default function Users() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.getUsers()
      .then(res => setUsers(res.data || []))
      .catch(err => toast.error(err.message))
      .finally(() => setLoading(false));
  }, []);

  const handleBan = async (id) => {
    try {
      const res = await api.toggleBanUser(id);
      setUsers(prev => prev.map(u => u.id === id ? { ...u, is_active: res.data.is_active } : u));
      toast.success(res.data.is_active ? 'تم رفع الحظر' : 'تم حظر المستخدم');
    } catch (err) {
      toast.error(err.message);
    }
  };

  const handleRoleChange = async (id, currentRole) => {
    const isCoach = currentRole === 'coach' || currentRole === 'therapist';
    const newRole = isCoach ? 'client' : 'coach';
    const label = newRole === 'coach' ? 'كوتش' : 'عميل';
    if (!window.confirm(`تغيير الدور إلى ${label}؟`)) return;
    try {
      const res = await api.updateUserRole(id, newRole);
      setUsers(prev => prev.map(u => u.id === id ? { ...u, role: res.data.role } : u));
      toast.success(`تم تغيير الدور إلى ${label}`);
    } catch (err) {
      toast.error(err.message);
    }
  };

  const columns = [
    { key: 'name', label: 'الاسم', render: v => v || '—' },
    { key: 'phone', label: 'الجوال' },
    { key: 'role', label: 'الدور', render: v => (v === 'coach' || v === 'therapist') ? 'كوتش' : 'عميل' },
    { key: 'sessions', label: 'الجلسات' },
    {
      key: 'created_at', label: 'تاريخ التسجيل',
      render: v => v ? new Date(v).toLocaleDateString('ar-SA') : '—'
    },
    {
      key: 'is_active', label: 'الحالة',
      render: v => (
        <span style={{ padding: '4px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, background: v ? '#e8f8ee' : '#fdecea', color: v ? '#2ECC71' : '#E53935' }}>
          {v ? 'نشط' : 'محظور'}
        </span>
      )
    },
    {
      key: 'actions', label: 'إجراء',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          <button
            onClick={() => handleRoleChange(row.id, row.role)}
            style={{ padding: '5px 10px', borderRadius: 8, border: '1px solid #1A6B72', background: 'none', color: '#1A6B72', fontSize: 12, cursor: 'pointer' }}
          >
            {(row.role === 'coach' || row.role === 'therapist') ? '← عميل' : '← كوتش'}
          </button>
          <button
            onClick={() => handleBan(row.id)}
            style={{ padding: '5px 10px', borderRadius: 8, border: `1px solid ${row.is_active ? '#E53935' : '#2ECC71'}`, background: 'none', color: row.is_active ? '#E53935' : '#2ECC71', fontSize: 12, cursor: 'pointer' }}
          >
            {row.is_active ? 'حظر' : 'رفع الحظر'}
          </button>
        </div>
      )
    },
  ];

  if (loading) return <div style={{ padding: 40, textAlign: 'center', color: '#8A94A6' }}>جاري التحميل...</div>;

  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>المستخدمون</h1>
        <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>إدارة جميع مستخدمي التطبيق</p>
      </div>
      <DataTable title={`إجمالي المستخدمين: ${users.length}`} columns={columns} data={users} />
    </div>
  );
}
