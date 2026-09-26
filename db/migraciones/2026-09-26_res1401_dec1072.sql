-- =====================================================================
-- Migración: controles de la Res. 1401/2007 y módulos del Dec. 1072/2015
--   Res. 1401 Art. 7 (equipo investigador) y Art. 14 (remisión a la ARL)
--   Dec. 1072 Arts. 2.2.4.6.25 a 2.2.4.6.31: emergencias, gestión del cambio,
--   contratistas, auditoría y revisión por la dirección
-- Para bases ya inicializadas. Se puede ejecutar más de una vez.
-- =====================================================================
BEGIN;

ALTER TABLE api.eventos ADD COLUMN IF NOT EXISTS inv_jefe_inmediato boolean NOT NULL DEFAULT false;
ALTER TABLE api.eventos ADD COLUMN IF NOT EXISTS inv_copasst boolean NOT NULL DEFAULT false;
ALTER TABLE api.eventos ADD COLUMN IF NOT EXISTS inv_responsable_sst boolean NOT NULL DEFAULT false;
ALTER TABLE api.eventos ADD COLUMN IF NOT EXISTS inv_profesional_licencia boolean NOT NULL DEFAULT false;

-- ---------- Decreto 1072 de 2015: módulos complementarios -----------
-- Plan de prevención, preparación y respuesta ante emergencias (Art. 2.2.4.6.25)
CREATE TABLE IF NOT EXISTS api.planes_emergencia (
  id                    int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id            int NOT NULL REFERENCES api.empresas(id),
  sede                  text NOT NULL,
  fecha_elaboracion     date NOT NULL,
  fecha_actualizacion   date,
  amenazas              text,
  vulnerabilidad        text,
  recursos              text,
  divulgado             boolean NOT NULL DEFAULT false,
  ubicacion             text,
  proxima_revision      date
);

CREATE TABLE IF NOT EXISTS api.simulacros (
  id                    int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id            int NOT NULL REFERENCES api.empresas(id),
  plan_id               int REFERENCES api.planes_emergencia(id),
  escenario             text NOT NULL,
  fecha_programada      date NOT NULL,
  fecha_ejecucion       date,
  participantes         int CHECK (participantes >= 0),
  tiempo_respuesta_min  numeric(6,1) CHECK (tiempo_respuesta_min >= 0),
  hallazgos             text,
  estado                text NOT NULL DEFAULT 'programada' CHECK (estado IN ('programada','ejecutada','cancelada'))
);

-- Gestión del cambio (Art. 2.2.4.6.26)
CREATE TABLE IF NOT EXISTS api.gestion_cambio (
  id                      int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id              int NOT NULL REFERENCES api.empresas(id),
  fecha                   date NOT NULL DEFAULT current_date,
  origen                  text NOT NULL CHECK (origen IN ('interno','externo')),
  descripcion             text NOT NULL,
  peligros_identificados  text,
  medidas                 text,
  informado_trabajadores  boolean NOT NULL DEFAULT false,
  responsable             text,
  fecha_implementacion    date,
  estado                  text NOT NULL DEFAULT 'abierta' CHECK (estado IN ('abierta','en_proceso','cerrada'))
);

-- Contratistas y proveedores (Arts. 2.2.4.6.27 y 2.2.4.6.28)
CREATE TABLE IF NOT EXISTS api.contratistas (
  id                    int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id            int NOT NULL REFERENCES api.empresas(id),
  razon_social          text NOT NULL,
  nit                   text,
  servicio              text NOT NULL,
  fecha_inicio          date,
  fecha_fin             date,
  trabajadores          int CHECK (trabajadores >= 0),
  afiliacion_arl        boolean NOT NULL DEFAULT false,
  induccion_sst         boolean NOT NULL DEFAULT false,
  calificacion_sgsst    numeric(5,2) CHECK (calificacion_sgsst BETWEEN 0 AND 100),
  fecha_verificacion    date,
  observaciones         text
);

-- Auditoría anual con participación del COPASST (Arts. 2.2.4.6.29 y 2.2.4.6.30)
CREATE TABLE IF NOT EXISTS api.auditorias (
  id                    int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id            int NOT NULL REFERENCES api.empresas(id),
  anio                  int NOT NULL,
  alcance               text NOT NULL,
  auditor               text,
  fecha_programada      date NOT NULL,
  fecha_ejecucion       date,
  participa_copasst     boolean NOT NULL DEFAULT false,
  hallazgos             text,
  conclusiones          text,
  informe               text,
  estado                text NOT NULL DEFAULT 'programada' CHECK (estado IN ('programada','ejecutada','cancelada'))
);

