const pool = require('./db');
const { SCHEMA } = require('./models/productos');

async function health() {
  const started = Date.now();
  try {
    await pool.query('SELECT 1');
    return { status: 'ok', db: 'up', uptime: process.uptime(), timestamp: new Date().toISOString(), responseTimeMs: Date.now() - started };
  } catch (err) {
    return { status: 'degraded', db: 'down', uptime: process.uptime(), timestamp: new Date().toISOString(), responseTimeMs: Date.now() - started, error: err.message };
  }
}

module.exports = { health, SCHEMA };
