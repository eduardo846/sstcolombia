-- =====================================================================
-- Datos de demostración. Omitir este archivo en producción.
-- Usuario: admin@demo.co  ·  Contraseña: CambiarYa2026
-- =====================================================================
SELECT auth.alta_empresa('900123456-7', 'Distribuciones Andinas S.A.S.', 3::smallint, 64,
                         'admin@demo.co', 'Administrador SG-SST', 'CambiarYa2026');

UPDATE api.empresas SET codigo_ciiu = '4690', actividad_economica = 'Comercio al por mayor no especializado',
  arl = 'ARL Ejemplo', ciudad = 'Bogotá D.C.', departamento = 'Cundinamarca',
  responsable_sst = 'Laura Méndez', licencia_sst = 'LIC-0000-2024', curso_50h_fecha = '2024-03-15'
WHERE nit = '900123456-7';

DO $$
DECLARE eid int := (SELECT id FROM api.empresas WHERE nit = '900123456-7');
BEGIN
  INSERT INTO api.trabajadores (empresa_id, documento, nombres, apellidos, sexo, cargo, area, fecha_ingreso, eps, clase_riesgo_arl) VALUES
   (eid,'1010101010','Carlos','Rodríguez Pérez','M','Auxiliar de bodega','Logística','2021-02-01','EPS Sura',3),
   (eid,'1020202020','Ana María','Gómez Ruiz','F','Analista de compras','Administrativa','2022-06-15','Compensar',1),
   (eid,'1030303030','Jhon Fredy','Martínez','M','Montacarguista','Logística','2020-09-10','Sanitas',3),
   (eid,'1040404040','Laura','Méndez Castro','F','Coordinadora SST','Talento humano','2023-01-09','Nueva EPS',1),
   (eid,'1050505050','Diego','Suárez Niño','M','Conductor','Distribución','2019-11-20','EPS Sura',4);

  INSERT INTO api.nomina_mensual (empresa_id, anio, mes, trabajadores, dias_trabajo_programados)
  SELECT eid, 2026, m, 64, 64 * 24 FROM generate_series(1, 8) m;

  INSERT INTO api.peligros (empresa_id, proceso, zona_lugar, actividad, tarea, clasificacion, descripcion,
                            efectos_posibles, nd, ne, nc, expuestos, med_ingenieria, med_administrativos, med_epp) VALUES
   (eid,'Almacenamiento','Bodega principal','Manipulación de carga','Descargue de camiones','Biomecánico',
    'Levantamiento manual de cargas superiores a 25 kg','Lesiones osteomusculares, lumbalgia',6,4,25,12,
    'Ayudas mecánicas (estibadores)','Programa de vigilancia osteomuscular, pausas activas','Faja no recomendada; guantes'),
   (eid,'Almacenamiento','Bodega principal','Operación de montacargas','Movimiento de estibas','Condiciones de seguridad',
    'Tránsito de montacargas en zonas peatonales','Atrapamiento, golpes, muerte',6,3,100,20,
    'Demarcación y separación de vías','Licencia y certificación de operadores','Chaleco reflectivo'),
   (eid,'Administrativo','Oficinas','Trabajo con computador','Digitación','Biomecánico',
    'Postura prolongada sedente y movimientos repetitivos','Síndrome de túnel carpiano, fatiga visual',2,4,10,15,
    NULL,'Pausas activas, inspección de puestos de trabajo',NULL);

  INSERT INTO api.eventos (empresa_id, trabajador_id, tipo, fecha_evento, lugar, descripcion, tipo_lesion, parte_cuerpo,
                           dias_incapacidad, fecha_reporte_arl, fecha_investigacion) VALUES
   (eid,(SELECT id FROM api.trabajadores WHERE documento='1010101010'),'accidente','2026-03-10','Bodega principal',
    'Golpe en mano derecha al acomodar estiba','Contusión','Mano',3,'2026-03-11','2026-03-20'),
   (eid,(SELECT id FROM api.trabajadores WHERE documento='1030303030'),'accidente','2026-06-02','Muelle de carga',
    'Torcedura de tobillo al bajar del montacargas','Esguince','Tobillo',7,'2026-06-05',NULL),
   (eid,NULL,'incidente','2026-07-14','Parqueadero','Casi colisión entre vehículo de reparto y peatón',NULL,NULL,0,NULL,NULL);

  INSERT INTO api.ausentismo (empresa_id, trabajador_id, origen, fecha_inicio, fecha_fin) VALUES
   (eid,(SELECT id FROM api.trabajadores WHERE documento='1010101010'),'accidente_trabajo','2026-03-10','2026-03-12'),
   (eid,(SELECT id FROM api.trabajadores WHERE documento='1030303030'),'accidente_trabajo','2026-06-02','2026-06-08'),
   (eid,(SELECT id FROM api.trabajadores WHERE documento='1020202020'),'enfermedad_general','2026-04-27','2026-05-03');

  INSERT INTO api.comites (empresa_id, tipo, fecha_conformacion, acta) VALUES
   (eid,'COPASST','2025-02-10','Acta 001-2025'), (eid,'CONVIVENCIA','2024-03-01','Acta 001-2024');

  INSERT INTO api.plan_anual (empresa_id, anio, actividad, estandar_codigo, responsable, fecha_programada, fecha_ejecucion, estado) VALUES
   (eid,2026,'Autoevaluación de Estándares Mínimos','2.3.1','Coordinadora SST','2026-01-31','2026-01-28','ejecutada'),
   (eid,2026,'Simulacro de evacuación','5.1.1','Brigada','2026-10-21',NULL,'programada'),
   (eid,2026,'Exámenes médicos periódicos','3.1.4','Coordinadora SST','2026-05-30','2026-06-10','ejecutada'),
   (eid,2026,'Aplicación batería de riesgo psicosocial','4.1.2','Psicólogo externo','2026-08-15',NULL,'reprogramada');

  INSERT INTO api.acciones (empresa_id, tipo, origen, referencia, descripcion, responsable, fecha_limite) VALUES
   (eid,'correctiva','investigacion','AT 2026-06-02','Instalar peldaño antideslizante en montacargas','Mantenimiento','2026-07-15');
END $$;

-- Matriz legal inicial de la empresa demo
DO $$ BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('empresa_id', (SELECT id FROM api.empresas WHERE nit='900123456-7'), 'app_rol','admin','nombre','Demo')::text, true);
  PERFORM api.cargar_matriz_legal_base();
END $$;
