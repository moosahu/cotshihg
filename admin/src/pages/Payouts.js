import React, { useState, useEffect } from 'react';
import api from '../services/api';
import toast from 'react-hot-toast';

const statusColors = { pending: '#F5A623', paid: '#2ECC71', rejected: '#E53935' };
const statusLabels = { pending: 'معلق', paid: 'تم التحويل', rejected: 'مرفوض' };

export default function Payouts() {
  const [tab, setTab] = useState('requests'); // 'requests' | 'summary'
  const [requests, setRequests] = useState([]);
  const [summary, setSummary] = useState([]);
  const [loading, setLoading] = useState(true);
  const [paying, setPaying] = useState(null);

  const load = () => {
    setLoading(true);
    Promise.all([api.getPayoutRequests(), api.getCoachPayouts()])
      .then(([r, s]) => {
        setRequests(r.data || []);
        setSummary(s.data || []);
      })
      .catch(err => toast.error(err.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const handleMarkPaid = async (id, coachName, amount) => {
    if (!window.confirm(`تأكيد تحويل ${amount} ر.س لـ ${coachName}؟`)) return;
    setPaying(id);
    try {
      const res = await api.markPayoutRequestPaid(id);
      toast.success(res.message || 'تم');
      load();
    } catch (err) {
      toast.error(err.message);
    } finally {
      setPaying(null);
    }
  };

  const pendingRequests = requests.filter(r => r.status === 'pending');
  const totalRequested = pendingRequests.reduce((s, r) => s + parseFloat(r.amount || 0), 0);

  if (loading) return <div style={{ padding: 40, textAlign: 'center', color: '#8A94A6' }}>جاري التحميل...</div>;

  return (
    <div style={{ direction: 'rtl' }}>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>مستحقات الكوتشيز</h1>
        <p style={{ color: '#8A94A6', fontSize: 14, marginTop: 4 }}>طلبات السحب والمستحقات المتراكمة</p>
      </div>

      {/* Summary cards */}
      <div style={{ display: 'flex', gap: 16, marginBottom: 24 }}>
        <div style={{ flex: 1, background: '#fff', borderRadius: 14, padding: '18px 22px', boxShadow: '0 2px 8px rgba(0,0,0,0.06)' }}>
          <div style={{ fontSize: 13, color: '#8A94A6', marginBottom: 4 }}>طلبات سحب معلقة</div>
          <div style={{ fontSize: 26, fontWeight: 700, color: '#F5A623' }}>{pendingRequests.length}</div>
        </div>
        <div style={{ flex: 1, background: '#fff', borderRadius: 14, padding: '18px 22px', boxShadow: '0 2px 8px rgba(0,0,0,0.06)' }}>
          <div style={{ fontSize: 13, color: '#8A94A6', marginBottom: 4 }}>إجمالي مطلوب التحويل</div>
          <div style={{ fontSize: 26, fontWeight: 700, color: '#e65100' }}>{totalRequested.toFixed(2)} ر.س</div>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {[{ key: 'requests', label: `طلبات السحب ${pendingRequests.length > 0 ? `(${pendingRequests.length})` : ''}` }, { key: 'summary', label: 'ملخص الكوتشيز' }].map(t => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            style={{ padding: '8px 20px', borderRadius: 10, border: 'none', cursor: 'pointer', fontSize: 14, fontWeight: 600, background: tab === t.key ? '#1A6B72' : '#f0f0f0', color: tab === t.key ? '#fff' : '#555' }}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* ── طلبات السحب ── */}
      {tab === 'requests' && (
        <div style={{ background: '#fff', borderRadius: 14, boxShadow: '0 2px 8px rgba(0,0,0,0.06)', overflow: 'hidden' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 14 }}>
            <thead>
              <tr style={{ background: '#f9fafb', borderBottom: '1px solid #eee' }}>
                {['الكوتش', 'الجوال', 'المبلغ', 'IBAN', 'البنك', 'اسم الحساب', 'تاريخ الطلب', 'الحالة', 'إجراء'].map(h => (
                  <th key={h} style={{ padding: '12px 14px', textAlign: 'right', fontWeight: 600, color: '#555', fontSize: 13, whiteSpace: 'nowrap' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {requests.length === 0 ? (
                <tr><td colSpan={9} style={{ padding: 40, textAlign: 'center', color: '#8A94A6' }}>لا توجد طلبات</td></tr>
              ) : requests.map(row => (
                <tr key={row.id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                  <td style={{ padding: '14px', fontWeight: 600 }}>{row.coach_name}</td>
                  <td style={{ padding: '14px', color: '#555', direction: 'ltr', fontSize: 13 }}>{row.coach_phone || '—'}</td>
                  <td style={{ padding: '14px', fontWeight: 700, color: '#1A6B72' }}>{parseFloat(row.amount).toFixed(2)} ر.س</td>
                  <td style={{ padding: '14px', fontFamily: 'monospace', fontSize: 13, direction: 'ltr', color: '#333' }}>
                    {row.iban ? (
                      <span title={row.iban}>{row.iban.substring(0, 6)}...{row.iban.slice(-4)}</span>
                    ) : '—'}
                  </td>
                  <td style={{ padding: '14px', fontSize: 13, color: '#555' }}>{row.bank_name || '—'}</td>
                  <td style={{ padding: '14px', fontSize: 13 }}>{row.account_holder || '—'}</td>
                  <td style={{ padding: '14px', fontSize: 12, color: '#8A94A6' }}>
                    {new Date(row.requested_at).toLocaleDateString('ar-SA')}
                  </td>
                  <td style={{ padding: '14px' }}>
                    <span style={{ padding: '3px 10px', borderRadius: 8, fontSize: 12, fontWeight: 600, background: `${statusColors[row.status]}22`, color: statusColors[row.status] }}>
                      {statusLabels[row.status] || row.status}
                    </span>
                  </td>
                  <td style={{ padding: '14px' }}>
                    {row.status === 'pending' ? (
                      <button
                        onClick={() => handleMarkPaid(row.id, row.coach_name, parseFloat(row.amount).toFixed(2))}
                        disabled={paying === row.id}
                        style={{ padding: '7px 14px', background: '#1A6B72', color: '#fff', border: 'none', borderRadius: 8, fontSize: 13, fontWeight: 600, cursor: 'pointer', opacity: paying === row.id ? 0.6 : 1, whiteSpace: 'nowrap' }}
                      >
                        {paying === row.id ? '...' : '✓ تم التحويل'}
                      </button>
                    ) : (
                      <span style={{ color: '#2ECC71', fontSize: 13 }}>✓ مسدد {row.paid_at ? new Date(row.paid_at).toLocaleDateString('ar-SA') : ''}</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* ── ملخص الكوتشيز ── */}
      {tab === 'summary' && (
        <div style={{ background: '#fff', borderRadius: 14, boxShadow: '0 2px 8px rgba(0,0,0,0.06)', overflow: 'hidden' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 14 }}>
            <thead>
              <tr style={{ background: '#f9fafb', borderBottom: '1px solid #eee' }}>
                {['الكوتش', 'الجوال', 'نسبة الكوتش', 'جلسات غير محولة', 'متراكم غير محول', 'إجمالي محوَّل', 'آخر تحويل'].map(h => (
                  <th key={h} style={{ padding: '12px 14px', textAlign: 'right', fontWeight: 600, color: '#555', fontSize: 13 }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {summary.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: 40, textAlign: 'center', color: '#8A94A6' }}>لا توجد بيانات</td></tr>
              ) : summary.map(row => {
                const pending = parseFloat(row.pending_amount || 0);
                const paid = parseFloat(row.paid_amount || 0);
                return (
                  <tr key={row.therapist_id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                    <td style={{ padding: '14px', fontWeight: 600 }}>{row.coach_name}</td>
                    <td style={{ padding: '14px', color: '#555', direction: 'ltr', fontSize: 13 }}>{row.coach_phone || '—'}</td>
                    <td style={{ padding: '14px' }}>
                      <span style={{ padding: '3px 10px', borderRadius: 8, background: '#e8f8ee', color: '#1A6B72', fontWeight: 700, fontSize: 13 }}>{row.coach_rate ?? 70}%</span>
                    </td>
                    <td style={{ padding: '14px', textAlign: 'center' }}>
                      {parseInt(row.pending_sessions) > 0
                        ? <span style={{ padding: '3px 10px', borderRadius: 8, background: '#fff3e0', color: '#e65100', fontWeight: 700, fontSize: 13 }}>{row.pending_sessions}</span>
                        : '—'}
                    </td>
                    <td style={{ padding: '14px', fontWeight: 700, color: pending > 0 ? '#e65100' : '#8A94A6' }}>
                      {pending > 0 ? `${pending.toFixed(2)} ر.س` : '—'}
                    </td>
                    <td style={{ padding: '14px', color: '#2ECC71', fontWeight: 600 }}>
                      {paid > 0 ? `${paid.toFixed(2)} ر.س` : '—'}
                    </td>
                    <td style={{ padding: '14px', color: '#8A94A6', fontSize: 13 }}>
                      {row.last_payout_date ? new Date(row.last_payout_date).toLocaleDateString('ar-SA') : '—'}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
