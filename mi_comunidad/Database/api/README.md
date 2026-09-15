# API Módulo 8 — Express + PostgreSQL

API REST básica con Node.js, Express y PostgreSQL, preparada para producción siguiendo buenas prácticas de configuración, monitoreo, respaldo de información y despliegue automatizado (DevOps).

## Tabla de contenidos

- [Requisitos](#requisitos)
- [Instalacion](#instalacion)
- [Configuracion](#configuracion)
- [Uso de la API](#uso-de-la-api)
- [Monitoreo](#monitoreo)
- [Despliegue en la nube](#despliegue-en-la-nube)
- [CI/CD](#cicd)
- [Plan de backups](#plan-de-backups)
- [Estructura del proyecto](#estructura-del-proyecto)

## Requisitos

- Node.js >= 20
- PostgreSQL >= 14
- npm >= 10

## Instalacion

```bash
git clone <url-del-repositorio>
cd ProyectoModulo8
npm install
```

## Configuracion

1. Copia la plantilla de variables de entorno:

```bash
cp .env.example .env
```

2. Ajusta los valores en `.env`:

```env
PORT=3000
DATABASE_URL=postgresql://usuario:password@host:5432/nombre_db
LOG_LEVEL=info
NODE_ENV=development
```

3. Crea la base de datos en PostgreSQL:

```sql
CREATE DATABASE api_modulo8;
```

La tabla `productos` se crea automaticamente al iniciar la aplicacion.

## Uso de la API

Inicia el servidor:

```bash
npm start        # produccion
npm run dev      # desarrollo (recarga automatica)
```

Ejecuta los tests:

```bash
npm test
```

### Endpoints

| Metodo | Ruta          | Descripcion                              |
|--------|---------------|------------------------------------------|
| GET    | `/`           | Informacion basica de la API             |
| GET    | `/health`     | Estado de la API y conexion a la BD      |
| GET    | `/productos`  | Lista todos los productos                |
| GET    | `/productos/:id` | Obtiene un producto por id            |
| POST   | `/productos`  | Crea un producto                         |

Ejemplos:

```bash
# Crear un producto
curl -X POST http://localhost:3000/productos \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Laptop","precio":999.99,"stock":5}'

# Listar productos
curl http://localhost:3000/productos
```

### Estructura de la tabla `productos`

| Columna      | Tipo           | Restricciones            |
|--------------|----------------|--------------------------|
| id           | SERIAL         | PRIMARY KEY              |
| nombre       | VARCHAR(120)   | NOT NULL                 |
| precio       | NUMERIC(10,2)  | NOT NULL, >= 0           |
| stock        | INTEGER        | DEFAULT 0, >= 0          |
| created_at   | TIMESTAMPTZ    | DEFAULT NOW()            |

## Monitoreo

El endpoint `GET /health` permite verificar la operatividad de la API:

```json
{
  "status": "ok",
  "db": "up",
  "uptime": 1.39,
  "timestamp": "2026-08-06T00:49:17.229Z",
  "responseTimeMs": 10
}
```

- Devuelve `200` si la API y la base de datos responden (`status: ok`).
- Devuelve `503` si hay problemas de conexion (`status: degraded`).
- El Dockerfile incluye un `HEALTHCHECK` que consulta este endpoint cada 30 segundos.

## Despliegue en la nube

La aplicacion esta preparada para desplegarse en **Render** usando Docker o Blueprint.

### Opcion A: Render Blueprint (recomendada)

1. Sube el proyecto a GitHub.
2. En Render: **New > Blueprint**, conecta el repositorio.
3. Render crea automaticamente el servicio web y la base de datos PostgreSQL a partir de `render.yaml`.
4. Las variables de entorno (`DATABASE_URL`, `NODE_ENV`) se configuran desde el Blueprint.

### Opcion B: Docker manual

```bash
docker build -t api-modulo8 .
docker run -p 3000:3000 -e DATABASE_URL="postgresql://user:pass@host:5432/db" -e NODE_ENV=production api-modulo8
```

La API queda accesible mediante una URL publica publica, por ejemplo `https://api-modulo8.onrender.com`.

> Nota: los secretos (password, cadena de conexion) se inyectan como variables de entorno en el panel de Render; nunca van en el codigo fuente.

## CI/CD

El pipeline de GitHub Actions esta definido en `.github/workflows/deploy.yml`:

1. **Validacion (job `test`)**: instala dependencias con `npm ci`, ejecuta `npm test` y verifica la existencia de `.env.example`.
2. **Despliegue (job `deploy`)**: solo en `main`, tras pasar los tests, dispara un deploy en Render mediante la API (requiere los secrets `RENDER_API_KEY` y `RENDER_SERVICE_ID`).

El pipeline se ejecuta automaticamente en cada push a `main` y en cada pull request hacia `main`.

Para configurar los secrets en GitHub:

```
Settings > Secrets and variables > Actions
  RENDER_API_KEY    -> clave de la API de Render (dashboard.render.com/api)
  RENDER_SERVICE_ID -> id del servicio web en Render
```

## Plan de backups

Consulta el documento completo en [docs/BACKUP_PLAN.md](docs/BACKUP_PLAN.md). Resumen:

- **Que**: dump de la base de datos, codigo fuente, configuracion y documentacion.
- **Frecuencia**: `pg_dump` diario a las 03:00 UTC; el codigo queda respaldado con cada commit.
- **Almacenamiento**: S3 / Google Cloud Storage (30 dias de retencion) y GitHub (indefinido).
- **Recuperacion**: restauracion con `pg_restore` y validacion mediante `GET /health`.

## Estructura del proyecto

```
├── .github/workflows/deploy.yml   # Pipeline CI/CD
├── docs/BACKUP_PLAN.md            # Plan de backups
├── src/
│   ├── index.js                   # Servidor Express + /health
│   ├── db.js                      # Pool de conexiones a PostgreSQL
│   ├── monitoring.js              # Check de salud de la BD
│   ├── models/productos.js        # Operaciones de la tabla productos
│   └── routes/productos.js        # Rutas CRUD de productos
├── tests/api.test.js              # Tests de la API
├── .env.example                   # Plantilla de variables de entorno
├── Dockerfile                     # Imagen para despliegue
├── render.yaml                    # Blueprint de Render (servicio + BD)
└── package.json
```

## Licencia

MIT
