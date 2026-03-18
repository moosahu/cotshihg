import React from 'react';
import './Header.css';

export default function Header({ onToggleSidebar, onLogout }) {
  return (
    <header className="header">
      <button className="toggle-btn" onClick={onToggleSidebar}>☰</button>
      <div className="header-right">
        <div className="search-box">
          <span>🔍</span>
          <input placeholder="بحث..." />
        </div>
        <div className="header-actions">
          <button className="icon-btn">🔔</button>
          <div className="header-avatar">A</div>
          {onLogout && (
            <button onClick={onLogout} style={{ marginRight: 8, background: 'none', border: '1px solid #E53935', color: '#E53935', borderRadius: 8, padding: '4px 12px', fontSize: 12, cursor: 'pointer' }}>
              خروج
            </button>
          )}
        </div>
      </div>
    </header>
  );
}
