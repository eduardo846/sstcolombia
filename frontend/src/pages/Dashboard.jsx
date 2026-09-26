import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import ScoreBar from '../components/ScoreBar.jsx';

const ALERTAS = [
  ['eventos_sin_reporte', 'accidentes sin reporte a la ARL', '/r/eventos', 'rojo'],
  ['investigaciones_pendientes', 'investigaciones pendientes o vencidas', '/r/eventos', 'rojo'],
  ['reportes_mintrabajo_pendientes', 'accidentes graves o mortales sin reporte a Mintrabajo', '/r/eventos', 'rojo'],
  ['remisiones_arl_pendientes', 'investigaciones de accidentes graves o mortales sin remitir a la ARL', '/r/eventos', 'rojo'],
  ['riesgos_no_aceptables', 'riesgos en nivel I o II', '/r/peligros', 'rojo'],
  ['acciones_vencidas', 'acciones de mejora vencidas', '/r/acciones', 'rojo'],
  ['investigaciones_equipo_incompleto', 'investigaciones sin el equipo que exige la Res. 1401', '/r/eventos', 'amarillo'],
  ['contratistas_sin_requisitos', 'contratistas activos sin afiliación a ARL o inducción verificada', '/r/contratistas', 'amarillo'],
  ['simulacros_vencidos', 'simulacros programados sin ejecutar', '/r/simulacros', 'amarillo'],
  ['planes_emergencia_por_revisar', 'planes de emergencia por revisar', '/r/planes_emergencia', 'amarillo'],
  ['auditorias_vencidas', 'auditorías programadas sin ejecutar', '/r/auditorias', 'amarillo'],
  ['revisiones_vencidas', 'revisiones por la dirección sin realizar', '/r/revisiones_direccion', 'amarillo'],
  ['comites_vencidos', 'comités con periodo vencido', '/r/comites', 'amarillo'],
  ['examenes_vencidos', 'evaluaciones médicas vencidas', '/r/evaluaciones_medicas', 'amarillo'],
  ['epp_por_reponer', 'entregas de EPP por reponer', '/r/epp_entregas', 'amarillo'],
  ['requisitos_legales_pendientes', 'requisitos legales parciales o incumplidos', '/r/matriz_legal', 'amarillo'],
];

export default function Dashboard() {
  const [d, setD] = useState(null);
  const [emp, setEmp] = useState(null);
  const [eval_, setEval] = useState(undefined);
  const [ind, setInd] = useState([]);
  const [error, setError] = useState('');

  useEffect(() => {
    const anio = new Date().getFullYear();
    Promise.all([
      api.one('v_dashboard', 'select=*'),
      api.one('v_empresa', 'select=razon_social,nit,clase_riesgo,numero_trabajadores,estandares_aplicables'),
      api.one('v_autoevaluacion_resultado', 'order=anio.desc'),
      api.list('v_indicadores_mensuales', `anio=eq.${anio}&order=mes`),
    ]).then(([a, b, c, e]) => { setD(a); setEmp(b); setEval(c); setInd(e); }).catch(e => setError(e.message));
  }, []);

  if (error) return <div className="page"><p className="alert rojo">{error}</p></div>;
  if (!d) return <div className="page"><p className="muted">Cargando panel…</p></div>;

  const activas = ALERTAS.filter(([k]) => Number(d[k]) > 0);
  const ultimo = ind[ind.length - 1];

  return (
    <div className="page">
      <header className="page-head">
        <div>
          <h1>{emp?.razon_social}</h1>
          <p className="norma">NIT {emp?.nit}, clase de riesgo {emp?.clase_riesgo}, {emp?.numero_trabajadores} trabajadores:
            aplican {emp?.estandares_aplicables} estándares mínimos.</p>
        </div>
      </header>

      <section className="panel hero">
        <h2>Estándares mínimos {eval_ ? eval_.anio : ''}</h2>
        {eval_ ? (
          <>
            <ScoreBar puntaje={eval_.puntaje} valoracion={eval_.valoracion} />
            <p className="accion-req">{eval_.accion_requerida}</p>
            {eval_.pendientes > 0 && <p className="muted">{eval_.pendientes} estándares sin calificar.</p>}
            <Link className="btn ghost" to="/autoevaluacion">Abrir autoevaluación</Link>
          </>
        ) : (
          <>
            <p>Aún no hay autoevaluación registrada. La Res. 0312 exige realizarla cada año y reportarla a la ARL.</p>
            <Link className="btn primary" to="/autoevaluacion">Iniciar autoevaluación</Link>
          </>
        )}
      </section>

      <div className="grid-2">
        <section className="panel">
          <h2>Pendientes</h2>
          {activas.length ? (
            <ul className="alert-list">
              {activas.map(([k, txt, to, tono]) => (
                <li key={k} className={tono}><Link to={to}><strong>{d[k]}</strong> {txt}</Link></li>
              ))}
            </ul>
          ) : <p className="muted">Sin pendientes. Todo está al día.</p>}
        </section>

        <section className="panel">
          <h2>Estado general</h2>
          <dl className="kv">
            <dt>Trabajadores activos</dt><dd>{d.trabajadores_activos}</dd>
            <dt>Cumplimiento del plan anual a la fecha</dt><dd>{d.cumplimiento_plan == null ? 'Sin actividades vencidas' : `${Number(d.cumplimiento_plan).toLocaleString('es-CO')}%`}</dd>
            <dt>Acciones de mejora abiertas</dt><dd>{d.acciones_abiertas}</dd>
            {ultimo && <>
              <dt>Frecuencia de accidentalidad (mes {ultimo.mes})</dt><dd>{Number(ultimo.frecuencia_accidentalidad).toLocaleString('es-CO')}</dd>
              <dt>Ausentismo por causa médica (mes {ultimo.mes})</dt><dd>{Number(ultimo.ausentismo_causa_medica).toLocaleString('es-CO')}%</dd>
            </>}
          </dl>
          <Link className="link" to="/indicadores">Ver todos los indicadores</Link>
        </section>
      </div>
    </div>
  );
}
