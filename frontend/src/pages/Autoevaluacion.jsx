import { useEffect, useState, useCallback, useMemo } from 'react';
import { api } from '../api.js';
import { useAuth } from '../auth.jsx';
import ScoreBar from '../components/ScoreBar.jsx';

const CICLOS = { P: 'Planear', H: 'Hacer', V: 'Verificar', A: 'Actuar' };
const CALIF = [['cumple', 'Cumple'], ['no_cumple', 'No cumple'], ['no_aplica', 'No aplica']];

export default function Autoevaluacion() {
  const { puedeEscribir } = useAuth();
  const [lista, setLista] = useState([]);
  const [sel, setSel] = useState(null);
  const [items, setItems] = useState([]);
  const [res, setRes] = useState(null);
  const [anio, setAnio] = useState(new Date().getFullYear());
  const [error, setError] = useState('');
  const [aviso, setAviso] = useState('');

  const cargarLista = useCallback(async () => {
    const l = await api.list('autoevaluaciones', 'order=anio.desc');
    setLista(l);
    setSel(s => s ?? l[0]?.id ?? null);
  }, []);

  const cargarDetalle = useCallback(async id => {
    const [its, r] = await Promise.all([
      api.list('autoevaluacion_items', `autoevaluacion_id=eq.${id}&select=id,codigo,calificacion,justificacion,evidencia,estandares_0312(ciclo,grupo,subgrupo,descripcion,peso,orden)`),
      api.one('v_autoevaluacion_resultado', `autoevaluacion_id=eq.${id}`),
    ]);
    its.sort((a, b) => a.estandares_0312.orden - b.estandares_0312.orden);
    setItems(its); setRes(r);
  }, []);

  useEffect(() => { cargarLista().catch(e => setError(e.message)); }, [cargarLista]);
  useEffect(() => { if (sel) cargarDetalle(sel).catch(e => setError(e.message)); }, [sel, cargarDetalle]);

  const actual = lista.find(a => a.id === sel);
  const cerrada = actual?.estado === 'cerrada';
  const editable = puedeEscribir && !cerrada;

  async function iniciar() {
    setError('');
    try {
      const id = await api.rpc('iniciar_autoevaluacion', { p_anio: Number(anio) });
      await cargarLista(); setSel(id);
      setAviso(`Autoevaluación ${anio} creada con los estándares que aplican a la empresa.`);
    } catch (e) { setError(e.message); }
  }

  async function calificar(item, calificacion) {
    const cambios = { calificacion };
    if (calificacion === 'no_aplica' && !item.justificacion) {
      const j = window.prompt('La Res. 0312 exige justificar por qué no aplica este estándar. Escribe la justificación:');
      if (!j?.trim()) return;
      cambios.justificacion = j.trim();
    }
    await guardar(item, cambios);
  }

  async function guardar(item, cambios) {
    setError('');
    try {
      await api.update('autoevaluacion_items', item.id, cambios);
      setItems(its => its.map(i => (i.id === item.id ? { ...i, ...cambios } : i)));
      setRes(await api.one('v_autoevaluacion_resultado', `autoevaluacion_id=eq.${sel}`));
    } catch (e) { setError(e.message); }
  }

  async function cerrar() {
    if (res?.pendientes > 0) { setError(`Faltan ${res.pendientes} estándares por calificar antes de cerrar.`); return; }
    if (!window.confirm('Al cerrar, la autoevaluación queda en solo lectura. ¿Continuar?')) return;
    await api.update('autoevaluaciones', sel, { estado: 'cerrada' });
    await cargarLista(); setAviso('Autoevaluación cerrada.');
  }

  async function planMejora() {
    try {
      const n = await api.rpc('generar_plan_mejoramiento', { p_autoevaluacion: sel });
      setAviso(n ? `${n} acciones creadas en "Acciones de mejora" con plazo de 90 días.` : 'Todos los estándares incumplidos ya tienen una acción abierta.');
    } catch (e) { setError(e.message); }
  }

  const grupos = useMemo(() => {
    const g = {};
    for (const i of items) (g[i.estandares_0312.ciclo] ??= []).push(i);
    return g;
  }, [items]);

  return (
    <div className="page">
      <header className="page-head">
        <div>
          <h1>Autoevaluación de estándares mínimos</h1>
          <p className="norma">Res. 0312/2019 Arts. 27 y 28. Se realiza anualmente y se reporta a la ARL; con puntaje inferior al 85% se exige plan de mejoramiento.</p>
        </div>
        <div className="actions no-print">
          {lista.length > 0 && (
            <select value={sel ?? ''} onChange={e => setSel(Number(e.target.value))} aria-label="Año de la autoevaluación">
              {lista.map(a => <option key={a.id} value={a.id}>{a.anio} ({a.tipo_estandares} estándares{a.estado === 'cerrada' ? ', cerrada' : ''})</option>)}
            </select>
          )}
          <button className="btn ghost" onClick={() => window.print()} disabled={!items.length}>Imprimir</button>
        </div>
      </header>

      {error && <p className="alert rojo" role="alert">{error}</p>}
      {aviso && <p className="alert verde" role="status">{aviso}</p>}

      {puedeEscribir && (
        <section className="panel inline no-print">
          <label htmlFor="anio">Nueva autoevaluación para el año</label>
          <input id="anio" type="number" value={anio} onChange={e => setAnio(e.target.value)} style={{ width: '7rem' }} />
          <button className="btn primary" onClick={iniciar}>Iniciar autoevaluación</button>
        </section>
      )}

      {res && (
        <section className="panel hero">
          <ScoreBar puntaje={res.puntaje} valoracion={res.valoracion} />
          <div className="ciclos">
            {Object.entries(CICLOS).map(([c, n]) => res.por_ciclo?.[c] && (
              <div key={c} className="ciclo-chip">
                <span className={`ciclo-letra c-${c}`}>{c}</span>{n}
                <b>{Number(res.por_ciclo[c].obtenido).toLocaleString('es-CO')} / {Number(res.por_ciclo[c].peso).toLocaleString('es-CO')}</b>
              </div>
            ))}
          </div>
          <p className="accion-req">{res.accion_requerida}</p>
          {editable && (
            <div className="actions no-print">
              {res.no_cumple > 0 && <button className="btn ghost" onClick={planMejora}>Generar plan de mejoramiento</button>}
              <button className="btn ghost" onClick={cerrar}>Cerrar autoevaluación</button>
            </div>
          )}
        </section>
      )}

      {res && items.length > 0 && (
        <div className="sticky-mini no-print" aria-hidden="true">
          <ScoreBar puntaje={res.puntaje} valoracion={res.valoracion} compact />
          <span className="muted">{res.pendientes} sin calificar</span>
        </div>
      )}

      {!lista.length && !puedeEscribir && <p className="muted">Aún no hay autoevaluaciones registradas.</p>}

      {Object.entries(grupos).map(([c, its]) => (
        <section key={c} className="panel estandares">
          <h2><span className={`ciclo-letra c-${c}`}>{c}</span>{CICLOS[c]}</h2>
          {its.map((i, idx) => {
            const e = i.estandares_0312;
            const nuevoGrupo = idx === 0 || its[idx - 1].estandares_0312.subgrupo !== e.subgrupo;
            return (
              <div key={i.id}>
                {nuevoGrupo && <h3 className="subgrupo">{e.grupo}: {e.subgrupo}</h3>}
                <article className={`estandar ${i.calificacion ?? 'sin'}`}>
                  <div className="est-cod">{i.codigo}<small>{Number(e.peso).toLocaleString('es-CO')}%</small></div>
                  <div className="est-body">
                    <p>{e.descripcion}</p>
                    {(i.calificacion === 'no_aplica' || i.justificacion) && (
                      <input className="mini" placeholder="Justificación" defaultValue={i.justificacion ?? ''} disabled={!editable}
                        onBlur={ev => ev.target.value !== (i.justificacion ?? '') && guardar(i, { justificacion: ev.target.value })} />
                    )}
                    <input className="mini" placeholder="Evidencia (documento, registro, enlace)" defaultValue={i.evidencia ?? ''} disabled={!editable}
                      onBlur={ev => ev.target.value !== (i.evidencia ?? '') && guardar(i, { evidencia: ev.target.value })} />
                  </div>
                  <div className="seg" role="group" aria-label={`Calificación ${i.codigo}`}>
                    {CALIF.map(([v, l]) => (
                      <button key={v} className={i.calificacion === v ? `on ${v}` : ''} disabled={!editable}
                        aria-pressed={i.calificacion === v} onClick={() => calificar(i, v)}>{l}</button>
                    ))}
                  </div>
                </article>
              </div>
            );
          })}
        </section>
      ))}
    </div>
  );
}
