const { Router } = require('express');
const pool = require('../db');
const { requireAuth } = require('../auth');

const router = Router();

const selectBusinesses = `
  SELECT business_id AS id, name, category, description, address, phone,
         latitude, longitude, created_at,
         COALESCE((SELECT ROUND(AVG(rating)::numeric, 1) FROM app.business_reviews r
                   WHERE r.business_id = b.business_id), 0) AS rating,
         (SELECT COUNT(*) FROM app.business_reviews r WHERE r.business_id = b.business_id) AS ratings_count,
         COALESCE((SELECT json_agg(json_build_object(
           'id', r.review_id::text, 'userName', u.first_name,
           'rating', r.rating, 'comment', r.comment, 'date', r.created_at
         ) ORDER BY r.created_at DESC)
         FROM app.business_reviews r JOIN app.users u ON u.user_id = r.user_id
         WHERE r.business_id = b.business_id), '[]'::json) AS reviews
  FROM app.businesses b WHERE b.is_active`;

router.get('/', async (_req, res, next) => {
  try {
    const { rows } = await pool.query(`${selectBusinesses} ORDER BY created_at DESC`);
    res.json({ count: rows.length, data: rows });
  } catch (error) {
    next(error);
  }
});

router.get('/favorites', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT business_id AS id FROM app.business_favorites WHERE user_id = $1',
      [req.user.user_id]
    );
    res.json({ data: rows.map((row) => String(row.id)) });
  } catch (error) {
    next(error);
  }
});

router.post('/:id/favorite', requireAuth, async (req, res, next) => {
  try {
    await pool.query(
      `INSERT INTO app.business_favorites (user_id, business_id)
       SELECT $1, business_id FROM app.businesses WHERE business_id = $2 AND is_active
       ON CONFLICT DO NOTHING`,
      [req.user.user_id, req.params.id]
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

router.delete('/:id/favorite', requireAuth, async (req, res, next) => {
  try {
    await pool.query('DELETE FROM app.business_favorites WHERE user_id = $1 AND business_id = $2', [req.user.user_id, req.params.id]);
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

router.post('/:id/reviews', requireAuth, async (req, res, next) => {
  try {
    const rating = Number(req.body.rating);
    const comment = String(req.body.comment || '').trim();
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'La calificacion debe ser un entero entre 1 y 5' });
    }
    const { rows } = await pool.query(
      `INSERT INTO app.business_reviews (user_id, business_id, rating, comment)
       SELECT $1, business_id, $2, $3 FROM app.businesses WHERE business_id = $4 AND is_active
       ON CONFLICT (user_id, business_id) DO UPDATE SET rating = EXCLUDED.rating, comment = EXCLUDED.comment
       RETURNING review_id AS id, rating, comment, created_at AS date`,
      [req.user.user_id, rating, comment, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Negocio no encontrado' });
    res.status(201).json({ data: rows[0] });
  } catch (error) {
    next(error);
  }
});

router.post('/', requireAuth, async (req, res, next) => {
  let client;
  try {
    const { name, category, description, address, phone, latitude, longitude } = req.body;
    if (!name || !category || !description || !address || !phone) {
      return res.status(400).json({ error: 'name, category, description, address y phone son requeridos' });
    }
    client = await pool.connect();
    await client.query('BEGIN');
    const { rows } = await client.query(
      `INSERT INTO app.businesses (owner_id, name, category, description, address, phone, latitude, longitude)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING business_id AS id, name, category, description, address, phone, latitude, longitude, created_at`,
      [req.user.user_id, name.trim(), category.trim(), description.trim(), address.trim(), phone.trim(), Number(latitude) || 13.7215, Number(longitude) || -89.3620]
    );
    const subscription = await client.query(
      `INSERT INTO app.subscriptions (user_id, plan_id, status, ends_at)
       SELECT $1, plan_id, 'active', CURRENT_TIMESTAMP + INTERVAL '1 month'
       FROM app.subscription_plans WHERE plan_name = 'Membresía negocio mensual'
       RETURNING subscription_id`,
      [req.user.user_id]
    );
    await client.query(
      `INSERT INTO app.payments (subscription_id, user_id, amount, provider, provider_payment_id)
       SELECT $1, $2, price, 'demo', $3 FROM app.subscription_plans
       WHERE plan_name = 'Membresía negocio mensual'`,
      [subscription.rows[0].subscription_id, req.user.user_id, `demo-${rows[0].id}-${Date.now()}`]
    );
    await client.query('COMMIT');
    res.status(201).json({ data: rows[0], payment: { status: 'succeeded', amount: 5, currency: 'USD' } });
  } catch (error) {
    if (client) await client.query('ROLLBACK');
    next(error);
  } finally {
    client?.release();
  }
});

router.delete('/:id', requireAuth, async (req, res, next) => {
  try {
    const result = await pool.query(
      'UPDATE app.businesses SET is_active = false WHERE business_id = $1 AND (owner_id = $2 OR $3) ',
      [req.params.id, req.user.user_id, req.user.is_admin]
    );
    if (!result.rowCount) return res.status(404).json({ error: 'Negocio no encontrado' });
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

module.exports = router;