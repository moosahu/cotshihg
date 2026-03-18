import React, { useState } from 'react';
import './DataTable.css';

export default function DataTable({ columns, data, title, onAction }) {
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const perPage = 8;

  const filtered = data.filter(row =>
    Object.values(row).some(v => String(v).toLowerCase().includes(search.toLowerCase()))
  );

  const paginated = filtered.slice(page * perPage, (page + 1) * perPage);
  const totalPages = Math.ceil(filtered.length / perPage);

  return (
    <div className="data-table-wrapper card">
      <div className="table-header">
        <h3 className="table-title">{title}</h3>
        <div className="table-controls">
          <input
            className="table-search"
            placeholder="بحث..."
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(0); }}
          />
        </div>
      </div>
      <div className="table-scroll">
        <table className="data-table">
          <thead>
            <tr>
              {columns.map(col => (
                <th key={col.key}>{col.label}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {paginated.length === 0 ? (
              <tr><td colSpan={columns.length} className="empty-row">لا توجد بيانات</td></tr>
            ) : paginated.map((row, i) => (
              <tr key={i}>
                {columns.map(col => (
                  <td key={col.key}>
                    {col.render ? col.render(row[col.key], row) : row[col.key]}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="table-footer">
        <span className="table-info">إجمالي: {filtered.length} نتيجة</span>
        <div className="pagination">
          <button disabled={page === 0} onClick={() => setPage(p => p - 1)}>‹</button>
          <span>{page + 1} / {Math.max(1, totalPages)}</span>
          <button disabled={page >= totalPages - 1} onClick={() => setPage(p => p + 1)}>›</button>
        </div>
      </div>
    </div>
  );
}
