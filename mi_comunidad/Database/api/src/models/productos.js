const pool = require('../db');

const SCHEMA = `
  CREATE EXTENSION IF NOT EXISTS pgcrypto;
  CREATE SCHEMA IF NOT EXISTS app;

  CREATE TABLE IF NOT EXISTS app.roles (
    role_id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name VARCHAR(30) NOT NULL UNIQUE,
    description VARCHAR(150),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
  );

  INSERT INTO app.roles (role_name, description)
  VALUES ('user', 'Usuario normal'), ('admin', 'Administrador')
  ON CONFLICT (role_name) DO NOTHING;

  CREATE TABLE IF NOT EXISTS app.users (
    user_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email VARCHAR(254) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
  );

  CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_unique
    ON app.users (lower(email));

  CREATE TABLE IF NOT EXISTS app.user_roles (
    user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE CASCADE,
    role_id SMALLINT NOT NULL REFERENCES app.roles (role_id) ON DELETE RESTRICT,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
  );

  CREATE TABLE IF NOT EXISTS app.login_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE CASCADE,
    refresh_token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS app.subscription_plans (
    plan_id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    plan_name VARCHAR(80) NOT NULL UNIQUE,
    price NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    billing_interval VARCHAR(20) NOT NULL CHECK (billing_interval IN ('month', 'year')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
  );

  INSERT INTO app.subscription_plans (plan_name, price, currency, billing_interval)
  VALUES ('Membresía negocio mensual', 5.00, 'USD', 'month')
  ON CONFLICT (plan_name) DO NOTHING;

  CREATE TABLE IF NOT EXISTS app.subscriptions (
    subscription_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE RESTRICT,
    plan_id SMALLINT NOT NULL REFERENCES app.subscription_plans (plan_id) ON DELETE RESTRICT,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    starts_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT subscriptions_status_valid CHECK (status IN ('pending', 'active', 'cancelled', 'expired'))
  );

  CREATE TABLE IF NOT EXISTS app.payments (
    payment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subscription_id BIGINT NOT NULL REFERENCES app.subscriptions (subscription_id) ON DELETE RESTRICT,
    user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE RESTRICT,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    status VARCHAR(20) NOT NULL DEFAULT 'succeeded',
    provider VARCHAR(40) NOT NULL DEFAULT 'demo',
    provider_payment_id VARCHAR(150),
    paid_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT payments_status_valid CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded'))
  );

  CREATE TABLE IF NOT EXISTS app.businesses (
    business_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id BIGINT REFERENCES app.users (user_id) ON DELETE SET NULL,
    name VARCHAR(160) NOT NULL,
    category VARCHAR(80) NOT NULL,
    description TEXT NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(40) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL DEFAULT 13.7215,
    longitude DOUBLE PRECISION NOT NULL DEFAULT -89.3620,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS app.business_favorites (
    user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE CASCADE,
    business_id BIGINT NOT NULL REFERENCES app.businesses (business_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, business_id)
  );

  CREATE TABLE IF NOT EXISTS app.business_reviews (
    review_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE CASCADE,
    business_id BIGINT NOT NULL REFERENCES app.businesses (business_id) ON DELETE CASCADE,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, business_id)
  );

  INSERT INTO app.businesses (name, category, description, address, phone, latitude, longitude)
  SELECT seed.name, seed.category, seed.description, seed.address, seed.phone, seed.latitude, seed.longitude
  FROM (VALUES
    ('Café El Chaparrastique', 'Restaurantes', 'Café especial y desayunos artesanales.', 'Colonia Escalón, San Salvador', '+503 7000-1001', 13.6980, -89.2230),
    ('Farmacia La Buena Salud', 'Farmacias', 'Medicamentos y atención las 24 horas.', 'Centro Histórico, San Salvador', '+503 7000-1002', 13.6890, -89.2110),
    ('Hotel La Comunidad', 'Hoteles', 'Hospedaje cómodo para visitantes de la ciudad.', 'Boulevard Los Héroes, San Salvador', '+503 7000-1003', 13.7040, -89.2160),
    ('Reparaciones Express', 'Servicios', 'Reparación de celulares y electrodomésticos.', 'Colonia Miramonte, San Salvador', '+503 7000-1004', 13.7060, -89.2250),
    ('Restaurante El Buen Sabor', 'Restaurantes', 'Comida casera y platos típicos salvadoreños.', 'San Benito, San Salvador', '+503 7000-1005', 13.6930, -89.2360)
  ) AS seed(name, category, description, address, phone, latitude, longitude)
  WHERE NOT EXISTS (
    SELECT 1 FROM app.businesses existing
    WHERE existing.name = seed.name AND existing.address = seed.address
  );

  CREATE TABLE IF NOT EXISTS productos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    precio NUMERIC(10, 2) NOT NULL CHECK (precio >= 0),
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
`;

async function list() {
  const { rows } = await pool.query('SELECT * FROM productos ORDER BY id ASC');
  return rows;
}

async function create(producto) {
  const { rows } = await pool.query(
    'INSERT INTO productos (nombre, precio, stock) VALUES ($1, $2, $3) RETURNING *',
    [producto.nombre, producto.precio, producto.stock || 0]
  );
  return rows[0];
}

async function findById(id) {
  const { rows } = await pool.query('SELECT * FROM productos WHERE id = $1', [id]);
  return rows[0] || null;
}

module.exports = { SCHEMA, list, create, findById };
