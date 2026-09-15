const express = require('express');
require('dotenv').config();

const pool = require('./db');
const { connectionString, maskConnectionString } = pool;
const { health, SCHEMA } = require('./monitoring');
const productosRouter = require('./routes/productos');
const authRouter = require('./routes/auth');
const businessesRouter = require('./routes/businesses');
const { authenticate } = require('./auth');

const app = express();
app.use(express.json());
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', process.env.CORS_ORIGIN || '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,DELETE,OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});
app.use(authenticate);

app.get('/health', async (_req, res) => {
  const h = await health();
  res.status(h.status === 'ok' ? 200 : 503).json(h);
});

app.get('/', (_req, res) => {
  res.json({
    name: 'API Módulo 8',
    message: 'API REST con Express y PostgreSQL',
    endpoints: ['GET /health', 'POST /auth/register', 'POST /auth/login', 'GET /businesses', 'POST /businesses', 'DELETE /businesses/:id', 'GET /productos', 'GET /productos/:id', 'POST /productos'],
  });
});

app.use('/productos', productosRouter);
app.use('/auth', authRouter);
app.use('/businesses', businessesRouter);

app.use((req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor' });
});

const PORT = process.env.PORT || 3000;
const MAX_DB_ATTEMPTS = 10;
const DB_RETRY_DELAY_MS = 5000;

async function waitForDatabase() {
  for (let attempt = 1; attempt <= MAX_DB_ATTEMPTS; attempt += 1) {
    try {
      await pool.query('SELECT 1');
      return true;
    } catch (err) {
      console.error(
        `[${attempt}/${MAX_DB_ATTEMPTS}] PostgreSQL no disponible:`,
        err.message || JSON.stringify(err)
      );
      if (attempt === MAX_DB_ATTEMPTS) return false;
      await new Promise((resolve) => setTimeout(resolve, DB_RETRY_DELAY_MS));
    }
  }
  return false;
}

async function start() {
  const dbReady = await waitForDatabase();
  if (!dbReady) {
    console.error('No se pudo conectar a PostgreSQL tras varios intentos.');
    console.error('DATABASE_URL configurada:', maskConnectionString(connectionString));
    console.error('NODE_ENV:', process.env.NODE_ENV);
    process.exit(1);
  }

  try {
    await pool.query(SCHEMA);
    app.listen(PORT, () => {
      console.log(`API escuchando en el puerto ${PORT}`);
    });
  } catch (err) {
    console.error('No se pudo inicializar el esquema:', err.message || err);
    process.exit(1);
  }
}

if (require.main === module) {
  start();
}

module.exports = { app, start };
