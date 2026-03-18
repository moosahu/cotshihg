import React from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, PieChart, Pie, Cell } from 'recharts';
import StatCard from '../components/StatCard';
import './Dashboard.css';

const sessionsData = [
  { day: 'الأحد', sessions: 24 },
  { day: 'الاثنين', sessions: 38 },
  { day: 'الثلاثاء', sessions: 29 },
  { day: 'الأربعاء', sessions: 45 },
  { day: 'الخميس', sessions: 52 },
  { day: 'الجمعة', sessions: 18 },
  { day: 'السبت', sessions: 31 },
];

const revenueData = [
  { month: 'يناير', revenue: 12400 },
  { month: 'فبراير', revenue: 18200 },
  { month: 'مارس', revenue: 15800 },
  { month: 'أبريل', revenue: 22000 },
  { month: 'مايو', revenue: 19500 },
  { month: 'يونيو', revenue: 28000 },
];

const sessionTypes = [
  { name: 'فيديو', value: 55, color: '#1A6B72' },
  { name: 'صوتي', value: 25, color: '#F5A623' },
  { name: 'دردشة', value: 20, color: '#FF6B35' },
];

const recentBookings = [
  { user: 'أحمد محمد', therapist: 'د. سارة', type: 'فيديو', status: 'مكتملة', amount: '300 ر.س' },
  { user: 'نورة علي', therapist: 'د. خالد', type: 'صوتي', status: 'مجدولة', amount: '200 ر.س' },
  { user: 'محمد سالم', therapist: 'د. ريم', type: 'دردشة', status: 'معلقة', amount: '150 ر.س' },
  { user: 'سارة أحمد', therapist: 'د. سارة', type: 'فيديو', status: 'مكتملة', amount: '300 ر.س' },
];

const statusColors = { 'مكتملة': '#2ECC71', 'مجدولة': '#1A6B72', 'معلقة': '#F5A623', 'ملغية': '#E53935' };

export default function Dashboard() {
  return (
    <div className="dashboard">
      <div className="page-header">
        <h1>لوحة التحكم</h1>
        <p>مرحباً — هذا ملخص أداء التطبيق اليوم</p>
      </div>

      {/* Stats */}
      <div className="stats-grid">
        <StatCard title="إجمالي المستخدمين" value="12,450" change={8.2} icon="👥" color="#1A6B72" />
        <StatCard title="الكوتشز النشطون" value="148" change={3.5} icon="🧑‍💼" color="#F5A623" />
        <StatCard title="جلسات هذا الشهر" value="2,840" change={12.1} icon="📅" color="#FF6B35" />
        <StatCard title="الإيرادات (ر.س)" value="284,000" change={15.3} icon="💰" color="#2ECC71" />
      </div>

      {/* Charts row */}
      <div className="charts-row">
        {/* Sessions chart */}
        <div className="chart-card card">
          <h3>الجلسات هذا الأسبوع</h3>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={sessionsData}>
              <defs>
                <linearGradient id="sessionsGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#1A6B72" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#1A6B72" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="day" tick={{ fontFamily: 'Cairo', fontSize: 12 }} />
              <YAxis tick={{ fontFamily: 'Cairo', fontSize: 12 }} />
              <Tooltip contentStyle={{ fontFamily: 'Cairo', borderRadius: 8 }} />
              <Area type="monotone" dataKey="sessions" stroke="#1A6B72" strokeWidth={2} fill="url(#sessionsGrad)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Session types pie */}
        <div className="chart-card card chart-small">
          <h3>أنواع الجلسات</h3>
          <ResponsiveContainer width="100%" height={180}>
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

      {/* Revenue chart */}
      <div className="card" style={{ marginBottom: 24 }}>
        <h3 style={{ marginBottom: 16 }}>الإيرادات الشهرية (ر.س)</h3>
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={revenueData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="month" tick={{ fontFamily: 'Cairo', fontSize: 12 }} />
            <YAxis tick={{ fontFamily: 'Cairo', fontSize: 12 }} />
            <Tooltip contentStyle={{ fontFamily: 'Cairo', borderRadius: 8 }} formatter={v => `${v.toLocaleString()} ر.س`} />
            <Bar dataKey="revenue" fill="#1A6B72" radius={[6, 6, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Recent bookings */}
      <div className="card">
        <h3 style={{ marginBottom: 16 }}>آخر الحجوزات</h3>
        <table className="mini-table">
          <thead>
            <tr>
              <th>المستخدم</th><th>الكوتش</th><th>النوع</th><th>الحالة</th><th>المبلغ</th>
            </tr>
          </thead>
          <tbody>
            {recentBookings.map((b, i) => (
              <tr key={i}>
                <td>{b.user}</td>
                <td>{b.therapist}</td>
                <td>{b.type}</td>
                <td><span className="status-badge" style={{ background: `${statusColors[b.status]}20`, color: statusColors[b.status] }}>{b.status}</span></td>
                <td><strong>{b.amount}</strong></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
