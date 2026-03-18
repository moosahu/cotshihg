import React from 'react';
import './Header.css';

export default function Header({ onToggleSidebar }) {
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
        </div>
      </div>
    </header>
  );
}
