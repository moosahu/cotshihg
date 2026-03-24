import React, { useEffect, useState } from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, PieChart, Pie, Cell } from 'recharts';
import StatCard from '../components/StatCard';
import api from '../services/api';
import './Dashboard.css';

const sessionTypes = [
  { name: 'فيديو', value: 55, color: '#1A6B72' },
  { name: 'صوتي', value: 25, color: '#F5A623' },
  { name: 'دردشة', value: 20, color: '#FF6B35' },
];

const statusColors = { completed: '#2ECC71', confirmed: '#1A6B72', pending: '#F5A623', cancelled: '#E53935', in_progress: '#FF6B35' };
const statusLabels = { completed: 'مكتملة', confirmed: 'مؤكدة', pending: 'معلقة', cancelled: 'ملغية', in_progress: 'جارية' };
const typeLabels = { video: 'فيديو', voice: 'صوتي', chat: 'دردشة' };

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([api.getStats(), api.getBookings()])
      .then(([statsRes, bookingsRes]) => {
        setStats(statsRes.data);
        setBookings((bookingsRes.data || []).slice(0, 5));
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="dashboard">
      <div className="page-header">
        <h1>لوحة التحكم</h1>
        <p>مرحباً — هذا ملخص أداء التطبيق اليوم</p>
      </div>

      {/* Stats */}
      <div className="stats-grid">
        <StatCard title="إجمالي المستخدمين" value={loading ? '...' : (stats?.totalUsers ?? 0).toLocaleString()} change={null} icon="👥" color="#1A6B72" />
        <StatCard title="الكوتشيز" value={loading ? '...' : (stats?.totalTherapists ?? 0).toLocaleString()} change={null} icon="🧑‍💼" color="#F5A623" />
        <StatCard title="جلسات اليوم" value={loading ? '...' : (stats?.todaySessions ?? 0).toLocaleString()} change={null} icon="📅" color="#FF6B35" />
        <StatCard title="الإيرادات (ر.س)" value={loading ? '...' : (stats?.totalRevenue ?? 0).toLocaleString()} change={null} icon="💰" color="#2ECC71" />
      </div>

      {/* Charts row */}
      <div className="charts-row">
        <div className="chart-card card">
          <h3>أنواع الجلسات</h3>
          <ResponsiveContainer width="100%" height={220}>
            <PieChart>
              <Pie data={sessionTypes} cx="50%" cy="50%" innerRadius={50} outerRadius={80} dataKey="value">
                {sessionTypes.map((entry, index) => <Cell key={index} fill={entry.color} />)}
              </Pie>
              <Tooltip formatter={(v) => `${v}%`} contentStyle={{ fontFamily: 'Cairo', borderRadius: 8 }} />
            </PieChart>
          </ResponsiveContainer>
          <div className="pie-legend">
            {sessionTypes.map(t => (
              <div key={t.name} className="legend-item">
                <span className="legend-dot" style={{ background: t.color }} />
                <span>{t.name} {t.value}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Recent bookings */}
      <div className="card">
        <h3 style={{ marginBottom: 16 }}>آخر الجلسات</h3>
        {loading ? (
          <p style={{ color: '#8A94A6', textAlign: 'center', padding: 24 }}>جاري التحميل...</p>
        ) : bookings.length === 0 ? (
          <p style={{ color: '#8A94A6', textAlign: 'center', padding: 24 }}>لا توجد حجوزات بعد</p>
        ) : (
          <table className="mini-table">
            <thead>
              <tr>
                <th>العميل</th><th>الكوتش</th><th>النوع</th><th>الحالة</th><th>المبلغ</th>
              </tr>
            </thead>
            <tbody>
              {bookings.map((b) => (
                <tr key={b.id}>
                  <td>{b.client_name || '—'}</td>
                  <td>{b.therapist_name || '—'}</td>
                  <td>{typeLabels[b.session_type] || b.session_type}</td>
                  <td>
                    <span className="status-badge" style={{ background: `${statusColors[b.status] || '#8A94A6'}20`, color: statusColors[b.status] || '#8A94A6' }}>
                      {statusLabels[b.status] || b.status}
                    </span>
                  </td>
                  <td><strong>{b.price ? <><strong>{b.price}</strong> <i className="icon-saudi_riyal_new" /></> : '—'}</strong></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
