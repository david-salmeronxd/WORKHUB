const { Router } = require('express');
const pool = require('../db');
const { hashPassword, verifyPassword, createToken, tokenHash } = require('../auth');

const router = Router();

function publicUser(row) {
  return { id: String(row.user_id), email: row.email, firstName: row.first_name, lastName: row.last_name, isAdmin: row.is_admin === true };
}

router.post('/register', async (req, res, next) => {
  try {
    const { email, password, firstName, lastName } = req.body;
    if (!email || !password || !firstName || password.length < 6) {
      return res.status(400).json({ error: 'email, firstName y password de al menos 6 caracteres son requeridos' });
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const user = await client.query(
        `INSERT INTO app.users (email, password_hash, first_name, last_name)
         VALUES ($1, $2, $3, $4) RETURNING user_id, email, first_name, last_name`,
        [email.trim().toLowerCase(), hashPassword(password), firstName.trim(), lastName?.trim() || null]
      );
      await client.query(
        `INSERT INTO app.user_roles (user_id, role_id)
         SELECT $1, role_id FROM app.roles WHERE role_name = 'user'`,
        [user.rows[0].user_id]
      );
      const token = createToken();
      await client.query(
        `INSERT INTO app.login_sessions (user_id, refresh_token_hash, expires_at)
         VALUES ($1, $2, CURRENT_TIMESTAMP + INTERVAL '30 days')`,
        [user.rows[0].user_id, tokenHash(token)]
      );
      await client.query('COMMIT');
      res.status(201).json({ token, data: publicUser({ ...user.rows[0], is_admin: false }) });
    } catch (error) {
      await client.query('ROLLBACK');
      if (error.code === '23505') return res.status(409).json({ error: 'El correo ya esta registrado' });
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
});

router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const { rows } = await pool.query(
      `SELECT u.*, COALESCE(bool_or(r.role_name = 'admin'), false) AS is_admin
       FROM app.users u LEFT JOIN app.user_roles ur ON ur.user_id = u.user_id
       LEFT JOIN app.roles r ON r.role_id = ur.role_id
       WHERE lower(u.email) = lower($1) AND u.is_active GROUP BY u.user_id`,
      [email]
    );
    if (!rows[0] || !verifyPassword(password || '', rows[0].password_hash)) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
    }
    const token = createToken();
    await pool.query(
      `INSERT INTO app.login_sessions (user_id, refresh_token_hash, expires_at)
       VALUES ($1, $2, CURRENT_TIMESTAMP + INTERVAL '30 days')`,
      [rows[0].user_id, tokenHash(token)]
    );
    res.json({ token, data: publicUser(rows[0]) });
  } catch (error) {
    next(error);
  }
});

module.exports = router;