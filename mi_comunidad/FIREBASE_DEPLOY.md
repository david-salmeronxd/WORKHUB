# Despliegue en Firebase

La aplicación usa Firebase Hosting para los archivos web y la API Node/Express para acceder a PostgreSQL WorkHub. La base de datos no se publica dentro de Firebase Hosting.

## 1. Crear el proyecto Firebase

Instala Node.js con npm y luego Firebase CLI:

```bash
npm install -g firebase-tools
firebase login
firebase projects:list
```

Desde la carpeta `mi_comunidad`, enlaza el proyecto reemplazando `TU_PROJECT_ID`:

```bash
firebase use --add TU_PROJECT_ID
```

Esto crea el archivo `.firebaserc`, que no debe contener contraseñas.

## 2. Publicar la API

Despliega `Database/api` en Render usando el `render.yaml` existente. Configura estas variables en el servicio:

```env
NODE_ENV=production
DATABASE_URL=postgresql://.../workhub
CORS_ORIGIN=https://TU_PROJECT_ID.web.app
```

La API debe responder antes de continuar:

```bash
curl https://TU_API.onrender.com/health
```

La respuesta esperada incluye `"status":"ok"` y `"db":"up"`.

## 3. Compilar y publicar Flutter

Desde `mi_comunidad`:

```bash
flutter pub get
flutter build web --release --dart-define=API_URL=https://TU_API.onrender.com
firebase deploy --only hosting
```

El archivo `firebase.json` ya apunta a `build/web` y configura las rutas de Flutter Web.

## Importante

No pongas `DATABASE_URL`, contraseñas ni tokens en Flutter, Firebase Hosting o el repositorio. Solo la API debe conocer la conexión de PostgreSQL.