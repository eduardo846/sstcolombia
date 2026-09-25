import { Routes, Route, Navigate, useParams } from 'react-router-dom';
import { useAuth } from './auth.jsx';
import { RESOURCES } from './resources.js';
import Layout from './components/Layout.jsx';
import CrudPage from './components/CrudPage.jsx';
import Login from './pages/Login.jsx';
import Dashboard from './pages/Dashboard.jsx';
import Autoevaluacion from './pages/Autoevaluacion.jsx';
import Indicadores from './pages/Indicadores.jsx';
import Empresa from './pages/Empresa.jsx';

function Recurso() {
  const { key } = useParams();
  const res = RESOURCES[key];
  return res ? <CrudPage key={key} table={key} res={res} /> : <Navigate to="/" replace />;
}

export default function App() {
  const { user } = useAuth();
  if (!user) return <Login />;
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/autoevaluacion" element={<Autoevaluacion />} />
        <Route path="/indicadores" element={<Indicadores />} />
        <Route path="/empresa" element={<Empresa />} />
        <Route path="/r/:key" element={<Recurso />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Layout>
  );
}
