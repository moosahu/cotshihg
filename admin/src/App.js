import React, { useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
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

function Layout({ children }) {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  return (
    <div className="app-layout">
      <Sidebar open={sidebarOpen} />
      <div className={`main-content ${sidebarOpen ? 'sidebar-open' : ''}`}>
        <Header onToggleSidebar={() => setSidebarOpen(!sidebarOpen)} />
        <div className="page-content">{children}</div>
      </div>
    </div>
  );
}

export default function App() {
  const isLoggedIn = !!localStorage.getItem('admin_token');

  return (
    <BrowserRouter>
      <Toaster position="top-center" toastOptions={{ style: { fontFamily: 'Cairo' } }} />
      <Routes>
        <Route path="/login" element={<Login />} />
        {isLoggedIn ? (
          <>
            <Route path="/" element={<Layout><Dashboard /></Layout>} />
            <Route path="/users" element={<Layout><Users /></Layout>} />
            <Route path="/therapists" element={<Layout><Therapists /></Layout>} />
            <Route path="/bookings" element={<Layout><Bookings /></Layout>} />
            <Route path="/content" element={<Layout><Content /></Layout>} />
            <Route path="/payments" element={<Layout><Payments /></Layout>} />
          </>
        ) : (
          <Route path="*" element={<Navigate to="/login" />} />
        )}
        <Route path="*" element={<Navigate to="/" />} />
      </Routes>
    </BrowserRouter>
  );
}
