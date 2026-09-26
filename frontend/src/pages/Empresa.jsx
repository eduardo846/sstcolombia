import { useEffect, useState } from 'react';
import { api } from '../api.js';
import { useAuth } from '../auth.jsx';
import Field from '../components/Field.jsx';

const CAMPOS = [
  { k: 'razon_social', l: 'Razón social', t: 'text', req: true },
  { k: 'nit', l: 'NIT', t: 'text', req: true },
  { k: 'codigo_ciiu', l: 'Código CIIU', t: 'text' },
  { k: 'actividad_economica', l: 'Actividad económica', t: 'text' },
  { k: 'clase_riesgo', l: 'Clase de riesgo', t: 'select', req: true, options: [['1', 'I'], ['2', 'II'], ['3', 'III'], ['4', 'IV'], ['5', 'V']] },
  { k: 'numero_trabajadores', l: 'Número de trabajadores', t: 'number', req: true },
  { k: 'unidad_agropecuaria', l: 'Unidad de producción agropecuaria', t: 'bool' },
  { k: 'arl', l: 'ARL', t: 'text' },
  { k: 'representante_legal', l: 'Representante legal', t: 'text' },
  { k: 'responsable_sst', l: 'Responsable del SG-SST', t: 'text' },
  { k: 'licencia_sst', l: 'Licencia SST', t: 'text' },
  { k: 'licencia_vence', l: 'Vencimiento de licencia', t: 'date' },
  { k: 'curso_50h_fecha', l: 'Curso de 50 horas (fecha)', t: 'date' },
  { k: 'direccion', l: 'Dirección', t: 'text' },
  { k: 'ciudad', l: 'Ciudad', t: 'text' },
  { k: 'departamento', l: 'Departamento', t: 'text' },
];

const ROLES = [['admin', 'Administrador'], ['responsable_sst', 'Responsable SST'], ['copasst', 'COPASST'], ['consulta', 'Solo consulta']];

export default function Empresa() {
  const { user } = useAuth();
  const esAdmin = user.app_rol === 'admin';
  const [emp, setEmp] = useState(null);
  const [nuevo, setNuevo] = useState({ email: '', nombre: '', rol: 'consulta', password: '' });
  const [pw, setPw] = useState({ actual: '', nueva: '' });
  const [msg, setMsg] = useState(null);

  const cargar = () => api.one('v_empresa', 'select=*').then(setEmp).catch(e => setMsg(['rojo', e.message]));
  useEffect(() => { cargar(); }, []);

  async function run(fn, ok) {
    setMsg(null);
    try { await fn(); setMsg(['verde', ok]); } catch (e) { setMsg(['rojo', e.message]); }
  }

  const guardarEmpresa = e => {
    e.preventDefault();
    const datos = Object.fromEntries(CAMPOS.map(f => [f.k, emp[f.k] === '' ? null : emp[f.k]]));
    run(async () => { await api.update('empresas', emp.id, datos); await cargar(); }, 'Datos de la empresa guardados.');
  };
  const crearUsuario = e => {
    e.preventDefault();
    run(async () => { await api.rpc('crear_usuario', nuevo); setNuevo({ email: '', nombre: '', rol: 'consulta', password: '' }); },
      `Usuario ${nuevo.email} creado.`);
  };
  const cambiarPw = e => {
    e.preventDefault();
    run(async () => { await api.rpc('cambiar_password', pw); setPw({ actual: '', nueva: '' }); }, 'Contraseña actualizada.');
  };

  if (!emp) return <div className="page">{msg ? <p className={`alert ${msg[0]}`}>{msg[1]}</p> : <p className="muted">Cargando…</p>}</div>;

  return (
    <div className="page">
      <header className="page-head">
        <div>
          <h1>Empresa y usuarios</h1>
          <p className="norma">Con clase de riesgo {emp.clase_riesgo} y {emp.numero_trabajadores} trabajadores aplican <b>{emp.estandares_aplicables} estándares</b> (Res. 0312/2019 Arts. 3, 7, 9 y 16).
            Hay {emp.trabajadores_activos} trabajadores activos registrados.</p>
        </div>
      </header>
      {msg && <p className={`alert ${msg[0]}`} role="status">{msg[1]}</p>}

      <form className="panel" onSubmit={guardarEmpresa}>
        <h2>Datos de la empresa</h2>
        <fieldset disabled={!esAdmin} className="form-grid">
          {CAMPOS.map(f => <Field key={f.k} f={f} value={emp[f.k]} onChange={v => setEmp(s => ({ ...s, [f.k]: v }))} />)}
        </fieldset>
        {esAdmin ? <button className="btn primary">Guardar datos</button> : <p className="muted">Solo un administrador puede modificar estos datos.</p>}
      </form>

      <div className="grid-2">
        {esAdmin && (
          <form className="panel" onSubmit={crearUsuario}>
            <h2>Crear usuario</h2>
            <div className="field"><label htmlFor="u-n">Nombre</label><input id="u-n" required value={nuevo.nombre} onChange={e => setNuevo({ ...nuevo, nombre: e.target.value })} /></div>
            <div className="field"><label htmlFor="u-e">Correo</label><input id="u-e" type="email" required value={nuevo.email} onChange={e => setNuevo({ ...nuevo, email: e.target.value })} /></div>
            <div className="field"><label htmlFor="u-r">Rol</label>
              <select id="u-r" value={nuevo.rol} onChange={e => setNuevo({ ...nuevo, rol: e.target.value })}>
                {ROLES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
              </select>
            </div>
            <div className="field"><label htmlFor="u-p">Contraseña inicial (mínimo 10 caracteres)</label>
              <input id="u-p" type="password" minLength={10} required value={nuevo.password} onChange={e => setNuevo({ ...nuevo, password: e.target.value })} /></div>
            <button className="btn primary">Crear usuario</button>
          </form>
        )}
        <form className="panel" onSubmit={cambiarPw}>
          <h2>Cambiar mi contraseña</h2>
          <div className="field"><label htmlFor="p-a">Contraseña actual</label><input id="p-a" type="password" required value={pw.actual} onChange={e => setPw({ ...pw, actual: e.target.value })} /></div>
          <div className="field"><label htmlFor="p-n">Nueva contraseña</label><input id="p-n" type="password" minLength={10} required value={pw.nueva} onChange={e => setPw({ ...pw, nueva: e.target.value })} /></div>
          <button className="btn primary">Cambiar contraseña</button>
        </form>
      </div>
    </div>
  );
}
