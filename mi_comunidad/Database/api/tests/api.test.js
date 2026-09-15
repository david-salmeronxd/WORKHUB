const { test, before, after } = require('node:test');
const assert = require('node:assert');

const { app } = require('../src/index');

let server;
let base;

before(async () => {
  await new Promise((resolve) => {
    server = app.listen(0, () => {
      base = `http://127.0.0.1:${server.address().port}`;
      resolve();
    });
  });
});

after(() => server.close());

test('GET / responde 200 con los endpoints', async () => {
  const res = await fetch(`${base}/`);
  assert.strictEqual(res.status, 200);
  const body = await res.json();
  assert.ok(body.endpoints.includes('GET /health'));
});

test('GET /health responde JSON con status', async () => {
  const res = await fetch(`${base}/health`);
  assert.ok(res.status === 200 || res.status === 503);
  const body = await res.json();
  assert.ok(['ok', 'degraded'].includes(body.status));
  assert.ok(typeof body.uptime === 'number');
});

test('Ruta inexistente responde 404', async () => {
  const res = await fetch(`${base}/no-existe`);
  assert.strictEqual(res.status, 404);
});
