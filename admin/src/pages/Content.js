import React, { useState } from 'react';
import toast from 'react-hot-toast';
import './Content.css';

const mockContent = [
  { id: 1, title: 'كيف تحدد أهدافك بذكاء', type: 'مقال', category: 'تطوير ذاتي', published: true },
  { id: 2, title: 'أسرار الإنتاجية العالية', type: 'برنامج', category: 'إنتاجية', published: true },
  { id: 3, title: 'بناء عادات النجاح', type: 'مقال', category: 'تطوير ذاتي', published: false },
  { id: 4, title: 'فن التواصل الفعّال', type: 'ويبينار', category: 'علاقات', published: true },
  { id: 5, title: 'القيادة بالتأثير', type: 'برنامج', category: 'قيادة', published: false },
];

export default function Content() {
  const [items, setItems] = useState(mockContent);
  const [showForm, setShowForm] = useState(false);
  const [newTitle, setNewTitle] = useState('');

  const togglePublish = (id) => {
    setItems(items.map(item => item.id === id ? { ...item, published: !item.published } : item));
    toast.success('تم تحديث حالة المحتوى');
  };

  return (
    <div>
      <div className="content-header">
        <div>
          <h1 style={{ fontSize: 22, fontWeight: 700 }}>المحتوى</h1>
          <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>إدارة المقالات والبرامج والويبينارات</p>
        </div>
        <button className="add-btn" onClick={() => setShowForm(!showForm)}>+ إضافة محتوى</button>
      </div>

      {showForm && (
        <div className="card" style={{ marginBottom: 16 }}>
          <h3 style={{ marginBottom: 12 }}>إضافة محتوى جديد</h3>
          <div style={{ display: 'flex', gap: 12 }}>
            <input className="form-input" placeholder="عنوان المحتوى" value={newTitle} onChange={e => setNewTitle(e.target.value)} style={{ flex: 1 }} />
            <button className="add-btn" onClick={() => { if (newTitle) { setItems([...items, { id: items.length + 1, title: newTitle, type: 'مقال', category: 'تطوير ذاتي', published: false }]); setNewTitle(''); setShowForm(false); toast.success('تمت الإضافة'); } }}>حفظ</button>
          </div>
        </div>
      )}

      <div className="content-grid">
        {items.map(item => (
          <div key={item.id} className="content-card card">
            <div className="content-card-header">
              <span className="content-type">{item.type}</span>
              <label className="toggle-switch">
                <input type="checkbox" checked={item.published} onChange={() => togglePublish(item.id)} />
                <span className="slider" />
              </label>
            </div>
            <h4 className="content-title">{item.title}</h4>
            <div className="content-meta">
              <span className="content-category">{item.category}</span>
              <span className={`content-status ${item.published ? 'published' : 'draft'}`}>{item.published ? 'منشور' : 'مسودة'}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
