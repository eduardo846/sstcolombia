# Manual de usuario · SG-SST

Guía para las personas que usan la aplicación en el día a día: responsables del SG-SST, integrantes del COPASST o Vigía, y usuarios de consulta (gerencia, auditores, ARL).

La aplicación organiza el Sistema de Gestión de Seguridad y Salud en el Trabajo según el ciclo **PHVA** (Planear, Hacer, Verificar, Actuar), el **Decreto 1072 de 2015** y la **Resolución 0312 de 2019**.

---

## 1. Ingreso

1. Abre la dirección de la aplicación que te entregó el administrador.
2. Escribe tu **correo** y tu **contraseña** y pulsa **Ingresar**.

- La sesión dura **8 horas**. Después, la aplicación te pide ingresar de nuevo.
- Si el servidor estuvo inactivo, el primer ingreso puede tardar hasta un minuto. Espera sin recargar la página.
- Si olvidaste tu contraseña, pide al administrador que te cree un usuario nuevo. La aplicación no envía correos de recuperación.

Para salir, pulsa **Cerrar sesión** al final del menú lateral.

## 2. Roles y permisos

| Rol | Qué puede hacer |
|---|---|
| **Administrador** | Todo, incluidos los datos de la empresa y la creación de usuarios |
| **Responsable SST** | Crear, editar y eliminar registros en todos los módulos |
| **COPASST** | Crear, editar y eliminar registros en todos los módulos |
| **Solo consulta** | Ver y exportar información. No ve los botones de crear, editar ni eliminar |

Cada usuario ve **solo la información de su empresa**.

## 3. Pantalla principal

El menú lateral agrupa los módulos por ciclo PHVA: **P** Planear, **H** Hacer, **V** Verificar y **A** Actuar. En el celular, ábrelo con el botón **Menú**.

El **Panel** es la pantalla de inicio y muestra:

- **Estándares mínimos**: el puntaje de la última autoevaluación y la acción que exige la norma.
- **Pendientes**: alertas que requieren atención. Haz clic en cualquiera para ir al módulo correspondiente.
  - En rojo: accidentes sin reporte a la ARL, investigaciones vencidas, riesgos en nivel I o II y acciones de mejora vencidas.
  - En amarillo: comités vencidos, evaluaciones médicas vencidas, EPP por reponer y requisitos legales pendientes.
- **Estado general**: trabajadores activos, cumplimiento del plan anual, acciones abiertas y los últimos indicadores.

## 4. Cómo se trabaja en cada módulo

Casi todos los módulos funcionan igual:

| Acción | Cómo |
|---|---|
| Crear | **Nuevo registro** → llena el formulario → **Crear registro** |
| Editar | **Editar** en la fila → cambia los datos → **Guardar cambios** |
| Eliminar | **Eliminar** en la fila → confirma. No se puede deshacer |
| Buscar | Escribe en **Buscar en la tabla**. Filtra por cualquier columna visible |
| Exportar | **Exportar CSV** descarga lo que ves en la tabla. Se abre en Excel |

- Los campos obligatorios están marcados. Si falta alguno, el formulario no se guarda.
- Algunas columnas las **calcula el sistema** y no se pueden editar, como el nivel de riesgo, los plazos o los días. Se actualizan al guardar.
- Los colores de las etiquetas indican el estado: **verde** significa cumplido o al día, **amarillo** pendiente o en proceso, y **rojo** vencido o incumplido.

## 5. Primeros pasos recomendados

Si la empresa es nueva en la aplicación, sigue este orden:

1. **Empresa y usuarios**: completa los datos de la empresa y crea los usuarios del equipo.
2. **Trabajadores**: registra a todo el personal.
3. **Autoevaluación 0312**: inicia la autoevaluación del año.
4. **Matriz legal**: pulsa **Cargar normativa base**.
5. **Matriz de peligros**, **Comités** y **Plan anual**.
6. **Base mensual**: registra cada mes para que se calculen los indicadores.

