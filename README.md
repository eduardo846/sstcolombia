# SG-SST Colombia · React + PostgreSQL + PostgREST

Sistema de Gestión de Seguridad y Salud en el Trabajo alineado con el **Decreto 1072 de 2015** (Libro 2, Parte 2, Título 4, Capítulo 6) y la **Resolución 0312 de 2019** (Estándares Mínimos), organizado por el ciclo PHVA.

## Arranque rápido

```bash
cp .env.example .env          # edita las claves
docker compose up -d --build
```

Abre http://localhost:8080 e ingresa con el usuario de demostración:

- Correo: `admin@demo.co`
- Contraseña: `CambiarYa2026`

La API queda en http://localhost:3000 (documentación OpenAPI en la raíz).

## Integración continua

El workflow de GitHub Actions en `.github/workflows/ci.yml` construye y levanta los servicios con Docker Compose en cada push y pull request, y comprueba que la API y el frontend respondan. También se puede ejecutar manualmente desde la pestaña **Actions** con **Run workflow**. Usa credenciales temporales de prueba; no despliega la aplicación ni conserva los datos al terminar.

## Despliegue del frontend en Netlify

El archivo `netlify.toml` configura el build de React y el fallback de rutas de la SPA. El workflow `.github/workflows/netlify-deploy.yml` publica automáticamente la rama `deployment` en el sitio Netlify configurado y también permite un despliegue manual. Configura en GitHub los secretos de repositorio `NETLIFY_AUTH_TOKEN` y `NETLIFY_SITE_ID`, y la variable de repositorio `VITE_API_URL` con la URL HTTPS pública de PostgREST, sin una barra final (por ejemplo, `https://api.ejemplo.com`). El frontend no incluye el backend: PostgreSQL y PostgREST deben estar desplegados por separado, con CORS habilitado para el dominio de Netlify. No guardes tokens en el repositorio ni los compartas en mensajes.

### API en Render

El archivo `render.yaml` permite crear el servicio PostgREST `sgsst-api-virginia` en Render como un Blueprint, en la región Virginia y usando el Dockerfile de `backend/`. En Render, sincroniza el Blueprint desde la rama `deployment` y configura los tres valores secretos solicitados: `PGRST_DB_URI` (URL interna de la base PostgreSQL, obtenida en Render), `PGRST_JWT_SECRET` (el mismo secreto que se guardó en `auth.config` al ejecutar `db/00_roles.sh`) y `PGRST_SERVER_CORS_ALLOWED_ORIGINS` (origen exacto del sitio Netlify, por ejemplo `https://nombre-del-sitio.netlify.app`). El servicio requiere que el esquema ya esté inicializado y que exista al menos un administrador. El plan `free` puede suspender el servicio tras inactividad y demorar la primera solicitud al reactivarse. Crear este servicio nuevo no cambia ni elimina el anterior ni migra la base de datos.

Para inicializar una base Render vacía de forma manual desde GitHub Actions, crea estos secretos de repositorio en **Settings → Secrets and variables → Actions**:

- `RENDER_DATABASE_URL`: URL externa de PostgreSQL con el usuario administrador de la base y SSL habilitado.
- `AUTHENTICATOR_PASSWORD`: genera localmente con `openssl rand -hex 24`.
- `JWT_SECRET`: genera localmente con `openssl rand -hex 32`.

No compartas ni confirmes los valores en el chat. En **Actions → Initialize Render database → Run workflow**, selecciona `deployment`. El workflow se detiene si ya existe el esquema `api`, ejecuta los scripts `db/00_roles.sh` a `db/03_api.sql` y verifica que se hayan creado objetos. Luego configura `PGRST_DB_URI` en Render usando el host de base de datos accesible desde la región del servicio y la contraseña `AUTHENTICATOR_PASSWORD`; configura `PGRST_JWT_SECRET` con el valor `JWT_SECRET`. Ejecuta este workflow solo una vez en una base vacía.

