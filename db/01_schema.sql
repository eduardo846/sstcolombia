-- =====================================================================
-- SG-SST Colombia · Esquema de datos
-- Base normativa: Decreto 1072/2015 (Lib.2 Parte 2 Tít.4 Cap.6),
-- Resolución 0312/2019 (Estándares Mínimos), Ley 1562/2012, GTC 45.
-- =====================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS api;   -- expuesto por PostgREST
CREATE SCHEMA IF NOT EXISTS app;   -- funciones auxiliares (no expuesto)

-- ---------- Contexto de la sesión (claims del JWT) -------------------
CREATE OR REPLACE FUNCTION app.claims() RETURNS json LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::json
$$;
CREATE OR REPLACE FUNCTION app.empresa_actual() RETURNS int LANGUAGE sql STABLE AS $$
  SELECT nullif(app.claims()->>'empresa_id', '')::int
$$;
CREATE OR REPLACE FUNCTION app.rol_actual() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT coalesce(app.claims()->>'app_rol', '')
$$;
CREATE OR REPLACE FUNCTION app.puede_escribir() RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT app.rol_actual() IN ('admin', 'responsable_sst', 'copasst')
$$;

-- ---------- Festivos Colombia (Ley 51/1983 "Ley Emiliani") ----------
CREATE OR REPLACE FUNCTION app.pascua(y int) RETURNS date LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE a int; b int; c int; d int; e int; f int; g int; h int; i int; k int; l int; m int;
BEGIN
  a := y % 19; b := y / 100; c := y % 100; d := b / 4; e := b % 4;
  f := (b + 8) / 25; g := (b - f + 1) / 3; h := (19*a + b - d - g + 15) % 30;
  i := c / 4; k := c % 4; l := (32 + 2*e + 2*i - h - k) % 7; m := (a + 11*h + 22*l) / 451;
  RETURN make_date(y, (h + l - 7*m + 114) / 31, ((h + l - 7*m + 114) % 31) + 1);
END $$;

CREATE OR REPLACE FUNCTION app.lunes_siguiente(d date) RETURNS date LANGUAGE sql IMMUTABLE AS $$
  SELECT d + ((8 - extract(isodow FROM d)::int) % 7)
$$;

CREATE OR REPLACE FUNCTION app.festivos_colombia(y int) RETURNS SETOF date LANGUAGE sql IMMUTABLE AS $$
  WITH p AS (SELECT app.pascua(y) AS e)
  SELECT unnest(ARRAY[
    make_date(y,1,1), make_date(y,5,1), make_date(y,7,20), make_date(y,8,7),
    make_date(y,12,8), make_date(y,12,25),
    app.lunes_siguiente(make_date(y,1,6)),  app.lunes_siguiente(make_date(y,3,19)),
    app.lunes_siguiente(make_date(y,6,29)), app.lunes_siguiente(make_date(y,8,15)),
    app.lunes_siguiente(make_date(y,10,12)),app.lunes_siguiente(make_date(y,11,1)),
    app.lunes_siguiente(make_date(y,11,11)),
    p.e - 3, p.e - 2,          -- Jueves y Viernes Santo
    p.e + 43, p.e + 64, p.e + 71  -- Ascensión, Corpus Christi, Sagrado Corazón (lunes)
  ]) FROM p
$$;

CREATE OR REPLACE FUNCTION app.sumar_dias_habiles(p_fecha date, p_dias int) RETURNS date
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE d date := p_fecha; n int := 0;
BEGIN
  WHILE n < p_dias LOOP
    d := d + 1;
    IF extract(isodow FROM d) < 6
       AND d NOT IN (SELECT app.festivos_colombia(extract(year FROM d)::int)) THEN
      n := n + 1;
    END IF;
  END LOOP;
  RETURN d;
END $$;

-- ---------- Usuarios ------------------------------------------------
CREATE TABLE auth.usuarios (
  id          int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id  int NOT NULL,
  email       text NOT NULL UNIQUE CHECK (email = lower(email)),
  nombre      text NOT NULL,
  rol         text NOT NULL CHECK (rol IN ('admin','responsable_sst','copasst','consulta')),
  pass_hash   text NOT NULL,
  activo      boolean NOT NULL DEFAULT true,
  creado      timestamptz NOT NULL DEFAULT now()
);

