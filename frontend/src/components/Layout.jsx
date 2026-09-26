import { useState, useEffect } from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import { useAuth } from '../auth.jsx';
import { NAV } from '../resources.js';

const ROLES = { admin: 'Administrador', responsable_sst: 'Responsable SST', copasst: 'COPASST', consulta: 'Solo consulta' };

export default function Layout({ children }) {
  const { user, logout } = useAuth();
  const [abierto, setAbierto] = useState(false);
  const loc = useLocation();
  useEffect(() => setAbierto(false), [loc.pathname]);

  return (
    <div className="shell">
      <header className="topbar">
        <button className="menu-btn" aria-expanded={abierto} aria-controls="nav" onClick={() => setAbierto(a => !a)}>
          {abierto ? 'Cerrar' : 'Menú'}
        </button>
        <span className="topbar-title">SG-SST</span>
      </header>
      <nav id="nav" className={`sidebar ${abierto ? 'open' : ''}`}>
        <div className="brand">
          <span className="brand-mark" aria-hidden="true" />
          <div><strong>SG-SST</strong><small>Decreto 1072 de 2015</small></div>
        </div>
        <NavLink to="/" end className="nav-link nav-home">Panel</NavLink>
        {NAV.map(g => (
          <section key={g.ciclo} className={`nav-group ciclo-${g.ciclo}`}>
            <h2><span className={`ciclo-letra c-${g.ciclo}`}>{g.ciclo}</span>{g.nombre}</h2>
            {g.items.map(([to, label]) => <NavLink key={to} to={to} className="nav-link">{label}</NavLink>)}
          </section>
        ))}
        <div className="nav-foot">
          <NavLink to="/empresa" className="nav-link">Empresa y usuarios</NavLink>
          <p className="who">{user.nombre}<small>{ROLES[user.app_rol] ?? user.app_rol}</small></p>
          <button className="btn ghost small" onClick={logout}>Cerrar sesión</button>
          <p className="credito">Elaborado por el Ing. Hector Ramirez</p>
        </div>
      </nav>
      <main className="main">{children}</main>
    </div>
  );
}
