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
        <Route path="/login" element={<Login onLogin={() => setIsLoggedIn(true)} />} />
        {isLoggedIn ? (
          <>
            <Route path="/" element={<Layout onLogout={() => setIsLoggedIn(false)}><Dashboard /></Layout>} />
            <Route path="/users" element={<Layout onLogout={() => setIsLoggedIn(false)}><Users /></Layout>} />
            <Route path="/therapists" element={<Layout onLogout={() => setIsLoggedIn(false)}><Therapists /></Layout>} />
            <Route path="/bookings" element={<Layout onLogout={() => setIsLoggedIn(false)}><Bookings /></Layout>} />
            <Route path="/content" element={<Layout onLogout={() => setIsLoggedIn(false)}><Content /></Layout>} />
            <Route path="/payments" element={<Layout onLogout={() => setIsLoggedIn(false)}><Payments /></Layout>} />
          </>
        ) : (
          <Route path="*" element={<Navigate to="/login" />} />
        )}
        <Route path="*" element={<Navigate to="/" />} />
      </Routes>
    </BrowserRouter>
  );
}
