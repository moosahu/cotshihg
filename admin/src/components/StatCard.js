import React from 'react';
import './StatCard.css';

export default function StatCard({ title, value, change, icon, color }) {
  const isPositive = change >= 0;
  return (
    <div className="stat-card card">
      <div className="stat-header">
        <div className="stat-icon" style={{ background: `${color}20`, color }}>
          {icon}
        </div>
        <span className={`stat-change ${isPositive ? 'positive' : 'negative'}`}>
          {isPositive ? '↑' : '↓'} {Math.abs(change)}%
        </span>
      </div>
      <div className="stat-value">{value}</div>
      <div className="stat-title">{title}</div>
    </div>
  );
}
