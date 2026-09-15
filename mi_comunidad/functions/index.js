const crypto = require('node:crypto');
const express = require('express');
const cors = require('cors');
const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();
const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '1mb' }));

const users = db.collection('users');
const sessions = db.collection('sessions');
const businesses = db.collection('businesses');
const plans = db.collection('subscription_plans');
const subscriptions = db.collection('subscriptions');
const payments = db.collection('payments');

function passwordHash(password, salt = crypto.randomBytes(16).toString('hex')) {
  return `${salt}:${crypto.scryptSync(password, salt, 64).toString('hex')}`;
}

function verifyPassword(password, stored) {
  const [salt, expected] = String(stored).split(':');
  if (!salt || !expected) return false;
  const actual = crypto.scryptSync(password, salt, 64).toString('hex');
  return crypto.timingSafeEqual(Buffer.from(actual, 'hex'), Buffer.from(expected, 'hex'));
}

function publicUser(id, data) {
  return { id, email: data.email, firstName: data.firstName, lastName: data.lastName || null, isAdmin: data.isAdmin === true };
}

function jsonDate(value) {
  return value instanceof Timestamp ? value.toDate().toISOString() : value || null;
}

async function authenticate(req, _res, next) {
  try {
    const header = req.get('authorization') || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (token) {
      const session = await sessions.doc(token).get();
      if (session.exists && session.data().expiresAt.toMillis() > Date.now()) {
        const user = await users.doc(session.data().userId).get();
        if (user.exists && user.data().isActive !== false) req.user = { id: user.id, ...user.data() };
      }
    }
    next();
  } catch (error) {
    next(error);
  }
}

function requireAuth(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'Autenticacion requerida' });
  next();
}

function createSession(userId) {
  const token = crypto.randomBytes(32).toString('hex');
  return sessions.doc(token).set({ userId, expiresAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000), createdAt: FieldValue.serverTimestamp() }).then(() => token);
}

async function businessJson(snapshot, userId) {
  const data = snapshot.data();
  const reviewsSnapshot = await snapshot.ref.collection('reviews').orderBy('createdAt', 'desc').get();
  const reviews = reviewsSnapshot.docs.map((review) => ({ id: review.id, ...review.data(), date: jsonDate(review.data().createdAt) }));
  const rating = reviews.length ? reviews.reduce((sum, review) => sum + review.rating, 0) / reviews.length : 0;
  const favorite = userId ? (await snapshot.ref.collection('favorites').doc(userId).get()).exists : false;
  return { id: snapshot.id, ...data, rating: Number(rating.toFixed(1)), ratingsCount: reviews.length, reviews, isFavorite: favorite, createdAt: jsonDate(data.createdAt) };
}

app.use(authenticate);
app.get('/health', (_req, res) => res.json({ status: 'ok', db: 'up', timestamp: new Date().toISOString() }));

app.post('/auth/register', async (req, res, next) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    const firstName = String(req.body.firstName || '').trim();
    if (!email || !firstName || password.length < 6) return res.status(400).json({ error: 'email, firstName y password de al menos 6 caracteres son requeridos' });
    const existing = await users.where('email', '==', email).limit(1).get();
    if (!existing.empty) return res.status(409).json({ error: 'El correo ya esta registrado' });
    const ref = users.doc();
    const data = { email, passwordHash: passwordHash(password), firstName, lastName: req.body.lastName || null, isActive: true, isAdmin: false, createdAt: FieldValue.serverTimestamp() };
    await ref.set(data);
    const token = await createSession(ref.id);
    res.status(201).json({ token, data: publicUser(ref.id, data) });
  } catch (error) { next(error); }
});

app.post('/auth/login', async (req, res, next) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const found = await users.where('email', '==', email).where('isActive', '==', true).limit(1).get();
    if (found.empty || !verifyPassword(String(req.body.password || ''), found.docs[0].data().passwordHash)) return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
    const user = found.docs[0];
    const token = await createSession(user.id);
    res.json({ token, data: publicUser(user.id, user.data()) });
  } catch (error) { next(error); }
});

