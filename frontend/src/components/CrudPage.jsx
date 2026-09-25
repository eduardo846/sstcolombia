import { useEffect, useMemo, useState, useCallback } from 'react';
import { api, descargarCSV, fmtFecha, hoy } from '../api.js';
import { useAuth } from '../auth.jsx';
import Field, { useRefMap, limpiarRef } from './Field.jsx';
import { REFS } from '../resources.js';

// Celda de tabla con etiqueta legible y color semántico
function Celda({ f, v, refMap }) {
  let txt;
  if (v == null || v === '') txt = '';
  else if (f.t === 'bool') txt = v ? 'Sí' : 'No';
  else if (f.t === 'date') txt = fmtFecha(v);
  else if (f.t === 'select') txt = f.options.find(([o]) => o === String(v))?.[1] ?? v;
  else if (f.t === 'ref') txt = f.short ? v : refMap[f.ref]?.[String(v)] ?? `#${v}`;
  else txt = String(v).replace(/_/g, ' ');
  const tono = f.tone?.(v);
  if (tono && txt !== '') return <span className={`badge ${tono}`}>{txt}</span>;
  return f.t === 'textarea' || f.k === 'descripcion' ? <span className="clamp">{txt}</span> : txt;
}

function valorInicial(f) {
  if (f.def === 'hoy') return hoy();
  if (typeof f.def === 'function') return f.def();
  return f.def ?? (f.t === 'bool' ? false : '');
}