---

## 6. Planear (P)

### Autoevaluación 0312

Evalúa el cumplimiento de los estándares mínimos. La Res. 0312 exige hacerla **cada año** y reportarla a la ARL.

1. Escribe el año y pulsa **Iniciar autoevaluación**. El sistema carga automáticamente los estándares que le aplican a la empresa:
   - **3 estándares**: unidad de producción agropecuaria con 10 o menos trabajadores permanentes y riesgo I, II o III.
   - **7 estándares**: 10 o menos trabajadores y riesgo I, II o III.
   - **21 estándares**: de 11 a 50 trabajadores y riesgo I, II o III.
   - **60 estándares**: más de 50 trabajadores, o riesgo IV o V.
2. Califica cada estándar con **Cumple**, **No cumple** o **No aplica**.
   - Si eliges **No aplica**, la norma exige una **justificación**, y la aplicación la pide.
   - En **Evidencia**, anota el documento, registro o enlace que soporta la calificación.
3. El puntaje se actualiza al instante:
   - **Menos de 60 %**: crítico.
   - **Entre 60 % y 85 %**: moderadamente aceptable.
   - **Más de 85 %**: aceptable.
4. Si hay estándares incumplidos, pulsa **Generar plan de mejoramiento**. Se crea una acción correctiva por cada uno, con un plazo de 90 días, en **Acciones de mejora**.
5. Cuando todos estén calificados, pulsa **Cerrar autoevaluación**. Después de cerrarla ya no se puede modificar.

**Imprimir** genera una versión en papel o en PDF para la ARL o para auditorías. Con el selector de año puedes consultar las autoevaluaciones anteriores.

### Plan anual de trabajo

Registra las actividades del año con su responsable, fechas y estado (Programada, En ejecución, Ejecutada, Reprogramada o Cancelada). Puedes vincular cada actividad a un estándar de la 0312. El Panel calcula el porcentaje de cumplimiento del plan.

### Matriz legal

Lista las normas que debe cumplir la empresa.

- **Cargar normativa base** agrega un catálogo de normas colombianas de SST. Solo añade las que aún no tengas, así que puedes usarlo más de una vez.
- Para cada requisito registra el **Cumplimiento** (Cumple, Parcial, No cumple, No aplica), la evidencia y la fecha de verificación.

### Documentos

Es el inventario de documentos del sistema: política, objetivos, procedimientos, programas, formatos… Registra el código, la versión, la fecha de aprobación, la ubicación o enlace y la próxima revisión. La retención por defecto es de **20 años**, como exige el Decreto 1072.

### Comités

Registra el COPASST, el Vigía SST, el Comité de Convivencia, el Vigía de Convivencia y la Brigada de emergencias.

- La **fecha de vencimiento** (periodo de 2 años), el número de miembros y la última reunión se calculan solos.
- Los comités vencidos se marcan en rojo y aparecen en el Panel.

En **Integrantes** agregas a los miembros de cada comité, con su rol y a quién representan (empleador o trabajadores). En **Reuniones y actas** registras cada reunión con sus temas y compromisos. El COPASST debe reunirse al menos una vez al mes y el Comité de Convivencia al menos una vez cada trimestre.

---

## 7. Hacer (H)

### Trabajadores

Es el registro del personal: documento, datos personales, cargo, área, tipo de vinculación, EPS, fondo de pensiones, clase de riesgo ARL y si realiza actividades de alto riesgo (Decreto 2090 de 2003). Es la base de los demás módulos: todo lo que se asocia a una persona se elige de esta lista.

### Matriz de peligros (GTC 45)

1. Registra el proceso, la actividad, la clasificación del peligro, su descripción y los controles existentes.
2. Elige los niveles de **deficiencia (ND)**, **exposición (NE)** y **consecuencia (NC)**.
3. El sistema calcula:
   - **NP** = ND × NE.
   - **NR** = NP × NC.
   - El **nivel de riesgo**, de I a IV, y su aceptabilidad.
