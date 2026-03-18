const BASE_URL = process.env.REACT_APP_API_URL || 'https://coaching-backend-ft67.onrender.com/api/v1';

function getToken() {
  return localStorage.getItem('admin_token');
}

async function request(path, options = {}) {
  const token = getToken();
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...options,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || 'Request failed');
  return data;
}

const api = {
  login: (email, password) =>
    request('/admin/login', { method: 'POST', body: JSON.stringify({ email, password }) }),

  getStats: () => request('/admin/stats'),
  getUsers: () => request('/admin/users'),
  updateUserRole: (id, role) => request(`/admin/users/${id}/role`, { method: 'PUT', body: JSON.stringify({ role }) }),
  toggleBanUser: (id) => request(`/admin/users/${id}/ban`, { method: 'PUT' }),
  getTherapists: () => request('/admin/therapists'),
  toggleApproveTherapist: (id) => request(`/admin/therapists/${id}/approve`, { method: 'PUT' }),
  getBookings: () => request('/admin/bookings'),
  getPayments: () => request('/admin/payments'),
  getContent: () => request('/admin/content'),
  createContent: (data) => request('/admin/content', { method: 'POST', body: JSON.stringify(data) }),
  togglePublishContent: (id) => request(`/admin/content/${id}/publish`, { method: 'PUT' }),
  deleteContent: (id) => request(`/admin/content/${id}`, { method: 'DELETE' }),
};

export default api;