No cargues datos reales ni uses esta instancia para información de salud laboral hasta configurar y verificar el backend, sus credenciales, HTTPS, respaldos y controles de acceso. Las credenciales de demostración incluidas en el repositorio son solo para pruebas.

> Para producción elimina `db/04_demo.sql` **antes** del primer arranque. Los scripts de `db/` solo se ejecutan cuando el volumen `pgdata` está vacío; para reinstalar desde cero: `docker compose down -v`.

## Arquitectura

```
Navegador ──► nginx (web:8080) ──/api──► PostgREST (api:3000) ──► PostgreSQL 16 (db)
               React SPA                   JWT HS256                 RLS por empresa
```

No hay backend intermedio: la lógica de negocio vive en PostgreSQL (vistas, columnas generadas, funciones RPC) y PostgREST la expone como REST. La seguridad es **Row Level Security**: cada usuario solo ve y modifica filas de su `empresa_id`, que viaja firmado en el JWT.

| Esquema | Contenido | ¿Expuesto? |
|---|---|---|
| `api` | Tablas, vistas `v_*` y funciones RPC | Sí |
| `app` | Contexto de sesión, festivos, días hábiles | No |
| `auth` | Usuarios (hash bcrypt) y secreto JWT | No |

### Roles de usuario

| Rol | Permisos |
|---|---|
| `admin` | Todo, incluidos datos de la empresa y creación de usuarios |
| `responsable_sst` | Lectura y escritura en todos los módulos |
| `copasst` | Lectura y escritura en todos los módulos |
| `consulta` | Solo lectura (auditores, gerencia, ARL) |

## Módulos y soporte normativo

| Ciclo | Módulo | Norma principal |
|---|---|---|
| P | Autoevaluación de estándares (7, 21 o 60 según la empresa) | Res. 0312/2019 Arts. 3, 9, 16, 27, 28 |
| P | Plan anual de trabajo | Estándar 2.4.1 |
| P | Matriz legal con catálogo base de 37 normas | Estándar 2.7.1 |
| P | Documentos con retención de 20 años | Dec. 1072 Art. 2.2.4.6.13 |
| P | COPASST, Vigía, Convivencia y Brigada (vigencia 2 años) | Res. 2013/1986; Res. 652 y 1356/2012 |
| H | Trabajadores y perfil sociodemográfico | Estándares 1.1.4, 1.1.5, 3.1.1 |
| H | Matriz de peligros con NP, NR y nivel calculados | GTC 45 de 2012 |
| H | Evaluaciones médicas (solo concepto de aptitud) | Res. 1843/2025 |
| H | Capacitaciones, asistencia, EPP, inspecciones | Estándares 1.2.1, 4.2.4, 4.2.6 |
| V | Accidentes e incidentes con semáforo de plazos | Dec. 1295/1994; Res. 1401/2007 |
| V | Enfermedades laborales y ausentismo | Dec. 1477/2014 |
| V | Indicadores mínimos | Res. 0312/2019 Art. 30 |
| A | Acciones correctivas, preventivas y de mejora | Dec. 1072 Arts. 2.2.4.6.33–34 |

### Reglas automáticas en la base de datos

- **Tabla de estándares aplicable**: ≤10 trabajadores y riesgo I–III → 7; 11–50 y riesgo I–III → 21; más de 50 o riesgo IV–V → 60.
- **Puntaje 0312**: suma de pesos de estándares que cumplen o no aplican (con justificación obligatoria). Menor a 60% crítico, 60–85% moderadamente aceptable, mayor a 85% aceptable, con la acción exigida para cada rango.
- **Plan de mejoramiento**: `generar_plan_mejoramiento` crea una acción correctiva por cada estándar incumplido.
- **Plazo de reporte FURAT**: 2 días hábiles, descontando fines de semana y **festivos colombianos calculados para cualquier año** (Ley Emiliani y fechas móviles de Semana Santa).
- **Plazo de investigación**: 15 días calendario.
- **GTC 45**: NP = ND × NE, NR = NP × NC, nivel I (600–4000), II (150–500), III (40–120), IV (20).
- **Indicadores**: frecuencia, severidad, mortalidad, prevalencia, incidencia y ausentismo con las fórmulas del Art. 30.