app.get('/businesses', async (req, res, next) => {
  try {
    const snapshot = await businesses.where('isActive', '==', true).get();
    res.json({ count: snapshot.size, data: await Promise.all(snapshot.docs.map((item) => businessJson(item, req.user?.id))) });
  } catch (error) { next(error); }
});

app.get('/businesses/favorites', requireAuth, async (req, res, next) => {
  try {
    const snapshot = await businesses.where('isActive', '==', true).get();
    const ids = [];
    for (const business of snapshot.docs) if ((await business.ref.collection('favorites').doc(req.user.id).get()).exists) ids.push(business.id);
    res.json({ data: ids });
  } catch (error) { next(error); }
});

app.post('/businesses', requireAuth, async (req, res, next) => {
  try {
    const { name, category, description, address, phone } = req.body;
    if (!name || !category || !description || !address || !phone) return res.status(400).json({ error: 'name, category, description, address y phone son requeridos' });
    const ref = businesses.doc();
    const business = { ownerId: req.user.id, name: String(name).trim(), category: String(category).trim(), description: String(description).trim(), address: String(address).trim(), phone: String(phone).trim(), latitude: Number(req.body.latitude) || 13.7215, longitude: Number(req.body.longitude) || -89.362, isActive: true, createdAt: FieldValue.serverTimestamp() };
    const plan = (await plans.where('name', '==', 'Membresía negocio mensual').limit(1).get()).docs[0];
    const batch = db.batch();
    batch.set(ref, business);
    const subscription = subscriptions.doc();
    batch.set(subscription, { userId: req.user.id, businessId: ref.id, planId: plan?.id || 'monthly-business', status: 'active', amount: 5, createdAt: FieldValue.serverTimestamp(), endsAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000) });
    const payment = payments.doc();
    batch.set(payment, { userId: req.user.id, businessId: ref.id, subscriptionId: subscription.id, amount: 5, currency: 'USD', status: 'succeeded', provider: 'demo', createdAt: FieldValue.serverTimestamp() });
    await batch.commit();
    res.status(201).json({ data: { id: ref.id, ...business, createdAt: null }, payment: { status: 'succeeded', amount: 5, currency: 'USD' } });
  } catch (error) { next(error); }
});

app.post('/businesses/:id/favorite', requireAuth, async (req, res, next) => {
  try { await businesses.doc(req.params.id).collection('favorites').doc(req.user.id).set({ createdAt: FieldValue.serverTimestamp() }); res.sendStatus(204); } catch (error) { next(error); }
});
app.delete('/businesses/:id/favorite', requireAuth, async (req, res, next) => {
  try { await businesses.doc(req.params.id).collection('favorites').doc(req.user.id).delete(); res.sendStatus(204); } catch (error) { next(error); }
});
app.post('/businesses/:id/reviews', requireAuth, async (req, res, next) => {
  try {
    const rating = Number(req.body.rating);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) return res.status(400).json({ error: 'La calificacion debe estar entre 1 y 5' });
    const ref = businesses.doc(req.params.id).collection('reviews').doc(req.user.id);
    const data = { userName: req.user.firstName, rating, comment: String(req.body.comment || '').trim(), createdAt: FieldValue.serverTimestamp() };
    await ref.set(data);
    res.status(201).json({ data: { id: ref.id, ...data, createdAt: null } });
  } catch (error) { next(error); }
});

app.delete('/businesses/:id', requireAuth, async (req, res, next) => {
  try { const ref = businesses.doc(req.params.id); const item = await ref.get(); if (!item.exists || (item.data().ownerId !== req.user.id && !req.user.isAdmin)) return res.sendStatus(404); await ref.update({ isActive: false }); res.sendStatus(204); } catch (error) { next(error); }
});

app.use((error, _req, res, _next) => { console.error(error); res.status(500).json({ error: 'Error interno del servidor' }); });

exports.api = onRequest({ region: 'us-central1', timeoutSeconds: 60, memory: '256MiB' }, app);