-- Revisión por la alta dirección, mínimo una vez al año (Art. 2.2.4.6.31)
CREATE TABLE IF NOT EXISTS api.revisiones_direccion (
  id                    int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id            int NOT NULL REFERENCES api.empresas(id),
  anio                  int NOT NULL,
  fecha_programada      date NOT NULL,
  fecha_ejecucion       date,
  participantes         text,
  entradas              text,
  conclusiones          text,
  decisiones            text,
  comunicada_copasst    boolean NOT NULL DEFAULT false,
  estado                text NOT NULL DEFAULT 'programada' CHECK (estado IN ('programada','ejecutada','cancelada'))
);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['planes_emergencia','simulacros','gestion_cambio','contratistas','auditorias','revisiones_direccion']
  LOOP
    EXECUTE format('ALTER TABLE api.%I ALTER COLUMN empresa_id SET DEFAULT app.empresa_actual()', t);
    EXECUTE format('ALTER TABLE api.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS lectura ON api.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS escritura ON api.%I', t);
    EXECUTE format('CREATE POLICY lectura ON api.%I FOR SELECT TO authenticated
                    USING (empresa_id = app.empresa_actual())', t);
    EXECUTE format('CREATE POLICY escritura ON api.%I FOR ALL TO authenticated
                    USING (empresa_id = app.empresa_actual() AND app.puede_escribir())
                    WITH CHECK (empresa_id = app.empresa_actual() AND app.puede_escribir())', t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON api.%I TO authenticated', t);
  END LOOP;
END $$;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA api TO authenticated;

-- v_eventos cambia de columnas: se recrea junto con v_dashboard, que depende de ella
DROP VIEW IF EXISTS api.v_dashboard;
DROP VIEW IF EXISTS api.v_eventos;

CREATE VIEW api.v_eventos WITH (security_invoker = true) AS
SELECT ev.*,
  t.nombres || ' ' || t.apellidos AS trabajador,
  app.sumar_dias_habiles(ev.fecha_evento, 2) AS limite_reporte,
  ev.fecha_evento + 15 AS limite_investigacion,
  CASE WHEN ev.tipo = 'incidente' THEN 'no_requiere'
       WHEN ev.fecha_reporte_arl IS NOT NULL THEN
            CASE WHEN ev.fecha_reporte_arl <= app.sumar_dias_habiles(ev.fecha_evento, 2)
                 THEN 'a_tiempo' ELSE 'extemporaneo' END
       WHEN current_date > app.sumar_dias_habiles(ev.fecha_evento, 2) THEN 'vencido'
       ELSE 'pendiente' END AS estado_reporte,
  CASE WHEN ev.fecha_investigacion IS NOT NULL THEN
            CASE WHEN ev.fecha_investigacion <= ev.fecha_evento + 15 THEN 'a_tiempo' ELSE 'extemporanea' END
       WHEN current_date > ev.fecha_evento + 15 THEN 'vencida'
       ELSE 'pendiente' END AS estado_investigacion,
  (ev.tipo IN ('accidente_grave','accidente_mortal') AND ev.fecha_reporte_mintrabajo IS NULL) AS falta_reporte_mintrabajo,
  -- Dec. 1072 Art. 2.2.4.1.7: graves y mortales a la Dirección Territorial en 2 días hábiles
  CASE WHEN ev.tipo NOT IN ('accidente_grave','accidente_mortal') THEN 'no_requiere'
       WHEN ev.fecha_reporte_mintrabajo IS NOT NULL THEN
            CASE WHEN ev.fecha_reporte_mintrabajo <= app.sumar_dias_habiles(ev.fecha_evento, 2)
                 THEN 'a_tiempo' ELSE 'extemporaneo' END
       WHEN current_date > app.sumar_dias_habiles(ev.fecha_evento, 2) THEN 'vencido'
       ELSE 'pendiente' END AS estado_reporte_mintrabajo,
  -- Res. 1401/2007 Art. 14: investigación de graves y mortales remitida a la ARL en 15 días
  CASE WHEN ev.tipo NOT IN ('accidente_grave','accidente_mortal') THEN 'no_requiere'
       WHEN ev.fecha_remision_arl IS NOT NULL THEN
            CASE WHEN ev.fecha_remision_arl <= ev.fecha_evento + 15 THEN 'a_tiempo' ELSE 'extemporanea' END
       WHEN current_date > ev.fecha_evento + 15 THEN 'vencida'
       ELSE 'pendiente' END AS estado_remision_arl,
  -- Res. 1401/2007 Art. 7: jefe inmediato, COPASST o vigía y responsable del SG-SST;
  -- en graves y mortales, también un profesional con licencia en SST
  (ev.inv_jefe_inmediato AND ev.inv_copasst AND ev.inv_responsable_sst
   AND (ev.tipo NOT IN ('accidente_grave','accidente_mortal') OR ev.inv_profesional_licencia)) AS equipo_completo
FROM api.eventos ev
LEFT JOIN api.trabajadores t ON t.id = ev.trabajador_id;

CREATE VIEW api.v_dashboard WITH (security_invoker = true) AS
SELECT
  (SELECT count(*) FROM api.trabajadores WHERE fecha_retiro IS NULL OR fecha_retiro > current_date) AS trabajadores_activos,
  (SELECT count(*) FROM api.peligros WHERE nivel_riesgo IN ('I','II')) AS riesgos_no_aceptables,
  (SELECT count(*) FROM api.v_eventos WHERE estado_reporte IN ('pendiente','vencido')) AS eventos_sin_reporte,
  (SELECT count(*) FROM api.v_eventos WHERE estado_investigacion IN ('pendiente','vencida')) AS investigaciones_pendientes,
  (SELECT count(*) FROM api.v_eventos WHERE estado_reporte_mintrabajo IN ('pendiente','vencido')) AS reportes_mintrabajo_pendientes,
  (SELECT count(*) FROM api.v_eventos WHERE estado_remision_arl IN ('pendiente','vencida')) AS remisiones_arl_pendientes,
  (SELECT count(*) FROM api.v_eventos WHERE fecha_investigacion IS NOT NULL AND NOT equipo_completo) AS investigaciones_equipo_incompleto,
  (SELECT count(*) FROM api.acciones WHERE estado <> 'cerrada') AS acciones_abiertas,
  (SELECT count(*) FROM api.acciones WHERE estado <> 'cerrada' AND fecha_limite < current_date) AS acciones_vencidas,
  (SELECT count(*) FROM api.evaluaciones_medicas em
     WHERE em.fecha_proxima < current_date
       AND NOT EXISTS (SELECT 1 FROM api.evaluaciones_medicas x
                       WHERE x.trabajador_id = em.trabajador_id AND x.fecha > em.fecha)) AS examenes_vencidos,
  (SELECT count(*) FROM api.v_comites WHERE vencido) AS comites_vencidos,
  (SELECT round(100.0 * count(*) FILTER (WHERE estado = 'ejecutada')
               / nullif(count(*) FILTER (WHERE estado <> 'cancelada' AND fecha_programada <= current_date),0), 1)
     FROM api.plan_anual WHERE anio = extract(year FROM current_date)) AS cumplimiento_plan,
  (SELECT count(*) FROM api.matriz_legal WHERE cumplimiento IN ('no_cumple','parcial')) AS requisitos_legales_pendientes,
  (SELECT count(*) FROM api.epp_entregas WHERE fecha_reposicion < current_date) AS epp_por_reponer,
  (SELECT count(*) FROM api.planes_emergencia WHERE proxima_revision < current_date) AS planes_emergencia_por_revisar,
  (SELECT count(*) FROM api.simulacros WHERE estado = 'programada' AND fecha_programada < current_date) AS simulacros_vencidos,
  (SELECT count(*) FROM api.auditorias WHERE estado = 'programada' AND fecha_programada < current_date) AS auditorias_vencidas,
  (SELECT count(*) FROM api.revisiones_direccion WHERE estado = 'programada' AND fecha_programada < current_date) AS revisiones_vencidas,
  (SELECT count(*) FROM api.contratistas
     WHERE (fecha_fin IS NULL OR fecha_fin >= current_date) AND NOT (afiliacion_arl AND induccion_sst)) AS contratistas_sin_requisitos;

GRANT SELECT ON api.v_eventos, api.v_dashboard TO authenticated;

COMMIT;

-- PostgREST recarga el esquema para ver las tablas y columnas nuevas
NOTIFY pgrst, 'reload schema';
