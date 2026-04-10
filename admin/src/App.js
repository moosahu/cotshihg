import React, { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate, useNavigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import Sidebar from './components/Sidebar';
import Header from './components/Header';
import Dashboard from './pages/Dashboard';
import Users from './pages/Users';
import Therapists from './pages/Therapists';
import Bookings from './pages/Bookings';
import Content from './pages/Content';
import Payments from './pages/Payments';
import Questionnaire from './pages/Questionnaire';
import Payouts from './pages/Payouts';
import Login from './pages/Login';
import './App.css';

function Layout({ children, onLogout }) {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  return (
    <div className="app-layout">
      <Sidebar open={sidebarOpen} />
      <div className={`main-content ${sidebarOpen ? 'sidebar-open' : ''}`}>
        <Header onToggleSidebar={() => setSidebarOpen(!sidebarOpen)} onLogout={() => { localStorage.removeItem('admin_token'); onLogout?.(); }} />
        <div className="page-content">{children}</div>
      </div>
    </div>
  );
}

export default function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(!!localStorage.getItem('admin_token'));

  return (
    <BrowserRouter>
      <Toaster position="top-center" toastOptions={{ style: { fontFamily: 'Cairo' } }} />
      <Routes>
        <Route path="/login" element={isLoggedIn ? <Navigate to="/" replace /> : <Login onLogin={() => setIsLoggedIn(true)} />} />
        <Route path="/" element={isLoggedIn ? <Layout onLogout={() => setIsLoggedIn(false)}><Dashboard /></Layout> : <Navigate to="/login" replace />} />
        <Route path="/users" element={isLoggedIn ? <Layout onLogout={() => setIsLoggedIn(false)}><Users /></Layout> : <Navigate to="/login" replace />} />
        <Route path="/therapists" element={isLoggedIn ? <Layout onLogout={() => setIsLoggedIn(false)}><Therapists /></Layout> : <Navigate to="/login" replace />} />
        <Route path="/bookings" element={isLoggedIn ? <Layout onLogout={() => setIsLoggedIn(false)}><Bookings /></Layout> : <Navigate to="/login" replace />} />
        <Route path="/content" element={isLoggedIn ? <Layout onLogout={() => setIsLoggedIn(false)}><Content /></Layout> : <Navigate to="/login" replace />} />
        <Route path="/payments" element={isLoggedIn ? <Layout onLogout={() => setIsLoggedIn(false)}><Payments /></Layout> : <Navigate to="/login" replace />} />
        <Route path="/questionnaire" element={isLoggedIn ? <Layout onLogout={() => setIsLoggedIn(false)}><Questionnaire /></Layout> : <Navigate to="/login" replace />} />
        <Route path="/payouts" element={isLoggedIn ? <Layout onLogout={() => setIsLoggedIn(false)}><Payouts /></Layout> : <Navigate to="/login" replace />} />
        <Route path="*" element={<Navigate to={isLoggedIn ? "/" : "/login"} replace />} />
      </Routes>
    </BrowserRouter>
  );
}
