import React from 'react';
import { NavLink } from 'react-router-dom';
import './Sidebar.css';

const navItems = [
  { path: '/', icon: '📊', label: 'لوحة التحكم' },
  { path: '/users', icon: '👥', label: 'المستخدمون' },
  { path: '/therapists', icon: '🧑‍💼', label: 'الكوتشيز' },
  { path: '/bookings', icon: '📅', label: 'الجلسات' },
  { path: '/content', icon: '📚', label: 'المحتوى' },
  { path: '/payments', icon: '💳', label: 'المدفوعات' },
  { path: '/questionnaire', icon: '📋', label: 'الاستبيان' },
  { path: '/payouts', icon: '💰', label: 'مستحقات الكوتشيز' },
  { path: '/announcements', icon: '📢', label: 'الإعلانات' },
];

export default function Sidebar({ open }) {
  return (
    <aside className={`sidebar ${open ? 'open' : ''}`}>
      {/* Logo */}
      <div className="sidebar-logo">
        <div className="logo-icon">C</div>
        <span className="logo-text">Coaching</span>
      </div>

      {/* Nav */}
      <nav className="sidebar-nav">
        {navItems.map(item => (
          <NavLink
            key={item.path}
            to={item.path}
            end={item.path === '/'}
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <span className="nav-icon">{item.icon}</span>
            <span className="nav-label">{item.label}</span>
          </NavLink>
        ))}
      </nav>

      {/* Footer */}
      <div className="sidebar-footer">
        <div className="admin-info">
          <div className="admin-avatar">A</div>
          <div>
            <div className="admin-name">المشرف</div>
            <div className="admin-role">Admin</div>
          </div>
        </div>
      </div>
    </aside>
  );
}