export default function CrudPage({ table, res }) {
  const { puedeEscribir } = useAuth();
  const [rows, setRows] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aviso, setAviso] = useState('');
  const [buscar, setBuscar] = useState('');
  const [editando, setEditando] = useState(null);
  const [guardando, setGuardando] = useState(false);

  const cols = res.fields.filter(f => f.list);
  const editables = res.fields.filter(f => !f.ro);
  const refsUsados = [...new Set(cols.filter(f => f.t === 'ref').map(f => f.ref))];
  const refMap = useRefMap(refsUsados);

  const cargar = useCallback(async () => {
    setCargando(true); setError('');
    try {
      const q = [`order=${res.order ?? 'id.desc'}`, 'limit=1000'].join('&');
      setRows(await api.list(res.listFrom ?? table, q));
    } catch (e) { setError(e.message); }
    finally { setCargando(false); }
  }, [table, res]);
  useEffect(() => { cargar(); }, [cargar]);

  const filtradas = useMemo(() => {
    const q = buscar.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter(r => cols.some(f => {
      const v = f.t === 'ref' ? refMap[f.ref]?.[String(r[f.k])] : r[f.k];
      return String(v ?? '').toLowerCase().includes(q);
    }));
  }, [rows, buscar, refMap]); // eslint-disable-line react-hooks/exhaustive-deps

  function nuevo() {
    setEditando(Object.fromEntries(editables.map(f => [f.k, valorInicial(f)])));
  }

  async function guardar(e) {
    e.preventDefault();
    setGuardando(true); setError('');
    const payload = {};
    for (const f of editables) {
      let v = editando[f.k];
      if (v === '' || v === undefined) v = null;
      else if (f.t === 'number' && v !== null) v = Number(v);
      payload[f.k] = v;
    }
    try {
      if (editando.id) await api.update(table, editando.id, payload);
      else await api.create(table, payload);
      if (REFS[table]) limpiarRef(table);
      setEditando(null);
      setAviso(editando.id ? 'Cambios guardados.' : 'Registro creado.');
      await cargar();
    } catch (err) { setError(err.message); }
    finally { setGuardando(false); }
  }

  async function eliminar(r) {
    if (!window.confirm('¿Eliminar este registro? Esta acción no se puede deshacer.')) return;
    try {
      await api.remove(table, r.id);
      if (REFS[table]) limpiarRef(table);
      setAviso('Registro eliminado.');
      cargar();
    } catch (err) { setError(err.message); }
  }

  async function accion(t) {
    if (t.confirm && !window.confirm(t.confirm)) return;
    try {
      const n = await api.rpc(t.rpc);
      setAviso(t.done ? t.done(n) : 'Listo.');
      cargar();
    } catch (err) { setError(err.message); }
  }

  function exportar() {
    descargarCSV(table, res.fields.map(f => ({
      label: f.l,
      value: r => (f.t === 'ref' && !f.short ? refMap[f.ref]?.[String(r[f.k])] ?? r[f.k] : f.t === 'bool' ? (r[f.k] ? 'Sí' : 'No') : r[f.k]),
    })), filtradas);
  }

  useEffect(() => { if (aviso) { const t = setTimeout(() => setAviso(''), 4000); return () => clearTimeout(t); } }, [aviso]);

  return (
    <div className="page">
      <header className="page-head">
        <div>
          <h1>{res.title}</h1>
          <p className="norma">{res.norma}</p>
        </div>
        <div className="actions">
          {puedeEscribir && res.toolbar?.map(t => <button key={t.rpc} className="btn ghost" onClick={() => accion(t)}>{t.label}</button>)}
          <button className="btn ghost" onClick={exportar} disabled={!filtradas.length}>Exportar CSV</button>
          {puedeEscribir && !res.noCreate && <button className="btn primary" onClick={nuevo}>Nuevo registro</button>}
        </div>
      </header>

      {error && <p className="alert rojo" role="alert">{error}</p>}
      {aviso && <p className="alert verde" role="status">{aviso}</p>}

      <div className="toolbar">
        <input type="search" placeholder="Buscar en la tabla" value={buscar} onChange={e => setBuscar(e.target.value)} aria-label="Buscar" />
        <span className="count">{filtradas.length} de {rows.length}</span>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>{cols.map(f => <th key={f.k}>{f.l}</th>)}{puedeEscribir && <th className="acc"><span className="sr">Acciones</span></th>}</tr>
          </thead>
          <tbody>
            {cargando && <tr><td colSpan={cols.length + 1} className="empty">Cargando…</td></tr>}
            {!cargando && !filtradas.length && (
              <tr><td colSpan={cols.length + 1} className="empty">
                {rows.length ? 'Ningún registro coincide con la búsqueda.' : puedeEscribir ? 'Aún no hay registros. Usa "Nuevo registro" para crear el primero.' : 'Aún no hay registros.'}
              </td></tr>
            )}
            {filtradas.map(r => (
              <tr key={r.id}>
                {cols.map(f => <td key={f.k} className={`t-${f.t}`}><Celda f={f} v={r[f.k]} refMap={refMap} /></td>)}
                {puedeEscribir && (
                  <td className="acc">
                    <button className="link" onClick={() => setEditando({ ...r })}>Editar</button>
                    <button className="link danger" onClick={() => eliminar(r)}>Eliminar</button>
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {editando && (
        <div className="modal-bg" onMouseDown={e => e.target === e.currentTarget && setEditando(null)}>
          <form className="modal" onSubmit={guardar} aria-labelledby="modal-t">
            <header>
              <h2 id="modal-t">{editando.id ? 'Editar registro' : 'Nuevo registro'}</h2>
              <button type="button" className="link" onClick={() => setEditando(null)}>Cerrar</button>
            </header>
            <div className="form-grid">
              {editables.map(f => (
                <Field key={f.k} f={f} value={editando[f.k]} onChange={v => setEditando(s => ({ ...s, [f.k]: v }))} />
              ))}
            </div>
            {error && <p className="alert rojo">{error}</p>}
            <footer>
              <button type="button" className="btn ghost" onClick={() => setEditando(null)}>Cancelar</button>
              <button className="btn primary" disabled={guardando}>{guardando ? 'Guardando…' : editando.id ? 'Guardar cambios' : 'Crear registro'}</button>
            </footer>
          </form>
        </div>
      )}
    </div>
  );
}
