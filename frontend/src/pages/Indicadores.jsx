import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, descargarCSV } from '../api.js';

const MESES = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
const n = v => (v == null ? '' : Number(v).toLocaleString('es-CO', { maximumFractionDigits: 2 }));

const MENSUALES = [
  ['frecuencia_accidentalidad', 'Frecuencia de accidentalidad', '(N.º AT en el mes ÷ N.º trabajadores en el mes) × 100'],
  ['severidad_accidentalidad', 'Severidad de accidentalidad', '((Días de incapacidad por AT + días cargados) ÷ N.º trabajadores) × 100'],
  ['ausentismo_causa_medica', 'Ausentismo por causa médica', '(Días de ausencia por incapacidad laboral o común ÷ días de trabajo programados) × 100'],
];

export default function Indicadores() {
  const [anio, setAnio] = useState(new Date().getFullYear());
  const [mens, setMens] = useState([]);
  const [anual, setAnual] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    Promise.all([
      api.list('v_indicadores_mensuales', `anio=eq.${anio}&order=mes`),
      api.one('v_indicadores_anuales', `anio=eq.${anio}`),
    ]).then(([m, a]) => { setMens(m); setAnual(a); }).catch(e => setError(e.message));
  }, [anio]);

  const max = k => Math.max(1, ...mens.map(m => Number(m[k]) || 0));

  return (
    <div className="page">
      <header className="page-head">
        <div>
          <h1>Indicadores mínimos de SST</h1>
          <p className="norma">Res. 0312/2019 Art. 30. Los denominadores salen de la <Link to="/r/nomina_mensual">base mensual</Link>.</p>
        </div>
        <div className="actions">
          <input type="number" value={anio} onChange={e => setAnio(e.target.value)} aria-label="Año" style={{ width: '7rem' }} />
          <button className="btn ghost" disabled={!mens.length} onClick={() => descargarCSV(`indicadores_${anio}`, [
            { label: 'Mes', value: r => r.mes }, { label: 'Trabajadores', value: r => r.trabajadores },
            { label: 'AT', value: r => r.num_at }, ...MENSUALES.map(([k, l]) => ({ label: l, value: r => r[k] })),
          ], mens)}>Exportar CSV</button>
        </div>
      </header>
      {error && <p className="alert rojo">{error}</p>}

      {!mens.length && <p className="panel">No hay base mensual para {anio}. Registra trabajadores y días programados por mes en <Link to="/r/nomina_mensual">Base mensual</Link>.</p>}

      {MENSUALES.map(([k, l, formula]) => mens.length > 0 && (
        <section key={k} className="panel">
          <h2>{l}</h2>
          <p className="formula">{formula}</p>
          <div className="bars" role="img" aria-label={`${l} por mes`}>
            {mens.map(m => (
              <div key={m.mes} className="bar-col">
                <span className="bar-val">{n(m[k])}</span>
                <div className="bar" style={{ height: `${(Number(m[k]) / max(k)) * 100}%` }} />
                <span className="bar-lab">{MESES[m.mes]}</span>
              </div>
            ))}
          </div>
        </section>
      ))}

      {anual && (
        <section className="panel">
          <h2>Indicadores anuales {anio}</h2>
          <dl className="kv">
            <dt>Promedio de trabajadores</dt><dd>{n(anual.promedio_trabajadores)}</dd>
            <dt>Accidentes de trabajo en el año</dt><dd>{anual.total_at}</dd>
            <dt>Proporción de AT mortales<small>(AT mortales ÷ total AT) × 100</small></dt><dd>{n(anual.proporcion_at_mortales)}%</dd>
            <dt>Prevalencia de enfermedad laboral<small>(casos nuevos y antiguos ÷ promedio trabajadores) × 100.000</small></dt><dd>{n(anual.prevalencia_el)}</dd>
            <dt>Incidencia de enfermedad laboral<small>(casos nuevos ÷ promedio trabajadores) × 100.000</small></dt><dd>{n(anual.incidencia_el)}</dd>
          </dl>
        </section>
      )}
    </div>
  );
}
