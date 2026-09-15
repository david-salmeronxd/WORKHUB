const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL;

const pool = new Pool({
  connectionString,
  ssl:
    process.env.NODE_ENV === 'production' || /[?&]ssl=/i.test(connectionString || '')
      ? { rejectUnauthorized: false }
      : false,
});

pool.on('error', (err) => {
  console.error('Error inesperado en el pool de PostgreSQL:', err.message || err);
});

function maskConnectionString(url) {
  if (!url) return '(DATABASE_URL no definida)';
  return url.replace(/(:[^:@/]+)@/, ':***@');
}

module.exports = pool;
module.exports.connectionString = connectionString;
module.exports.maskConnectionString = maskConnectionString;
