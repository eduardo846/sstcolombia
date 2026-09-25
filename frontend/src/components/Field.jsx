import { useEffect, useState } from 'react';
import { api } from '../api.js';
import { REFS } from '../resources.js';

const refCache = {};
export function cargarRef(nombre) {
  if (!refCache[nombre]) {
    const r = REFS[nombre];
    refCache[nombre] = api.list(nombre, `select=${r.select}&order=${r.order}&limit=2000`)
      .then(rows => rows.map(x => [String(x[r.key ?? 'id']), r.label(x)]))
      .catch(e => { delete refCache[nombre]; throw e; });
  }
  return refCache[nombre];
}
export const limpiarRef = nombre => { delete refCache[nombre]; };

export function useOpciones(nombre) {
  const [opts, setOpts] = useState([]);
  useEffect(() => {
    if (nombre) cargarRef(nombre).then(setOpts).catch(() => setOpts([]));
  }, [nombre]);
  return opts;
}

export default function Field({ f, value, onChange }) {
  const refOpts = useOpciones(f.t === 'ref' ? f.ref : null);
  const id = `f-${f.k}`;
  const v = value ?? '';

  if (f.t === 'bool') {
    return (
      <label className="field check" htmlFor={id}>
        <input id={id} type="checkbox" checked={!!value} onChange={e => onChange(e.target.checked)} />
        <span>{f.l}</span>
      </label>
    );
  }

  let input;
  if (f.t === 'textarea') {
    input = <textarea id={id} rows={3} value={v} required={f.req} onChange={e => onChange(e.target.value)} />;
  } else if (f.t === 'select' || f.t === 'ref') {
    const opciones = f.t === 'ref' ? refOpts : f.options;
    input = (
      <select id={id} value={String(v)} required={f.req} onChange={e => onChange(e.target.value)}>
        <option value="">Seleccionar</option>
        {opciones.map(([val, label]) => <option key={val} value={val}>{label}</option>)}
      </select>
    );
  } else {
    input = (
      <input id={id} type={f.t === 'number' ? 'number' : f.t} step={f.t === 'number' ? 'any' : undefined}
        value={v} required={f.req} onChange={e => onChange(e.target.value)} />
    );
  }
  return (
    <div className={`field ${f.t === 'textarea' ? 'wide' : ''}`}>
      <label htmlFor={id}>{f.l}{f.req && <span className="req" title="Obligatorio"> *</span>}</label>
      {input}
    </div>
  );
}

// Carga varias referencias a la vez y devuelve { tabla: { id: etiqueta } }
export function useRefMap(nombres) {
  const [map, setMap] = useState({});
  const clave = nombres.join(',');
  useEffect(() => {
    let vivo = true;
    Promise.all(nombres.map(n => cargarRef(n).then(o => [n, Object.fromEntries(o)]).catch(() => [n, {}])))
      .then(pares => { if (vivo) setMap(Object.fromEntries(pares)); });
    return () => { vivo = false; };
  }, [clave]); // eslint-disable-line react-hooks/exhaustive-deps
  return map;
}