4. Registra las medidas de intervención en orden de prioridad: eliminación, sustitución, controles de ingeniería, controles administrativos y EPP.

La tabla se ordena del riesgo más alto al más bajo. Los niveles I y II aparecen como pendientes en el Panel.

### Evaluaciones médicas

Registra el **concepto de aptitud** de cada evaluación: de ingreso, periódica, post incapacidad, por cambio de ocupación o de egreso. También las restricciones, las recomendaciones y la fecha de la próxima evaluación.

> La empresa solo guarda el concepto. La historia clínica la custodia la IPS y **no debe registrarse aquí** (Res. 1843 de 2025).

### Capacitaciones y asistencias

En **Capacitaciones** registras cada formación con su tema, tipo, fecha, horas, facilitador y estado. En **Asistencias** registras qué trabajadores asistieron y su evaluación. Así queda la evidencia para los estándares de capacitación.

### Entrega de EPP

Registra cada entrega de elementos de protección personal: el trabajador, el elemento, la cantidad, la fecha, la fecha de reposición, si recibió capacitación en su uso y si firmó el recibido. Las reposiciones vencidas aparecen en el Panel.

### Inspecciones

Registra las inspecciones (locativas, de extintores, botiquines, EPP, vehículos…), si participó el COPASST y los hallazgos encontrados.

---

### Planes de emergencia y simulacros

Registra un plan de prevención, preparación y respuesta ante emergencias por sede: amenazas, análisis de vulnerabilidad, recursos, si se divulgó y la fecha de la próxima revisión. En **Simulacros** programa y registra los ejercicios de cada plan; el Decreto 1072 exige al menos uno al año. El panel avisa si un plan pasó su fecha de revisión o si un simulacro programado no se ejecutó.

### Gestión del cambio

Antes de un cambio interno (proceso, instalación, método u organización) o externo (nueva norma, nuevo conocimiento), registra los peligros que genera, las medidas de control y si se informó a los trabajadores.

### Contratistas y proveedores

Registra cada contratista con el servicio, las fechas del contrato y la verificación de su afiliación a la ARL, la inducción en SST y la calificación de su SG-SST. El panel avisa si un contratista activo no tiene afiliación o inducción verificada.

## 8. Verificar (V)

### Accidentes e incidentes

1. Registra el evento: tipo, trabajador, fecha, descripción y datos de la lesión.
2. El sistema calcula dos plazos:
   - **Límite de reporte a ARL y EPS**: 2 días hábiles. Descuenta fines de semana y festivos colombianos.
   - **Plazo de investigación**: 15 días calendario.
3. Cuando reportes o investigues, registra las fechas. Las columnas **Reporte** e **Investigación** muestran si se hizo a tiempo, si está pendiente o si se hizo fuera de plazo.
4. Completa la investigación con el equipo investigador, las causas inmediatas y básicas, las medidas de control y las lecciones aprendidas.
5. Marca quiénes participaron en la investigación. La Res. 1401 exige al jefe inmediato o supervisor, al COPASST o Vigía y al responsable del SG-SST. En accidentes graves y mortales también debe participar un profesional con licencia en SST. La columna **Equipo completo** indica si se cumplió.

Los accidentes graves y mortales tienen dos obligaciones más, cada una con su columna de estado:
- **Mintrabajo**: reporte a la Dirección Territorial del Ministerio del Trabajo en 2 días hábiles. Registra la fecha en *Reporte a Mintrabajo*.
- **Remisión ARL**: envío del informe de investigación a la ARL en 15 días. Registra la fecha en *Investigación remitida a ARL*.

### Enfermedades laborales

Registra cada caso con su grupo según el Decreto 1477 de 2014, las fechas de diagnóstico y calificación, la entidad que calificó y el estado (En estudio, Origen laboral, Origen común, En controversia).