-- ---------- Empresa -------------------------------------------------
CREATE TABLE api.empresas (
  id                    int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nit                   text NOT NULL UNIQUE,
  razon_social          text NOT NULL,
  codigo_ciiu           text,
  actividad_economica   text,
  clase_riesgo          smallint NOT NULL DEFAULT 1 CHECK (clase_riesgo BETWEEN 1 AND 5),
  numero_trabajadores   int NOT NULL DEFAULT 0 CHECK (numero_trabajadores >= 0),
  unidad_agropecuaria   boolean NOT NULL DEFAULT false,
  arl                   text,
  representante_legal   text,
  responsable_sst       text,
  licencia_sst          text,
  licencia_vence        date,
  curso_50h_fecha       date,
  direccion             text,
  ciudad                text,
  departamento          text,
  creado                timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE auth.usuarios ADD FOREIGN KEY (empresa_id) REFERENCES api.empresas(id);

-- Res. 0312/2019 Arts. 3, 7, 8, 9 y 16: qué tabla de estándares aplica
CREATE OR REPLACE FUNCTION app.tipo_estandares(e api.empresas) RETURNS text LANGUAGE sql STABLE AS $$
  SELECT CASE
    WHEN e.unidad_agropecuaria AND e.clase_riesgo <= 3 AND e.numero_trabajadores <= 10 THEN '3'
    WHEN e.clase_riesgo <= 3 AND e.numero_trabajadores <= 10 THEN '7'
    WHEN e.clase_riesgo <= 3 AND e.numero_trabajadores <= 50 THEN '21'
    ELSE '60' END
$$;

-- ---------- Catálogos globales -------------------------------------
CREATE TABLE api.estandares_0312 (
  codigo       text PRIMARY KEY,
  ciclo        char(1) NOT NULL CHECK (ciclo IN ('P','H','V','A')),
  grupo        text NOT NULL,
  subgrupo     text NOT NULL,
  descripcion  text NOT NULL,
  peso         numeric(5,2) NOT NULL,
  aplica_7     boolean NOT NULL DEFAULT false,
  aplica_21    boolean NOT NULL DEFAULT false,
  aplica_3     boolean NOT NULL DEFAULT false,   -- solo unidades agropecuarias (Art. 7), fuera de la tabla de 60
  orden        int NOT NULL
);

CREATE TABLE api.normativa (
  id           int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tipo         text NOT NULL,
  numero       text NOT NULL,
  anio         int NOT NULL,
  emisor       text NOT NULL,
  tema         text NOT NULL,
  requisito    text NOT NULL,
  aplica       text NOT NULL DEFAULT 'Todas las empresas',
  UNIQUE (tipo, numero, anio, tema)
);

-- ---------- Tablas por empresa -------------------------------------
CREATE TABLE api.trabajadores (
  id                 int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id         int NOT NULL REFERENCES api.empresas(id),
  tipo_documento     text NOT NULL DEFAULT 'CC' CHECK (tipo_documento IN ('CC','CE','PEP','PPT','TI','PA')),
  documento          text NOT NULL,
  nombres            text NOT NULL,
  apellidos          text NOT NULL,
  fecha_nacimiento   date,
  sexo               text CHECK (sexo IN ('F','M','Otro')),
  escolaridad        text,
  cargo              text,
  area               text,
  tipo_vinculacion   text NOT NULL DEFAULT 'directo'
                     CHECK (tipo_vinculacion IN ('directo','temporal','contratista','aprendiz','practicante','independiente')),
  fecha_ingreso      date,
  fecha_retiro       date,
  eps                text,
  afp                text,
  clase_riesgo_arl   smallint CHECK (clase_riesgo_arl BETWEEN 1 AND 5),
  alto_riesgo_2090   boolean NOT NULL DEFAULT false,
  telefono           text,
  contacto_emergencia text,
  UNIQUE (empresa_id, tipo_documento, documento)
);

CREATE TABLE api.nomina_mensual (   -- denominadores de indicadores (Res. 0312 Art. 30)
  id                       int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id               int NOT NULL REFERENCES api.empresas(id),
  anio                     int NOT NULL,
  mes                      int NOT NULL CHECK (mes BETWEEN 1 AND 12),
  trabajadores             int NOT NULL CHECK (trabajadores > 0),
  dias_trabajo_programados int NOT NULL CHECK (dias_trabajo_programados > 0),
  UNIQUE (empresa_id, anio, mes)
);

CREATE TABLE api.autoevaluaciones (
  id               int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id       int NOT NULL REFERENCES api.empresas(id),
  anio             int NOT NULL,
  fecha            date NOT NULL DEFAULT current_date,
  tipo_estandares  text NOT NULL CHECK (tipo_estandares IN ('3','7','21','60')),
  responsable      text,
  estado           text NOT NULL DEFAULT 'borrador' CHECK (estado IN ('borrador','cerrada')),
  observaciones    text,
  UNIQUE (empresa_id, anio)
);

CREATE TABLE api.autoevaluacion_items (
  id                 int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id         int NOT NULL REFERENCES api.empresas(id),
  autoevaluacion_id  int NOT NULL REFERENCES api.autoevaluaciones(id) ON DELETE CASCADE,
  codigo             text NOT NULL REFERENCES api.estandares_0312(codigo),
  calificacion       text CHECK (calificacion IN ('cumple','no_cumple','no_aplica')),
  justificacion      text,
  evidencia          text,
  UNIQUE (autoevaluacion_id, codigo),
  CHECK (calificacion IS DISTINCT FROM 'no_aplica' OR coalesce(justificacion,'') <> '')
);

CREATE TABLE api.plan_anual (
  id                int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id        int NOT NULL REFERENCES api.empresas(id),
  anio              int NOT NULL,
  actividad         text NOT NULL,
  estandar_codigo   text REFERENCES api.estandares_0312(codigo),
  responsable       text,
  recursos          text,
  fecha_programada  date NOT NULL,
  fecha_ejecucion   date,
  estado            text NOT NULL DEFAULT 'programada'
                    CHECK (estado IN ('programada','en_ejecucion','ejecutada','reprogramada','cancelada')),
  observaciones     text
);

CREATE TABLE api.matriz_legal (
  id                  int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id          int NOT NULL REFERENCES api.empresas(id),
  normativa_id        int REFERENCES api.normativa(id),
  tipo                text NOT NULL,
  numero              text NOT NULL,
  anio                int NOT NULL,
  emisor              text,
  tema                text,
  requisito           text NOT NULL,
  evidencia           text,
  cumplimiento        text NOT NULL DEFAULT 'no_evaluado'
                      CHECK (cumplimiento IN ('cumple','parcial','no_cumple','no_aplica','no_evaluado')),
  responsable         text,
  fecha_verificacion  date,
  UNIQUE (empresa_id, tipo, numero, anio, requisito)
);

-- GTC 45 (2012): identificación de peligros y valoración de riesgos
CREATE TABLE api.peligros (
  id                        int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                int NOT NULL REFERENCES api.empresas(id),
  proceso                   text NOT NULL,
  zona_lugar                text,
  actividad                 text NOT NULL,
  tarea                     text,
  rutinaria                 boolean NOT NULL DEFAULT true,
  clasificacion             text NOT NULL CHECK (clasificacion IN
                            ('Biológico','Físico','Químico','Psicosocial','Biomecánico',
                             'Condiciones de seguridad','Fenómenos naturales')),
  descripcion               text NOT NULL,
  efectos_posibles          text,
  control_fuente            text,
  control_medio             text,
  control_individuo         text,
  nd                        smallint NOT NULL CHECK (nd IN (0,2,6,10)),
  ne                        smallint NOT NULL CHECK (ne BETWEEN 1 AND 4),
  nc                        smallint NOT NULL CHECK (nc IN (10,25,60,100)),
  np                        int GENERATED ALWAYS AS (nd * ne) STORED,
  nr                        int GENERATED ALWAYS AS (nd * ne * nc) STORED,
  nivel_riesgo              text GENERATED ALWAYS AS (
                              CASE WHEN nd*ne*nc >= 600 THEN 'I'
                                   WHEN nd*ne*nc >= 150 THEN 'II'
                                   WHEN nd*ne*nc >= 40  THEN 'III' ELSE 'IV' END) STORED,
  expuestos                 int NOT NULL DEFAULT 0,
  peor_consecuencia         text,
  requisito_legal           text,
  med_eliminacion           text,
  med_sustitucion           text,
  med_ingenieria            text,
  med_administrativos       text,
  med_epp                   text,
  fecha_actualizacion       date NOT NULL DEFAULT current_date
);

-- Incidentes y accidentes de trabajo (Res. 1401/2007, Dec. 1072/2015)
CREATE TABLE api.eventos (
  id                        int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id                int NOT NULL REFERENCES api.empresas(id),
  trabajador_id             int REFERENCES api.trabajadores(id),
  tipo                      text NOT NULL CHECK (tipo IN ('incidente','accidente','accidente_grave','accidente_mortal')),
  fecha_evento              date NOT NULL,
  hora_evento               time,
  lugar                     text,
  descripcion               text NOT NULL,
  tipo_lesion               text,
  parte_cuerpo              text,
  agente                    text,
  mecanismo                 text,
  dias_incapacidad          int NOT NULL DEFAULT 0 CHECK (dias_incapacidad >= 0),
  dias_cargados             int NOT NULL DEFAULT 0 CHECK (dias_cargados >= 0),
  furat_numero              text,
  fecha_reporte_arl         date,
  fecha_reporte_eps         date,
  fecha_reporte_mintrabajo  date,
  fecha_investigacion       date,
  equipo_investigador       text,
  causas_inmediatas         text,
  causas_basicas            text,
  medidas_control           text,
  fecha_remision_arl        date,
  lecciones_aprendidas      text
);

CREATE TABLE api.enfermedades_laborales (
  id                    int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id            int NOT NULL REFERENCES api.empresas(id),
  trabajador_id         int NOT NULL REFERENCES api.trabajadores(id),
  grupo_decreto_1477    text,
  fecha_diagnostico     date,
  fecha_calificacion    date,
  entidad_calificadora  text CHECK (entidad_calificadora IN ('EPS','ARL','Junta Regional','Junta Nacional','AFP')),
  estado                text NOT NULL DEFAULT 'en_estudio'
                        CHECK (estado IN ('en_estudio','calificada_laboral','calificada_comun','en_controversia')),
  fecha_reporte_arl     date,
  observaciones         text
);

CREATE TABLE api.ausentismo (
  id             int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id     int NOT NULL REFERENCES api.empresas(id),
  trabajador_id  int NOT NULL REFERENCES api.trabajadores(id),
  origen         text NOT NULL CHECK (origen IN ('enfermedad_general','accidente_trabajo','enfermedad_laboral',
                                                 'licencia_maternidad','licencia_paternidad','otro')),
  fecha_inicio   date NOT NULL,
  fecha_fin      date NOT NULL,
  dias           int GENERATED ALWAYS AS (fecha_fin - fecha_inicio + 1) STORED,
  evento_id      int REFERENCES api.eventos(id),
  observaciones  text,
  CHECK (fecha_fin >= fecha_inicio)
);

-- Solo concepto de aptitud: la historia clínica la custodia la IPS
CREATE TABLE api.evaluaciones_medicas (
  id               int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id       int NOT NULL REFERENCES api.empresas(id),
  trabajador_id    int NOT NULL REFERENCES api.trabajadores(id),
  tipo             text NOT NULL CHECK (tipo IN ('ingreso','periodica','post_incapacidad','cambio_ocupacion','egreso')),
  fecha            date NOT NULL,
  ips              text,
  concepto         text NOT NULL CHECK (concepto IN ('apto','apto_con_restricciones','no_apto','aplazado')),
  restricciones    text,
  recomendaciones  text,
  fecha_proxima    date
);

CREATE TABLE api.capacitaciones (
  id              int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id      int NOT NULL REFERENCES api.empresas(id),
  tema            text NOT NULL,
  tipo            text NOT NULL CHECK (tipo IN ('induccion','reinduccion','copasst','convivencia','brigada',
                                                'alturas','espacios_confinados','riesgo_especifico','otra')),
  fecha           date NOT NULL,
  horas           numeric(5,1),
  facilitador     text,
  estado          text NOT NULL DEFAULT 'programada' CHECK (estado IN ('programada','ejecutada','cancelada')),
  observaciones   text
);

CREATE TABLE api.asistencias (
  id               int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id       int NOT NULL REFERENCES api.empresas(id),
  capacitacion_id  int NOT NULL REFERENCES api.capacitaciones(id) ON DELETE CASCADE,
  trabajador_id    int NOT NULL REFERENCES api.trabajadores(id),
  asistio          boolean NOT NULL DEFAULT true,
  calificacion     numeric(4,1),
  UNIQUE (capacitacion_id, trabajador_id)
);

CREATE TABLE api.epp_entregas (
  id                int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id        int NOT NULL REFERENCES api.empresas(id),
  trabajador_id     int NOT NULL REFERENCES api.trabajadores(id),
  elemento          text NOT NULL,
  cantidad          int NOT NULL DEFAULT 1,
  fecha_entrega     date NOT NULL,
  fecha_reposicion  date,
  capacitado_uso    boolean NOT NULL DEFAULT false,
  firma_recibido    boolean NOT NULL DEFAULT false
);

CREATE TABLE api.inspecciones (
  id                 int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id         int NOT NULL REFERENCES api.empresas(id),
  tipo               text NOT NULL CHECK (tipo IN ('locativa','extintores','botiquines','epp','herramientas',
                                                   'equipos_alturas','vehiculos','orden_aseo','quimicos','otra')),
  area               text,
  fecha              date NOT NULL,
  responsable        text,
  participa_copasst  boolean NOT NULL DEFAULT false,
  hallazgos          text,
  estado             text NOT NULL DEFAULT 'programada' CHECK (estado IN ('programada','ejecutada','cancelada'))
);

CREATE TABLE api.comites (
  id                  int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id          int NOT NULL REFERENCES api.empresas(id),
  tipo                text NOT NULL CHECK (tipo IN ('COPASST','VIGIA_SST','CONVIVENCIA','VIGIA_CONVIVENCIA','BRIGADA')),
  fecha_conformacion  date NOT NULL,
  fecha_vencimiento   date GENERATED ALWAYS AS ((fecha_conformacion + interval '2 years')::date) STORED,
  acta                text,
  observaciones       text
);

CREATE TABLE api.comite_miembros (
  id              int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id      int NOT NULL REFERENCES api.empresas(id),
  comite_id       int NOT NULL REFERENCES api.comites(id) ON DELETE CASCADE,
  trabajador_id   int NOT NULL REFERENCES api.trabajadores(id),
  rol             text NOT NULL CHECK (rol IN ('presidente','secretario','principal','suplente','brigadista','lider_brigada')),
  representa      text CHECK (representa IN ('empleador','trabajadores')),
  UNIQUE (comite_id, trabajador_id)
);

CREATE TABLE api.reuniones_comite (
  id          int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id  int NOT NULL REFERENCES api.empresas(id),
  comite_id   int NOT NULL REFERENCES api.comites(id) ON DELETE CASCADE,
  fecha       date NOT NULL,
  acta_numero text,
  temas       text,
  compromisos text
);

CREATE TABLE api.acciones (   -- ACPM: correctivas, preventivas y de mejora (Dec. 1072 Art. 2.2.4.6.33)
  id              int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id      int NOT NULL REFERENCES api.empresas(id),
  tipo            text NOT NULL CHECK (tipo IN ('correctiva','preventiva','mejora')),
  origen          text NOT NULL CHECK (origen IN ('autoevaluacion','auditoria','revision_direccion','investigacion',
                                                  'inspeccion','arl','autoridad','copasst','otro')),
  referencia      text,
  descripcion     text NOT NULL,
  causa_raiz      text,
  responsable     text,
  fecha_limite    date,
  fecha_cierre    date,
  estado          text NOT NULL DEFAULT 'abierta' CHECK (estado IN ('abierta','en_proceso','cerrada')),
  eficacia        text CHECK (eficacia IN ('eficaz','no_eficaz','pendiente'))
);

CREATE TABLE api.documentos (   -- Dec. 1072 Art. 2.2.4.6.12 y 2.2.4.6.13
  id                int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empresa_id        int NOT NULL REFERENCES api.empresas(id),
  codigo            text NOT NULL,
  nombre            text NOT NULL,
  tipo              text NOT NULL CHECK (tipo IN ('politica','objetivos','manual','procedimiento','programa','plan',
                                                  'formato','registro','matriz','informe','otro')),
  version           text NOT NULL DEFAULT '1',
  fecha_aprobacion  date,
  aprobado_por      text,
  retencion_anios   int NOT NULL DEFAULT 20,
  ubicacion         text,
  proxima_revision  date,
  UNIQUE (empresa_id, codigo, version)
);
