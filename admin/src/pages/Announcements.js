import React, { useState, useEffect } from 'react';
import api from '../services/api';
import toast from 'react-hot-toast';

const empty = { title: '', body: '', image_url: '', button_text: '', button_url: '' };

export default function Announcements() {
  const [list, setList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(empty);
  const [editId, setEditId] = useState(null);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);

  const load = () => {
    setLoading(true);
    api.getAnnouncements()
      .then(r => setList(r.data || []))
      .catch(e => toast.error(e.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const handleSave = async () => {
    if (!form.title.trim()) return toast.error('العنوان مطلوب');
    setSaving(true);
    try {
      if (editId) {
        await api.updateAnnouncement(editId, form);
        toast.success('تم التحديث');
      } else {
        await api.createAnnouncement(form);
        toast.success('تم إنشاء الإعلان');
      }
      setForm(empty);
      setEditId(null);
      load();
    } catch (e) {
      toast.error(e.message);
    } finally {
      setSaving(false);
    }
  };

  const handleEdit = (item) => {
    setEditId(item.id);
    setForm({
      title: item.title || '',
      body: item.body || '',
      image_url: item.image_url || '',
      button_text: item.button_text || '',
      button_url: item.button_url || '',
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDelete = async (id) => {
    if (!window.confirm('حذف هذا الإعلان؟')) return;
    try {
      await api.deleteAnnouncement(id);
      toast.success('تم الحذف');
      load();
    } catch (e) {
      toast.error(e.message);
    }
  };

  const handleImageUpload = (e) => {
    const file = e.target.files[0];
    if (!file) return;
    if (file.size > 1.5 * 1024 * 1024) {
      toast.error('الصورة يجب أن تكون أقل من 1.5 ميغا');
      return;
    }
    setUploading(true);
    const reader = new FileReader();
    reader.onload = () => {
      setForm(f => ({ ...f, image_url: reader.result }));
      setUploading(false);
      toast.success('تم تحميل الصورة');
    };
    reader.onerror = () => { toast.error('فشل قراءة الصورة'); setUploading(false); };
    reader.readAsDataURL(file);
    e.target.value = '';
  };

  const handleToggle = async (item) => {
    try {
      await api.updateAnnouncement(item.id, { is_active: !item.is_active });
      toast.success(item.is_active ? 'تم إيقاف الإعلان' : 'تم تفعيل الإعلان');
      load();
    } catch (e) {
      toast.error(e.message);
    }
  };

  return (
    <div style={{ maxWidth: 800, margin: '0 auto', padding: '24px 16px' }}>
      <h2 style={{ marginBottom: 24 }}>الإعلانات</h2>

      {/* Form */}
      <div style={{ background: '#fff', borderRadius: 12, padding: 24, marginBottom: 32, boxShadow: '0 1px 4px rgba(0,0,0,0.08)' }}>
        <h3 style={{ marginBottom: 16 }}>{editId ? 'تعديل الإعلان' : 'إعلان جديد'}</h3>

        <div style={{ display: 'grid', gap: 12 }}>
          <div>
            <label style={labelStyle}>العنوان *</label>
            <input style={inputStyle} placeholder="عنوان الإعلان" value={form.title}
              onChange={e => setForm(f => ({ ...f, title: e.target.value }))} />
          </div>
          <div>
            <label style={labelStyle}>النص</label>
            <textarea style={{ ...inputStyle, height: 80, resize: 'vertical' }}
              placeholder="نص الإعلان (اختياري)"
              value={form.body}
              onChange={e => setForm(f => ({ ...f, body: e.target.value }))} />
          </div>
          <div>
            <label style={labelStyle}>الصورة</label>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              <label style={{ background: '#f0f0f0', border: '1px solid #ddd', borderRadius: 8, padding: '9px 16px', cursor: 'pointer', fontSize: 13, fontFamily: 'inherit', whiteSpace: 'nowrap' }}>
                {uploading ? 'جاري الرفع...' : '📎 ارفع صورة'}
                <input type="file" accept="image/*" style={{ display: 'none' }} onChange={handleImageUpload} disabled={uploading} />
              </label>
              <input style={{ ...inputStyle, flex: 1 }} placeholder="أو الصق رابط مباشر..." value={form.image_url}
                onChange={e => setForm(f => ({ ...f, image_url: e.target.value }))} />
            </div>
            {form.image_url && (
              <div style={{ marginTop: 8, position: 'relative', display: 'inline-block' }}>
                <img src={form.image_url} alt="preview" style={{ maxHeight: 140, maxWidth: '100%', borderRadius: 8, objectFit: 'cover', display: 'block' }}
                  onError={e => { e.target.style.display = 'none'; }} />
                <button onClick={() => setForm(f => ({ ...f, image_url: '' }))}
                  style={{ position: 'absolute', top: 4, right: 4, background: 'rgba(0,0,0,0.5)', color: '#fff', border: 'none', borderRadius: '50%', width: 22, height: 22, cursor: 'pointer', fontSize: 12, lineHeight: '22px', padding: 0 }}>✕</button>
              </div>
            )}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div>
              <label style={labelStyle}>نص الزر</label>
              <input style={inputStyle} placeholder="مثال: اعرف أكثر" value={form.button_text}
                onChange={e => setForm(f => ({ ...f, button_text: e.target.value }))} />
            </div>
            <div>
              <label style={labelStyle}>رابط الزر</label>
              <input style={inputStyle} placeholder="https://..." value={form.button_url}
                onChange={e => setForm(f => ({ ...f, button_url: e.target.value }))} />
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
          <button onClick={handleSave} disabled={saving}
            style={{ background: '#1A6B72', color: '#fff', border: 'none', borderRadius: 8, padding: '10px 24px', cursor: 'pointer', fontFamily: 'inherit' }}>
            {saving ? 'جاري الحفظ...' : editId ? 'تحديث' : 'إنشاء'}
          </button>
          {editId && (
            <button onClick={() => { setForm(empty); setEditId(null); }}
              style={{ background: '#f0f0f0', border: 'none', borderRadius: 8, padding: '10px 16px', cursor: 'pointer', fontFamily: 'inherit' }}>
              إلغاء
            </button>
          )}
        </div>
      </div>

      {/* List */}
      {loading ? <p>جاري التحميل...</p> : list.length === 0 ? (
        <p style={{ color: '#999', textAlign: 'center', padding: 32 }}>لا يوجد إعلانات</p>
      ) : (
        <div style={{ display: 'grid', gap: 12 }}>
          {list.map(item => (
            <div key={item.id} style={{ background: '#fff', borderRadius: 12, padding: 16, boxShadow: '0 1px 4px rgba(0,0,0,0.08)', display: 'flex', gap: 16, alignItems: 'flex-start' }}>
              {item.image_url && (
                <img src={item.image_url} alt="" style={{ width: 80, height: 60, borderRadius: 8, objectFit: 'cover', flexShrink: 0 }}
                  onError={e => { e.target.style.display = 'none'; }} />
              )}
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                  <span style={{ fontWeight: 600 }}>{item.title}</span>
                  <span style={{ fontSize: 12, padding: '2px 8px', borderRadius: 20, background: item.is_active ? '#e8f5e9' : '#f5f5f5', color: item.is_active ? '#2e7d32' : '#999' }}>
                    {item.is_active ? 'مفعّل' : 'موقوف'}
                  </span>
                </div>
                {item.body && <p style={{ margin: 0, fontSize: 13, color: '#666' }}>{item.body}</p>}
              </div>
              <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
                <button onClick={() => handleToggle(item)}
                  style={{ background: item.is_active ? '#fff3e0' : '#e8f5e9', color: item.is_active ? '#e65100' : '#2e7d32', border: 'none', borderRadius: 6, padding: '6px 12px', cursor: 'pointer', fontSize: 12, fontFamily: 'inherit' }}>
                  {item.is_active ? 'إيقاف' : 'تفعيل'}
                </button>
                <button onClick={() => handleEdit(item)}
                  style={{ background: '#e3f2fd', color: '#1565c0', border: 'none', borderRadius: 6, padding: '6px 12px', cursor: 'pointer', fontSize: 12, fontFamily: 'inherit' }}>
                  تعديل
                </button>
                <button onClick={() => handleDelete(item.id)}
                  style={{ background: '#fce4ec', color: '#c62828', border: 'none', borderRadius: 6, padding: '6px 12px', cursor: 'pointer', fontSize: 12, fontFamily: 'inherit' }}>
                  حذف
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

const labelStyle = { display: 'block', fontSize: 13, color: '#555', marginBottom: 4 };
const inputStyle = { width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid #ddd', fontFamily: 'inherit', fontSize: 14, boxSizing: 'border-box' };
