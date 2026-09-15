# Plan de Backups

Proyecto: API Módulo 8 (Express + PostgreSQL)
Fecha de elaboración: 2026-08-05

## 1. Que informacion se respalda

| Componente | Detalle | Criticidad |
|---|---|---|
| Base de datos PostgreSQL | Tabla `productos` (y cualquier otra tabla del esquema `public`): datos de la aplicacion | Alta |
| Codigo fuente | Repositorio GitHub (rama `main` y demas ramas con commits) | Alta |
| Configuracion | Archivo `.env.example` (plantilla sin secretos). Los secretos reales viven en el panel de Render, no se respaldan en texto plano | Media |
| Documentacion | `README.md`, `docs/BACKUP_PLAN.md`, `render.yaml`, pipeline `.github/workflows/deploy.yml` | Media |

## 2. Frecuencia de los respaldos

| Tipo | Frecuencia | Herramienta |
|---|---|---|
| Backup completo de la base de datos | Diaria a las 03:00 (UTC) | `pg_dump` (script automatizado) |
| Backup logico incremental del codigo | Cada commit | Git + GitHub (repositorio remoto) |
| Snapshot del repositorio (tarball/zip) | Semanal | GitHub export / respaldo manual |
| Verificacion de restauracion | Mensual | Restaurar backup en entorno de pruebas |

## 3. Lugar de almacenamiento

| Backup | Ubicacion | Retencion |
|---|---|---|
| Dump SQL de PostgreSQL | Bucket S3 / Google Cloud Storage (cifrado en reposo, versionado habilitado) | 30 dias (7 dumps diarios, 4 semanales, 1 mensual) |
| Codigo fuente | GitHub (repositorio publico) | Indefinida (historial de commits) |
| Snapshot semanal | Almacenamiento frio (p. ej. S3 Glacier) | 6 meses |

### Script de backup de referencia (cron + pg_dump)

```bash
#!/usr/bin/env bash
# backup.sh — copia de seguridad de la BD en PostgreSQL
set -euo pipefail

DB_URL="${DATABASE_URL:?Falta DATABASE_URL}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
FILE="api_modulo8_${STAMP}.sql"

pg_dump "$DB_URL" -Fc -f "/tmp/${FILE}"

# Subir al almacenamiento remoto (ejemplo con aws cli)
# aws s3 cp "/tmp/${FILE}" "s3://bucket-backups/api-modulo8/${FILE}"

# Retencion: eliminar dumps locales con mas de 7 dias
find /tmp -name 'api_modulo8_*.sql' -mtime +7 -delete
echo "Backup completado: ${FILE}"
```

Programacion con cron (diario a las 03:00 UTC):

```cron
0 3 * * * /opt/scripts/backup.sh >> /var/log/backup_api.log 2>&1
```

## 4. Procedimiento de recuperacion ante fallos

### 4.1 Falla de la base de datos (perdida o corrupcion)

1. Detener la aplicacion o activar el modo mantenimiento (para evitar escrituras parciales).
2. Crear una base de datos limpia en PostgreSQL:
   ```sql
   CREATE DATABASE api_modulo8;
   ```
3. Restaurar el dump mas reciente:
   ```bash
   pg_restore -d "$DATABASE_URL" /tmp/api_modulo8_YYYYMMDD_HHMMSS.sql
   ```
4. Ejecutar `npm start` y validar el endpoint `GET /health` (debe responder `{"status":"ok","db":"up"}`).
5. Verificar la integridad con una consulta de prueba: `SELECT count(*) FROM productos;` y comparar con el ultimo conteo registrado en los backups.

### 4.2 Falla de la aplicacion (crash / 500)

1. Revisar logs del contenedor (Render > service > Logs).
2. Consultar `GET /health`; si `db` es `down`, seguir el punto 4.1.
3. Si el fallo es de codigo: revisar la rama `main`, revertir el commit problematico o corregir y hacer push (el pipeline CI/CD redespiega automaticamente).
4. Render re-sube automaticamente el servicio al fallar el health check; si no, usar el boton "Manual Deploy".

### 4.3 Falla completa de la plataforma cloud

1. Restaurar la base de datos desde el backup S3 (punto 4.1).
2. Desplegar el codigo desde GitHub usando `render.yaml` (Blueprint) o `docker build` + `docker run`.
3. Reconfigurar variables de entorno en el nuevo servicio (`.env.example` como referencia).

## 5. Responsables y pruebas

- Responsable del respaldo: administrador del proyecto.
- Prueba de restauracion: se ejecuta mensualmente en un entorno de pruebas; se documenta el resultado en el repositorio.
- Alertas: el endpoint `/health` se monitorea con un cron externo que notifica si el status es distinto de `ok` durante mas de 5 minutos.