## Operación

**Alta de una empresa nueva** (como superusuario):

```bash
docker compose exec db psql -U postgres -d sgsst -c \
  "SELECT auth.alta_empresa('900111222-3','Mi Empresa S.A.S.',2::smallint,35,'sst@miempresa.co','Nombre Responsable','ClaveSegura2026');"
```

Para crear la primera cuenta de administrador en una base Render ya inicializada, ejecuta `psql` desde Git Bash usando la conexión externa SSL de Render. Establece `PGHOST`, `PGPORT`, `PGDATABASE` y `PGUSER` con los valores de **Connect → External connection**; `psql` pedirá la contraseña de PostgreSQL. Después:

```bash
export PGSSLMODE=require
read -r -s -p "Nueva contraseña del administrador: " SG_ADMIN_PASSWORD; printf '\n'
export SG_ADMIN_PASSWORD
psql -v ON_ERROR_STOP=1 -f db/05_create_admin.sql
unset SG_ADMIN_PASSWORD
```

El script pregunta los datos de la empresa y del administrador. No uses la contraseña de demostración ni incluyas contraseñas en comandos, archivos versionados o mensajes.

**Respaldo y restauración:**

```bash
docker compose exec db pg_dump -U postgres -Fc sgsst > sgsst_$(date +%F).dump
docker compose exec -T db pg_restore -U postgres -d sgsst --clean < sgsst_2026-09-25.dump
```

**Desarrollo del frontend** (con la base y la API en Docker):

```bash
cd frontend && npm install && npm run dev   # http://localhost:5173, /api -> :3000
```

**Uso de la API desde otras herramientas:**

```bash
TOKEN=$(curl -s -X POST localhost:3000/rpc/login -H 'Content-Type: application/json' \
  -d '{"email":"admin@demo.co","password":"CambiarYa2026"}' | jq -r .token)
curl -s localhost:3000/v_indicadores_mensuales?anio=eq.2026 -H "Authorization: Bearer $TOKEN"
```

## Endurecimiento para producción

- Cambia todas las claves de `.env` y genera `JWT_SECRET` con `openssl rand -base64 48`.
- Publica solo el puerto 8080 detrás de HTTPS (Caddy, Traefik o nginx con Let's Encrypt). Los puertos 5432 y 3000 ya quedan limitados a `127.0.0.1`.
- Cambia la contraseña del usuario demo o elimina `04_demo.sql`.
- Programa `pg_dump` diario: el Decreto 1072 exige conservar registros durante 20 años.

## Advertencia sobre la normativa

El catálogo normativo refleja la normativa conocida hasta mediados de 2026. La regulación de SST en Colombia cambia con frecuencia: verifica vigencia y aplicabilidad de cada requisito en fuentes oficiales (Mintrabajo, Función Pública, Secretaría del Senado) antes de auditorías, y confirma contra el texto oficial la asignación de estándares para empresas de 7 y 21 estándares. Presta especial atención a la transición de la Res. 2346/2007 a la Res. 1843/2025 y a los ajustes derivados de la Ley 2466 de 2025.

## Hoja de ruta sugerida

- Batería de riesgo psicosocial (Res. 2764/2022) con periodicidad según nivel de riesgo.
- Módulo PESV (Ley 2050/2020, Res. 40595/2022) para empresas obligadas.
- Permisos de trabajo en alturas y espacios confinados (Res. 4272/2021 y 0491/2020).
- Carga de evidencias en almacenamiento de objetos (S3 o MinIO) con URL firmada.
- Exportación del reporte de autoevaluación en el formato de la ARL.
