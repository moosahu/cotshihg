import React, { useState, useEffect } from 'react';
import toast from 'react-hot-toast';
import api from '../services/api';
import './Content.css';

const typeLabels = { article: 'مقال', program: 'برنامج', webinar: 'ويبينار', exercise: 'تمرين' };

export default function Content() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newType, setNewType] = useState('article');
  const [newCategory, setNewCategory] = useState('تطوير ذاتي');

  useEffect(() => {
    api.getContent()
      .then(res => setItems(res.data || []))
      .catch(err => toast.error(err.message))
      .finally(() => setLoading(false));
  }, []);

  const togglePublish = async (id) => {
    try {
      const res = await api.togglePublishContent(id);
      setItems(prev => prev.map(item =>
        item.id === id ? { ...item, is_published: res.data.is_published } : item
      ));
      toast.success(res.data.is_published ? 'تم النشر' : 'تم التحويل لمسودة');
    } catch (err) {
      toast.error(err.message);
    }
  };

  const handleAdd = async () => {
    if (!newTitle.trim()) return;
    try {
      const res = await api.createContent({ title_ar: newTitle, content_type: newType, category: newCategory });
      setItems(prev => [res.data, ...prev]);
      setNewTitle('');
      setShowForm(false);
      toast.success('تمت الإضافة');
    } catch (err) {
      toast.error(err.message);
    }
  };

  const handleDelete = async (id, title) => {
    if (!window.confirm(`حذف "${title}"؟`)) return;
    try {
      await api.deleteContent(id);
      setItems(prev => prev.filter(item => item.id !== id));
      toast.success('تم الحذف');
    } catch (err) {
      toast.error(err.message);
    }
  };

  if (loading) return <div style={{ padding: 40, textAlign: 'center', color: '#8A94A6' }}>جاري التحميل...</div>;

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
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
            <input
              className="form-input"
              placeholder="عنوان المحتوى"
              value={newTitle}
              onChange={e => setNewTitle(e.target.value)}
              style={{ flex: 2, minWidth: 200 }}
            />
            <select className="form-input" value={newType} onChange={e => setNewType(e.target.value)} style={{ flex: 1 }}>
              <option value="article">مقال</option>
              <option value="program">برنامج</option>
              <option value="webinar">ويبينار</option>
              <option value="exercise">تمرين</option>
            </select>
            <input
              className="form-input"
              placeholder="التصنيف"
              value={newCategory}
              onChange={e => setNewCategory(e.target.value)}
              style={{ flex: 1 }}
            />
            <button className="add-btn" onClick={handleAdd}>حفظ</button>
          </div>
        </div>
      )}

      {items.length === 0 ? (
        <div className="card" style={{ textAlign: 'center', padding: 40, color: '#8A94A6' }}>
          لا يوجد محتوى بعد — اضغط "+ إضافة محتوى" للبدء
        </div>
      ) : (
        <div className="content-grid">
          {items.map(item => (
            <div key={item.id} className="content-card card">
              <div className="content-card-header">
                <span className="content-type">{typeLabels[item.content_type] || item.content_type}</span>
                <label className="toggle-switch">
                  <input type="checkbox" checked={item.is_published} onChange={() => togglePublish(item.id)} />
                  <span className="slider" />
                </label>
              </div>
              <h4 className="content-title">{item.title_ar}</h4>
              <div className="content-meta">
                <span className="content-category">{item.category || '—'}</span>
                <span className={`content-status ${item.is_published ? 'published' : 'draft'}`}>
                  {item.is_published ? 'منشور' : 'مسودة'}
                </span>
              </div>
              <button
                onClick={() => handleDelete(item.id, item.title_ar)}
                style={{ marginTop: 8, fontSize: 12, color: '#E53935', background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}
              >
                حذف
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
