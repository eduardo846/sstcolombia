-- =====================================================================
-- Seguridad (RLS multiempresa), vistas calculadas y funciones RPC
-- =====================================================================
GRANT USAGE ON SCHEMA api, app TO web_anon, authenticated;

-- ---------- RLS: cada usuario solo ve los datos de su empresa --------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'trabajadores','nomina_mensual','autoevaluaciones','autoevaluacion_items','plan_anual',
    'matriz_legal','peligros','eventos','enfermedades_laborales','ausentismo',
    'evaluaciones_medicas','capacitaciones','asistencias','epp_entregas','inspecciones',
    'comites','comite_miembros','reuniones_comite','acciones','documentos']
  LOOP
    EXECUTE format('ALTER TABLE api.%I ALTER COLUMN empresa_id SET DEFAULT app.empresa_actual()', t);
    EXECUTE format('ALTER TABLE api.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY lectura ON api.%I FOR SELECT TO authenticated
                    USING (empresa_id = app.empresa_actual())', t);
    EXECUTE format('CREATE POLICY escritura ON api.%I FOR ALL TO authenticated
                    USING (empresa_id = app.empresa_actual() AND app.puede_escribir())
                    WITH CHECK (empresa_id = app.empresa_actual() AND app.puede_escribir())', t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON api.%I TO authenticated', t);
  END LOOP;
END $$;

ALTER TABLE api.empresas ENABLE ROW LEVEL SECURITY;
CREATE POLICY lectura ON api.empresas FOR SELECT TO authenticated USING (id = app.empresa_actual());
CREATE POLICY edicion ON api.empresas FOR UPDATE TO authenticated
  USING (id = app.empresa_actual() AND app.rol_actual() = 'admin')
  WITH CHECK (id = app.empresa_actual());
GRANT SELECT, UPDATE ON api.empresas TO authenticated;

GRANT SELECT ON api.estandares_0312, api.normativa TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA api TO authenticated;

-- ---------- Vistas (security_invoker => respetan RLS) ----------------
CREATE VIEW api.v_empresa WITH (security_invoker = true) AS
SELECT e.*, app.tipo_estandares(e) AS estandares_aplicables,
       (SELECT count(*) FROM api.trabajadores t
         WHERE t.fecha_retiro IS NULL OR t.fecha_retiro > current_date) AS trabajadores_activos
FROM api.empresas e;

CREATE VIEW api.v_peligros WITH (security_invoker = true) AS
SELECT p.*,
  CASE WHEN p.np >= 24 THEN 'Muy alto' WHEN p.np >= 10 THEN 'Alto'
       WHEN p.np >= 6 THEN 'Medio' ELSE 'Bajo' END AS interpretacion_np,
  CASE p.nivel_riesgo
       WHEN 'I'   THEN 'No aceptable'
       WHEN 'II'  THEN 'No aceptable o aceptable con control específico'
       WHEN 'III' THEN 'Mejorable'
       ELSE 'Aceptable' END AS aceptabilidad
FROM api.peligros p;

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
  (ev.tipo IN ('accidente_grave','accidente_mortal') AND ev.fecha_reporte_mintrabajo IS NULL) AS falta_reporte_mintrabajo
FROM api.eventos ev
LEFT JOIN api.trabajadores t ON t.id = ev.trabajador_id;

-- Res. 0312 Art. 27-28: resultado de la autoevaluación
CREATE VIEW api.v_autoevaluacion_resultado WITH (security_invoker = true) AS
WITH it AS (
  SELECT i.autoevaluacion_id, e.ciclo, e.peso, i.calificacion,
         CASE WHEN i.calificacion IN ('cumple','no_aplica') THEN e.peso ELSE 0 END AS obtenido
  FROM api.autoevaluacion_items i JOIN api.estandares_0312 e ON e.codigo = i.codigo
), ciclo AS (
  SELECT autoevaluacion_id,
         jsonb_object_agg(ciclo, jsonb_build_object('peso', peso, 'obtenido', obtenido)) AS por_ciclo
  FROM (SELECT autoevaluacion_id, ciclo, sum(peso) AS peso, sum(obtenido) AS obtenido
        FROM it GROUP BY 1, 2) x
  GROUP BY autoevaluacion_id
), tot AS (
  SELECT autoevaluacion_id, count(*) AS items,
         count(*) FILTER (WHERE calificacion IS NULL) AS pendientes,
         count(*) FILTER (WHERE calificacion = 'no_cumple') AS no_cumple,
         round(100 * sum(obtenido) / sum(peso), 2) AS puntaje
  FROM it GROUP BY autoevaluacion_id
)
SELECT a.id AS autoevaluacion_id, a.anio, a.tipo_estandares, a.estado,
       t.items, t.pendientes, t.no_cumple, c.por_ciclo, t.puntaje,
       CASE WHEN t.puntaje < 60 THEN 'Crítico'
            WHEN t.puntaje <= 85 THEN 'Moderadamente aceptable'
            ELSE 'Aceptable' END AS valoracion,
       CASE WHEN t.puntaje < 60 THEN
              'Plan de mejoramiento inmediato; enviarlo a la ARL y reportar a Mintrabajo; seguimiento anual de la ARL'
            WHEN t.puntaje <= 85 THEN
              'Plan de mejoramiento a disposición de Mintrabajo; enviarlo a la ARL; plan de visitas'
            ELSE 'Mantener la calificación y las evidencias; incluir las mejoras detectadas en el plan anual' END AS accion_requerida
FROM api.autoevaluaciones a
JOIN tot t ON t.autoevaluacion_id = a.id
JOIN ciclo c ON c.autoevaluacion_id = a.id;

-- Res. 0312 Art. 30: indicadores mensuales
CREATE VIEW api.v_indicadores_mensuales WITH (security_invoker = true) AS
SELECT n.anio, n.mes, n.trabajadores, n.dias_trabajo_programados,
  at.num_at, at.dias_incapacidad, at.dias_cargados, au.dias_ausencia,
  round(100.0 * at.num_at / n.trabajadores, 2) AS frecuencia_accidentalidad,
  round(100.0 * (at.dias_incapacidad + at.dias_cargados) / n.trabajadores, 2) AS severidad_accidentalidad,
  round(100.0 * au.dias_ausencia / n.dias_trabajo_programados, 2) AS ausentismo_causa_medica
FROM api.nomina_mensual n
CROSS JOIN LATERAL (
  SELECT count(*) AS num_at, coalesce(sum(ev.dias_incapacidad),0) AS dias_incapacidad,
         coalesce(sum(ev.dias_cargados),0) AS dias_cargados
  FROM api.eventos ev
  WHERE ev.tipo <> 'incidente'
    AND ev.fecha_evento >= make_date(n.anio, n.mes, 1)
    AND ev.fecha_evento <  make_date(n.anio, n.mes, 1) + interval '1 month') at
CROSS JOIN LATERAL (
  SELECT coalesce(sum(greatest(0,
           least(a.fecha_fin, (make_date(n.anio, n.mes, 1) + interval '1 month - 1 day')::date)
         - greatest(a.fecha_inicio, make_date(n.anio, n.mes, 1)) + 1)),0) AS dias_ausencia
  FROM api.ausentismo a
  WHERE a.origen IN ('enfermedad_general','accidente_trabajo','enfermedad_laboral')) au;

-- Res. 0312 Art. 30: indicadores anuales
CREATE VIEW api.v_indicadores_anuales WITH (security_invoker = true) AS
WITH base AS (
  SELECT anio, avg(trabajadores) AS promedio_trabajadores FROM api.nomina_mensual GROUP BY anio
)
SELECT b.anio, round(b.promedio_trabajadores, 1) AS promedio_trabajadores,
  (SELECT count(*) FROM api.eventos e WHERE e.tipo <> 'incidente' AND extract(year FROM e.fecha_evento) = b.anio) AS total_at,
  (SELECT count(*) FROM api.eventos e WHERE e.tipo = 'accidente_mortal' AND extract(year FROM e.fecha_evento) = b.anio) AS at_mortales,
  round(100.0 * (SELECT count(*) FROM api.eventos e WHERE e.tipo = 'accidente_mortal' AND extract(year FROM e.fecha_evento) = b.anio)
        / nullif((SELECT count(*) FROM api.eventos e WHERE e.tipo <> 'incidente' AND extract(year FROM e.fecha_evento) = b.anio),0), 2)
        AS proporcion_at_mortales,
  round(100000.0 * (SELECT count(*) FROM api.enfermedades_laborales el
                    WHERE el.estado = 'calificada_laboral' AND el.fecha_calificacion <= make_date(b.anio,12,31))
        / b.promedio_trabajadores, 1) AS prevalencia_el,
  round(100000.0 * (SELECT count(*) FROM api.enfermedades_laborales el
                    WHERE el.estado = 'calificada_laboral' AND extract(year FROM el.fecha_calificacion) = b.anio)
        / b.promedio_trabajadores, 1) AS incidencia_el
FROM base b;

CREATE VIEW api.v_comites WITH (security_invoker = true) AS
SELECT c.*,
  (SELECT count(*) FROM api.comite_miembros m WHERE m.comite_id = c.id) AS miembros,
  (SELECT max(r.fecha) FROM api.reuniones_comite r WHERE r.comite_id = c.id) AS ultima_reunion,
  c.fecha_vencimiento < current_date AS vencido
FROM api.comites c;

CREATE VIEW api.v_dashboard WITH (security_invoker = true) AS
SELECT
  (SELECT count(*) FROM api.trabajadores WHERE fecha_retiro IS NULL OR fecha_retiro > current_date) AS trabajadores_activos,
  (SELECT count(*) FROM api.peligros WHERE nivel_riesgo IN ('I','II')) AS riesgos_no_aceptables,
  (SELECT count(*) FROM api.v_eventos WHERE estado_reporte IN ('pendiente','vencido')) AS eventos_sin_reporte,
  (SELECT count(*) FROM api.v_eventos WHERE estado_investigacion IN ('pendiente','vencida')) AS investigaciones_pendientes,
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
  (SELECT count(*) FROM api.epp_entregas WHERE fecha_reposicion < current_date) AS epp_por_reponer;

GRANT SELECT ON api.v_empresa, api.v_peligros, api.v_eventos, api.v_autoevaluacion_resultado,
  api.v_indicadores_mensuales, api.v_indicadores_anuales, api.v_comites, api.v_dashboard TO authenticated;

-- ---------- JWT (HS256) sin extensiones externas ----------------------
CREATE OR REPLACE FUNCTION auth.b64url(data bytea) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT translate(encode(data, 'base64'), E'+/=\n', '-_')
$$;
CREATE OR REPLACE FUNCTION auth.firmar(p_payload json) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = auth, public AS $$
  WITH x AS (
    SELECT auth.b64url(convert_to('{"alg":"HS256","typ":"JWT"}', 'utf8')) || '.' ||
           auth.b64url(convert_to(p_payload::text, 'utf8')) AS s)
  SELECT x.s || '.' || auth.b64url(public.hmac(x.s, (SELECT valor FROM auth.config WHERE clave = 'jwt_secret'), 'sha256'))
  FROM x
$$;

-- ---------- RPC: autenticación ---------------------------------------
CREATE OR REPLACE FUNCTION api.login(email text, password text) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = auth, public AS $$
DECLARE u auth.usuarios;
BEGIN
  SELECT * INTO u FROM auth.usuarios WHERE usuarios.email = lower(login.email) AND activo;
  IF NOT FOUND OR u.pass_hash <> public.crypt(login.password, u.pass_hash) THEN
    RAISE invalid_password USING message = 'Correo o contraseña incorrectos';
  END IF;
  RETURN json_build_object('token', auth.firmar(json_build_object(
    'role', 'authenticated', 'app_rol', u.rol, 'empresa_id', u.empresa_id,
    'email', u.email, 'nombre', u.nombre,
    'exp', extract(epoch FROM now() + interval '8 hours')::bigint)));
END $$;
REVOKE ALL ON FUNCTION api.login(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.login(text, text) TO web_anon, authenticated;

CREATE OR REPLACE FUNCTION api.crear_usuario(email text, password text, nombre text, rol text) RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = auth, public AS $$
DECLARE nuevo int;
BEGIN
  IF app.rol_actual() <> 'admin' THEN
    RAISE insufficient_privilege USING message = 'Solo un administrador puede crear usuarios';
  END IF;
  IF length(password) < 10 THEN
    RAISE check_violation USING message = 'La contraseña debe tener al menos 10 caracteres';
  END IF;
  INSERT INTO auth.usuarios (empresa_id, email, nombre, rol, pass_hash)
  VALUES (app.empresa_actual(), lower(email), nombre, rol, public.crypt(password, public.gen_salt('bf')))
  RETURNING id INTO nuevo;
  RETURN nuevo;
END $$;
REVOKE ALL ON FUNCTION api.crear_usuario(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.crear_usuario(text, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION api.cambiar_password(actual text, nueva text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = auth, public AS $$
BEGIN
  IF length(nueva) < 10 THEN
    RAISE check_violation USING message = 'La contraseña debe tener al menos 10 caracteres';
  END IF;
  UPDATE auth.usuarios SET pass_hash = public.crypt(nueva, public.gen_salt('bf'))
  WHERE email = app.claims()->>'email' AND pass_hash = public.crypt(actual, pass_hash);
  IF NOT FOUND THEN RAISE invalid_password USING message = 'La contraseña actual no es correcta'; END IF;
END $$;
REVOKE ALL ON FUNCTION api.cambiar_password(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.cambiar_password(text, text) TO authenticated;

-- ---------- RPC: diagnóstico de hora ---------------------------------
-- GET /rpc/hora_servidor: zona horaria y fecha que usa la base frente a la hora de Colombia
CREATE OR REPLACE FUNCTION api.hora_servidor() RETURNS json
LANGUAGE sql STABLE AS $$
  SELECT json_build_object(
    'zona_horaria_base', current_setting('TimeZone'),
    'hora_base', to_char(now(), 'YYYY-MM-DD HH24:MI:SS TZ'),
    'fecha_base', current_date,
    'hora_colombia', to_char(now() AT TIME ZONE 'America/Bogota', 'YYYY-MM-DD HH24:MI:SS'),
    'fecha_colombia', (now() AT TIME ZONE 'America/Bogota')::date,
    'fecha_coincide', current_date = (now() AT TIME ZONE 'America/Bogota')::date,
    'zona_correcta', current_setting('TimeZone') = 'America/Bogota'
  )
$$;
GRANT EXECUTE ON FUNCTION api.hora_servidor() TO web_anon, authenticated;

-- ---------- RPC: operaciones del SG-SST ------------------------------
-- Crea la autoevaluación del año con los estándares que aplican a la empresa
CREATE OR REPLACE FUNCTION api.iniciar_autoevaluacion(p_anio int) RETURNS int
LANGUAGE plpgsql AS $$
DECLARE e api.empresas; tipo text; nueva int;
BEGIN
  SELECT * INTO e FROM api.empresas WHERE id = app.empresa_actual();
  tipo := app.tipo_estandares(e);
  INSERT INTO api.autoevaluaciones (anio, tipo_estandares, responsable)
  VALUES (p_anio, tipo, app.claims()->>'nombre') RETURNING id INTO nueva;
  INSERT INTO api.autoevaluacion_items (autoevaluacion_id, codigo)
  SELECT nueva, codigo FROM api.estandares_0312
  WHERE (tipo = '60' AND NOT aplica_3) OR (tipo = '21' AND aplica_21) OR (tipo = '7' AND aplica_7)
     OR (tipo = '3' AND aplica_3)
  ORDER BY orden;
  RETURN nueva;
END $$;

-- Plan de mejoramiento (Res. 0312 Art. 28): una acción por estándar no cumplido
CREATE OR REPLACE FUNCTION api.generar_plan_mejoramiento(p_autoevaluacion int) RETURNS int
LANGUAGE plpgsql AS $$
DECLARE n int;
BEGIN
  INSERT INTO api.acciones (tipo, origen, referencia, descripcion, fecha_limite)
  SELECT 'correctiva', 'autoevaluacion', 'Res. 0312 · ' || i.codigo,
         'Cerrar brecha: ' || e.descripcion, current_date + 90
  FROM api.autoevaluacion_items i
  JOIN api.estandares_0312 e ON e.codigo = i.codigo
  WHERE i.autoevaluacion_id = p_autoevaluacion AND i.calificacion = 'no_cumple'
    AND NOT EXISTS (SELECT 1 FROM api.acciones a
                    WHERE a.origen = 'autoevaluacion' AND a.referencia = 'Res. 0312 · ' || i.codigo
                      AND a.estado <> 'cerrada');
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;

-- Copia el catálogo normativo base a la matriz legal de la empresa
CREATE OR REPLACE FUNCTION api.cargar_matriz_legal_base() RETURNS int
LANGUAGE plpgsql AS $$
DECLARE n int;
BEGIN
  INSERT INTO api.matriz_legal (normativa_id, tipo, numero, anio, emisor, tema, requisito)
  SELECT nv.id, nv.tipo, nv.numero, nv.anio, nv.emisor, nv.tema, nv.requisito
  FROM api.normativa nv
  WHERE NOT EXISTS (SELECT 1 FROM api.matriz_legal m WHERE m.normativa_id = nv.id);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;

CREATE OR REPLACE FUNCTION api.festivos(p_anio int) RETURNS SETOF date LANGUAGE sql IMMUTABLE AS $$
  SELECT d FROM app.festivos_colombia(p_anio) d ORDER BY d
$$;

-- Alta de una empresa nueva con su administrador (ejecutar como superusuario)
CREATE OR REPLACE FUNCTION auth.alta_empresa(p_nit text, p_razon text, p_clase smallint, p_trabajadores int,
                                            p_email text, p_nombre text, p_password text) RETURNS int
LANGUAGE plpgsql AS $$
DECLARE eid int;
BEGIN
  INSERT INTO api.empresas (nit, razon_social, clase_riesgo, numero_trabajadores)
  VALUES (p_nit, p_razon, p_clase, p_trabajadores) RETURNING id INTO eid;
  INSERT INTO auth.usuarios (empresa_id, email, nombre, rol, pass_hash)
  VALUES (eid, lower(p_email), p_nombre, 'admin', public.crypt(p_password, public.gen_salt('bf')));
  RETURN eid;
END $$;
REVOKE ALL ON FUNCTION auth.alta_empresa(text, text, smallint, int, text, text, text) FROM PUBLIC;

NOTIFY pgrst, 'reload schema';
