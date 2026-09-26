# SG-SST Colombia · React + PostgreSQL + PostgREST

Sistema de Gestión de Seguridad y Salud en el Trabajo alineado con el **Decreto 1072 de 2015** (Libro 2, Parte 2, Título 4, Capítulo 6) y la **Resolución 0312 de 2019** (Estándares Mínimos), organizado por el ciclo PHVA.

📘 **[Manual de usuario](docs/MANUAL_USUARIO.md)**: uso de cada módulo, roles y primeros pasos.

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

## Despliegue en la nube

```
Navegador ──► Netlify (React SPA) ──/api/*──► Render: sgsst-api-virginia (PostgREST) ──► Render PostgreSQL 18
                                   proxy                  Virginia · plan free              sstcolombiabd · Virginia
```

Los despliegues salen de la rama **`deployment`**. Todo push a esa rama redespliega la API en Render y el frontend en Netlify.

| Componente | Dónde | Detalle |
|---|---|---|
| Base de datos | Render PostgreSQL `sstcolombiabd` (workspace *pruebas*, Virginia) | Plan free: **caduca el 2026-10-26**. Antes de esa fecha, pásala a un plan de pago o haz un respaldo |
| API | Render web service `sgsst-api-virginia` | https://sgsst-api-virginia.onrender.com · Docker (`backend/Dockerfile`) · health check `/` |
| Frontend | Netlify | Build según `netlify.toml`, desde Git o con el workflow `netlify-deploy.yml` |

### Frontend en Netlify

`netlify.toml` compila `frontend/` y define dos reglas:

- **`/api/*` → `https://sgsst-api-virginia.onrender.com/:splat`**: proxy a PostgREST. El navegador solo habla con el dominio de Netlify, así que no hace falta configurar CORS.
- **`/*` → `/index.html`**: fallback de rutas de la SPA.

El workflow `.github/workflows/netlify-deploy.yml` publica la rama `deployment`. Para usarlo, crea en GitHub los secretos de repositorio `NETLIFY_AUTH_TOKEN` y `NETLIFY_SITE_ID`. La variable de repositorio `VITE_API_URL` es **opcional**:

- **Sin ella**, el frontend llama a `/api` y usa el proxy. Es la configuración recomendada.
- **Con ella**, el frontend llama directamente a esa URL HTTPS. Debe ir sin barra final, y en ese caso hay que configurar CORS en la API.

Si cambia la URL de la API, actualiza el proxy en `netlify.toml`.

### API en Render

Variables de entorno del servicio `sgsst-api-virginia`:

| Variable | Valor |
|---|---|
| `PGRST_DB_URI` | `postgresql://authenticator:<contraseña>@<host interno de la base>/<base>`. Siempre con el usuario **`authenticator`**, no con el administrador |
| `PGRST_JWT_SECRET` | El mismo valor guardado en `auth.config` (`clave = 'jwt_secret'`) |
| `PGRST_DB_SCHEMAS` | `api` |
| `PGRST_DB_ANON_ROLE` | `web_anon` |
| `PGRST_DB_MAX_ROWS` | `2000` |
| `PGRST_SERVER_CORS_ALLOWED_ORIGINS` | Opcional: el origen exacto del sitio si se usa `VITE_API_URL`. Si no se define, PostgREST acepta cualquier origen |

`render.yaml` describe el mismo servicio como Blueprint. El servicio actual se creó directamente, no desde el Blueprint.

**Diagnóstico rápido**: en el log de arranque debe aparecer `Schema cache loaded 31 Relations, ... 7 Functions`. Si aparece `0 Relations`, la base a la que apunta `PGRST_DB_URI` no está inicializada, el health check falla y Render marca el despliegue como *Timed Out*.

El plan free suspende el servicio tras un rato de inactividad. La primera petición después puede tardar entre 30 y 60 segundos.

### Inicializar una base nueva

Solo hace falta si se crea una base vacía, por ejemplo al migrar de plan. En **Settings → Secrets and variables → Actions → Secrets**, crea:

- `RENDER_DATABASE_URL`: la URL **externa** de la base (Render → base → Connect → External), con el usuario **administrador** de Render. Si lleva el usuario `authenticator`, el workflow se niega a ejecutarse.
- `AUTHENTICATOR_PASSWORD`: genérala con `openssl rand -hex 24`.
- `JWT_SECRET`: genérala con `openssl rand -hex 32`.

Luego ejecuta **Actions → Initialize Render database → Run workflow** sobre la rama `deployment`. El workflow:

1. se detiene si ya existe el esquema `api`;
2. ejecuta de `db/00_roles.sh` a `db/03_api.sql`;
3. verifica que se hayan creado los objetos.

Después, configura en Render `PGRST_DB_URI` con `AUTHENTICATOR_PASSWORD` y `PGRST_JWT_SECRET` con `JWT_SECRET`.

Si se pierde la contraseña de `authenticator`, puedes cambiarla conectándote como administrador con `\password authenticator` y actualizar `PGRST_DB_URI`. Los secretos de GitHub no se pueden volver a leer, así que guarda los valores en un gestor de contraseñas.

No cargues datos reales ni uses esta instancia para información de salud laboral hasta configurar y verificar el backend, sus credenciales, HTTPS, respaldos y controles de acceso. Las credenciales de demostración incluidas en el repositorio son solo para pruebas.

> Para producción elimina `db/04_demo.sql` **antes** del primer arranque. Los scripts de `db/` solo se ejecutan cuando el volumen `pgdata` está vacío; para reinstalar desde cero: `docker compose down -v`.

### Migraciones de una base existente

Los cambios de esquema para una base ya inicializada van en `db/migraciones/`, con un archivo por cambio, nombrado con fecha (`AAAA-MM-DD_descripcion.sql`). Cada archivo también se refleja en `db/01_schema.sql` a `db/03_api.sql` para que las bases nuevas nazcan actualizadas.

- El workflow **Migrate Render database** corre solo cuando un push a `deployment` toca `db/migraciones/`, y también se puede lanzar a mano. Usa el secreto `RENDER_DATABASE_URL` y anota cada archivo aplicado en `app.migraciones` para no repetirlo.
- El CI ejecuta cada migración dos veces sobre una base recién creada, así que deben poder correr sin error sobre una base que ya tiene el cambio.

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
| P | Autoevaluación de estándares (3, 7, 21 o 60 según la empresa) | Res. 0312/2019 Arts. 3, 7, 9, 16, 27, 28 |
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

Para crear la primera cuenta de administrador en una base Render ya inicializada, usa `psql` con la conexión externa SSL de Render. Si no tienes `psql` instalado, abre uno con Docker desde la raíz del repo, en Git Bash:

```bash
docker run -it --rm -v "$(pwd -W)/db:/db" -w / postgres:18 bash
```

Establece `PGHOST`, `PGPORT`, `PGDATABASE` y `PGUSER` con los valores de **Connect → External**; `psql` pedirá la contraseña de PostgreSQL. Después:

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