### Ausentismo

Registra cada ausencia con su origen, las fechas desde y hasta, y opcionalmente el accidente relacionado. Los **días** se calculan solos.

### Base mensual

Aquí se registran los datos de los que salen los indicadores. Cada mes anota:
- el número de trabajadores;
- los días de trabajo programados (persona-día).

**Sin estos datos, los indicadores no se calculan.**

### Indicadores

Muestra los indicadores mínimos del Art. 30 de la Res. 0312, con su fórmula:

- **Mensuales, en gráfico de barras**: frecuencia y severidad de la accidentalidad, y ausentismo por causa médica.
- **Anuales**: proporción de accidentes mortales, y prevalencia e incidencia de enfermedad laboral.

Cambia el año con el selector y descarga los datos con **Exportar CSV**.

---

### Auditorías

Programa la auditoría anual del SG-SST y registra su alcance, el auditor, si se planificó con el COPASST, los hallazgos y las conclusiones. Crea en **Acciones de mejora** una acción con origen *Auditoría* por cada hallazgo.

### Revisión por la dirección

La alta dirección revisa el SG-SST al menos una vez al año. Registra los aspectos revisados, las conclusiones, las decisiones y si los resultados se comunicaron al COPASST. El panel avisa si una auditoría o una revisión programada pasó su fecha sin realizarse.

## 9. Actuar (A)

### Acciones de mejora

Registra las acciones correctivas, preventivas y de mejora con:
- su origen (autoevaluación, auditoría, investigación, inspección, ARL…);
- la causa raíz y el responsable;
- la fecha límite y el estado (Abierta, En proceso, Cerrada).

Al cerrar una acción, registra la fecha de cierre y verifica su **eficacia**. Las acciones vencidas aparecen en rojo en el Panel.

---

## 10. Empresa y usuarios

Está al final del menú lateral.

- **Datos de la empresa** (solo el administrador): razón social, NIT, CIIU, clase de riesgo, número de trabajadores, si es unidad de producción agropecuaria, ARL, responsable del SG-SST, licencia y otros datos. **La clase de riesgo, el número de trabajadores y la casilla de unidad agropecuaria definen cuántos estándares aplican**, así que mantenlos al día.
- **Crear usuario** (solo el administrador): nombre, correo, rol y una contraseña inicial de al menos 10 caracteres. Entrégala a la persona por un medio seguro.
- **Cambiar mi contraseña** (todos los usuarios): escribe la contraseña actual y la nueva, de al menos 10 caracteres.

## 11. Mensajes frecuentes

| Mensaje | Qué significa |
|---|---|
| *Correo o contraseña incorrectos* | Revisa los datos. Las mayúsculas cuentan en la contraseña |
| *La sesión expiró* | Pasaron 8 horas. Ingresa de nuevo |
| *Tu rol no tiene permiso para esta acción* | Tu usuario es de solo consulta, o la acción es solo para administradores |
| *Ya existe un registro con esos datos* | Hay un duplicado, por ejemplo el mismo documento o la misma autoevaluación del año |
| *No se puede completar: el registro está relacionado con otros datos* | Antes de eliminarlo, elimina los registros que dependen de él |
| *Falta un campo obligatorio* | Completa el campo indicado |

## 12. Buenas prácticas

- Registra los accidentes **el mismo día**, para no perder el plazo de 2 días hábiles.
- Actualiza la **Base mensual** al cierre de cada mes.
- Revisa el **Panel** al menos una vez por semana.
- Exporta periódicamente a CSV la información clave como respaldo propio.
- No compartas tu usuario. Cada persona debe tener el suyo, para saber quién hizo cada cambio.

> La normativa de SST en Colombia cambia con frecuencia. Verifica la vigencia de cada requisito en las fuentes oficiales (Mintrabajo, Función Pública) antes de una auditoría.
