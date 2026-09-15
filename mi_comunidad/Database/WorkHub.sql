CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE app.roles (
	role_id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	role_name VARCHAR(30) NOT NULL UNIQUE,
	description VARCHAR(150),
	created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT roles_name_not_blank CHECK (length(trim(role_name)) > 0)
);

INSERT INTO app.roles (role_name, description)
VALUES
	('user', 'Usuario normal '),
	('admin', 'Administrador ')
ON CONFLICT (role_name) DO NOTHING;

CREATE TABLE app.users (
	user_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	email VARCHAR(254) NOT NULL,
	password_hash VARCHAR(255) NOT NULL,
	first_name VARCHAR(80) NOT NULL,
	last_name VARCHAR(80),
	is_active BOOLEAN NOT NULL DEFAULT TRUE,
	email_verified_at TIMESTAMPTZ,
	last_login_at TIMESTAMPTZ,
	created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT users_email_not_blank CHECK (length(trim(email)) > 0),
	CONSTRAINT users_password_hash_not_blank CHECK (length(trim(password_hash)) > 0),
	CONSTRAINT users_first_name_not_blank CHECK (length(trim(first_name)) > 0)
);

CREATE UNIQUE INDEX users_email_lower_unique
	ON app.users (lower(email));

CREATE TABLE app.subscription_plans (
	plan_id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	plan_name VARCHAR(80) NOT NULL UNIQUE,
	price NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
	currency CHAR(3) NOT NULL DEFAULT 'USD',
	billing_interval VARCHAR(20) NOT NULL CHECK (billing_interval IN ('month', 'year')),
	is_active BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO app.subscription_plans (plan_name, price, currency, billing_interval)
VALUES ('Membresía negocio mensual', 5.00, 'USD', 'month');

CREATE TABLE app.subscriptions (
	subscription_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE RESTRICT,
	plan_id SMALLINT NOT NULL REFERENCES app.subscription_plans (plan_id) ON DELETE RESTRICT,
	status VARCHAR(20) NOT NULL DEFAULT 'active',
	starts_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	ends_at TIMESTAMPTZ,
	created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE app.payments (
	payment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	subscription_id BIGINT NOT NULL REFERENCES app.subscriptions (subscription_id) ON DELETE RESTRICT,
	user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE RESTRICT,
	amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
	currency CHAR(3) NOT NULL DEFAULT 'USD',
	status VARCHAR(20) NOT NULL DEFAULT 'succeeded',
	provider VARCHAR(40) NOT NULL DEFAULT 'demo',
	provider_payment_id VARCHAR(150),
	paid_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
	created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE app.businesses (
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

INSERT INTO app.businesses (name, category, description, address, phone, latitude, longitude)
VALUES
	('Café El Chaparrastique', 'Restaurantes', 'Café especial y desayunos artesanales.', 'Colonia Escalón, San Salvador', '+503 7000-1001', 13.6980, -89.2230),
	('Farmacia La Buena Salud', 'Farmacias', 'Medicamentos y atención las 24 horas.', 'Centro Histórico, San Salvador', '+503 7000-1002', 13.6890, -89.2110),
	('Hotel La Comunidad', 'Hoteles', 'Hospedaje cómodo para visitantes de la ciudad.', 'Boulevard Los Héroes, San Salvador', '+503 7000-1003', 13.7040, -89.2160),
	('Reparaciones Express', 'Servicios', 'Reparación de celulares y electrodomésticos.', 'Colonia Miramonte, San Salvador', '+503 7000-1004', 13.7060, -89.2250),
	('Restaurante El Buen Sabor', 'Restaurantes', 'Comida casera y platos típicos salvadoreños.', 'San Benito, San Salvador', '+503 7000-1005', 13.6930, -89.2360);

CREATE TABLE app.user_roles (
	user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE CASCADE,
	role_id SMALLINT NOT NULL REFERENCES app.roles (role_id) ON DELETE RESTRICT,
	assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY (user_id, role_id)
);

CREATE TABLE app.subscription_plans (
	plan_id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	plan_name VARCHAR(80) NOT NULL UNIQUE,
	description VARCHAR(255),
	price NUMERIC(12, 2) NOT NULL,
	currency CHAR(3) NOT NULL DEFAULT 'USD',
	billing_interval VARCHAR(20) NOT NULL,
	is_active BOOLEAN NOT NULL DEFAULT TRUE,
	created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT plans_price_nonnegative CHECK (price >= 0),
	CONSTRAINT plans_currency_uppercase CHECK (currency = upper(currency)),
	CONSTRAINT plans_interval_valid CHECK (billing_interval IN ('month', 'year'))
);

CREATE TABLE app.subscriptions (
	subscription_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE RESTRICT,
	plan_id SMALLINT NOT NULL REFERENCES app.subscription_plans (plan_id) ON DELETE RESTRICT,
	status VARCHAR(20) NOT NULL DEFAULT 'pending',
	starts_at TIMESTAMPTZ NOT NULL,
	ends_at TIMESTAMPTZ,
	auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
	provider VARCHAR(40),
	provider_subscription_id VARCHAR(150),
	created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT subscriptions_status_valid CHECK (
		status IN ('pending', 'active', 'past_due', 'cancelled', 'expired')
	),
	CONSTRAINT subscriptions_dates_valid CHECK (ends_at IS NULL OR ends_at > starts_at),
	CONSTRAINT subscriptions_provider_id_unique UNIQUE (provider, provider_subscription_id)
);

CREATE INDEX subscriptions_user_idx ON app.subscriptions (user_id);
CREATE INDEX subscriptions_status_dates_idx ON app.subscriptions (status, starts_at, ends_at);

CREATE TABLE app.payments (
	payment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	subscription_id BIGINT NOT NULL REFERENCES app.subscriptions (subscription_id) ON DELETE RESTRICT,
	user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE RESTRICT,
	amount NUMERIC(12, 2) NOT NULL,
	currency CHAR(3) NOT NULL DEFAULT 'USD',
	status VARCHAR(20) NOT NULL DEFAULT 'pending',
	provider VARCHAR(40),
	provider_payment_id VARCHAR(150),
	paid_at TIMESTAMPTZ,
	created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT payments_amount_positive CHECK (amount > 0),
	CONSTRAINT payments_currency_uppercase CHECK (currency = upper(currency)),
	CONSTRAINT payments_status_valid CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
	CONSTRAINT payments_provider_id_unique UNIQUE (provider, provider_payment_id)
);

CREATE INDEX payments_user_idx ON app.payments (user_id);
CREATE INDEX payments_subscription_idx ON app.payments (subscription_id);

CREATE TABLE app.login_sessions (
	session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	user_id BIGINT NOT NULL REFERENCES app.users (user_id) ON DELETE CASCADE,
	refresh_token_hash VARCHAR(255) NOT NULL UNIQUE,
	expires_at TIMESTAMPTZ NOT NULL,
	revoked_at TIMESTAMPTZ,
	created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT sessions_token_not_blank CHECK (length(trim(refresh_token_hash)) > 0)
);

CREATE INDEX login_sessions_user_idx ON app.login_sessions (user_id);

CREATE OR REPLACE FUNCTION app.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
	NEW.updated_at = CURRENT_TIMESTAMP;
	RETURN NEW;
END;
$$;

CREATE TRIGGER users_set_updated_at
BEFORE UPDATE ON app.users
FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();

CREATE TRIGGER subscriptions_set_updated_at
BEFORE UPDATE ON app.subscriptions
FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();


CREATE UNIQUE INDEX one_current_subscription_per_user
	ON app.subscriptions (user_id)
	WHERE status IN ('pending', 'active', 'past_due');


CREATE VIEW app.user_access AS
SELECT
	u.user_id,
	u.email,
	EXISTS (
		SELECT 1
		FROM app.subscriptions s
		JOIN app.payments p ON p.subscription_id = s.subscription_id
		WHERE s.user_id = u.user_id
		  AND s.status = 'active'
		  AND p.status = 'succeeded'
		  AND (s.ends_at IS NULL OR s.ends_at > CURRENT_TIMESTAMP)
	) AS is_paid,
	EXISTS (
		SELECT 1
		FROM app.user_roles ur
		JOIN app.roles r ON r.role_id = ur.role_id
		WHERE ur.user_id = u.user_id
		  AND r.role_name = 'admin'
	) AS is_admin
FROM app.users u;