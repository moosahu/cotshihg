import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';
import './Login.css';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await api.login(email, password);
      localStorage.setItem('admin_token', res.data.token);
      navigate('/');
    } catch (err) {
      setError(err.message || 'بيانات الدخول غير صحيحة');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-logo">
          <div className="login-logo-icon">C</div>
          <h1>Coaching</h1>
          <p>لوحة تحكم المشرف</p>
        </div>
        <form onSubmit={handleSubmit} className="login-form">
          {error && <div style={{ background: '#fdecea', color: '#E53935', padding: '10px 14px', borderRadius: 8, fontSize: 14, marginBottom: 12 }}>{error}</div>}
          <div className="form-group">
            <label>البريد الإلكتروني</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="admin@coaching.app" required />
          </div>
          <div className="form-group">
            <label>كلمة المرور</label>
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" required />
          </div>
          <button type="submit" className="login-btn" disabled={loading}>
            {loading ? 'جاري الدخول...' : 'دخول'}
          </button>
        </form>
      </div>
    </div>
  );
}
