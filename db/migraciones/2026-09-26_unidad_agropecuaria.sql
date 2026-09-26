-- =====================================================================
-- Migración: estándares para unidades de producción agropecuaria
-- Res. 0312/2019 Art. 7 (3 estándares) y Art. 8 (riesgo IV-V usa los 60)
-- Para bases ya inicializadas. Se puede ejecutar más de una vez.
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/migraciones/2026-09-26_unidad_agropecuaria.sql
-- =====================================================================
BEGIN;

ALTER TABLE api.estandares_0312 ADD COLUMN IF NOT EXISTS aplica_3 boolean NOT NULL DEFAULT false;

INSERT INTO api.estandares_0312 (codigo, ciclo, grupo, subgrupo, descripcion, peso, aplica_7, aplica_21, aplica_3, orden) VALUES
('UPA.1','H','Unidades de producción agropecuaria (100%)','Estándares mínimos Art. 7 (100%)','Identificar los peligros en los procesos productivos, evaluar y valorar los riesgos y establecer los controles',33.34,false,false,true,61),
('UPA.2','H','Unidades de producción agropecuaria (100%)','Estándares mínimos Art. 7 (100%)','Desarrollar actividades para prevenir accidentes de trabajo y enfermedades laborales',33.33,false,false,true,62),
('UPA.3','H','Unidades de producción agropecuaria (100%)','Estándares mínimos Art. 7 (100%)','Proteger la seguridad y salud de todas las personas que realizan actividades en la unidad',33.33,false,false,true,63)
ON CONFLICT (codigo) DO NOTHING;

ALTER TABLE api.autoevaluaciones DROP CONSTRAINT IF EXISTS autoevaluaciones_tipo_estandares_check;
ALTER TABLE api.autoevaluaciones ADD CONSTRAINT autoevaluaciones_tipo_estandares_check
  CHECK (tipo_estandares IN ('3','7','21','60'));

CREATE OR REPLACE FUNCTION app.tipo_estandares(e api.empresas) RETURNS text LANGUAGE sql STABLE AS $$
  SELECT CASE
    WHEN e.unidad_agropecuaria AND e.clase_riesgo <= 3 AND e.numero_trabajadores <= 10 THEN '3'
    WHEN e.clase_riesgo <= 3 AND e.numero_trabajadores <= 10 THEN '7'
    WHEN e.clase_riesgo <= 3 AND e.numero_trabajadores <= 50 THEN '21'
    ELSE '60' END
$$;

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

COMMIT;

-- PostgREST recarga el esquema para ver la columna nueva
NOTIFY pgrst, 'reload schema';
