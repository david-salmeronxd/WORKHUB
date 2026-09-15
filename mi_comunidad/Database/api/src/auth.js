const crypto = require('node:crypto');
const pool = require('./db');

function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, stored) {
  const [salt, expected] = String(stored).split(':');
  if (!salt || !expected) return false;
  const actual = crypto.scryptSync(password, salt, 64).toString('hex');
  return crypto.timingSafeEqual(Buffer.from(actual, 'hex'), Buffer.from(expected, 'hex'));
}

function createToken() {
  return crypto.randomBytes(32).toString('hex');
}

function tokenHash(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

async function authenticate(req, _res, next) {
  try {
    const authorization = req.get('authorization') || '';
    const token = authorization.startsWith('Bearer ') ? authorization.slice(7) : '';
    if (!token) return next();

    const { rows } = await pool.query(
      `SELECT u.user_id, u.email, u.first_name, u.last_name,
              COALESCE(bool_or(r.role_name = 'admin'), false) AS is_admin
       FROM app.login_sessions s
       JOIN app.users u ON u.user_id = s.user_id
       LEFT JOIN app.user_roles ur ON ur.user_id = u.user_id
       LEFT JOIN app.roles r ON r.role_id = ur.role_id
       WHERE s.refresh_token_hash = $1 AND s.expires_at > CURRENT_TIMESTAMP AND u.is_active
       GROUP BY u.user_id`,
      [tokenHash(token)]
    );
    if (rows[0]) req.user = rows[0];
    next();
  } catch (error) {
    next(error);
  }
}

function requireAuth(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'Autenticacion requerida' });
  next();
}

module.exports = { hashPassword, verifyPassword, createToken, tokenHash, authenticate, requireAuth };