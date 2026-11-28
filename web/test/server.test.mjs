import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { SCENARIOS, sampleScenario } from '../src/sensor-scenarios.mjs';
import serverPackage from '../server.cjs';

const server = serverPackage.createServer();
let base;
before(async () => {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(async () => new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve())));

async function request(path, method = 'GET', body = undefined) {
  const response = await fetch(`${base}${path}`, { method, headers: body === undefined ? {} : { 'Content-Type': 'application/json' }, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: response.status, headers: response.headers, body: await response.json() };
}

test('serves the actual laptop app and safe service status on loopback', async () => {
  const page = await fetch(base);
  assert.equal(page.status, 200);
  assert.match(await page.text(), /SOSense/);
  assert.match(page.headers.get('content-security-policy'), /script-src 'self'/);
  assert.equal((await request('/api/health')).body.simulationOnly, true);
  assert.equal((await request('/api/diagnostics')).body.firebase, 'not connected by the local demo server');
});

test('exposes real evaluation files and explicit aggregate safety unavailability', async () => {
  const model = (await request('/api/ml/status')).body;
  assert.equal(model.nEstimators, 30);
  assert.equal(model.featureColumns.length, 20);
  assert.ok(model.evaluation.some((row) => row.model_name === 'Random Forest'));
  const safety = (await request('/api/safety')).body;
  assert.equal(safety.dataStatus, 'historical');
  assert.equal(safety.availability, 'unavailable');
  assert.deepEqual(safety.accidents.records, []);
  assert.deepEqual(safety.crimes.records, []);
  assert.equal((await request('/api/safety/nearby')).status, 404);
});

test('runs the actual exported model through the API and validates model windows', async () => {
  await request('/api/simulation/reset', 'POST', {});
  const samples = Array.from({ length: 128 }, (_, index) => ({ ...sampleScenario('walking', index), timestamp: new Date(index * 20).toISOString() }));
  const rejected = await request('/api/ml/predict', 'POST', { samples });
  assert.equal(rejected.status, 400);
  assert.equal(rejected.body.error, 'local_model_endpoint_requires_simulation_flag');
  const predicted = await request('/api/ml/predict', 'POST', { isSimulation: true, samples });
  assert.equal(predicted.status, 200);
  assert.equal(predicted.body.isSimulation, true);
  assert.ok(['normal', 'crash_candidate', 'fall_like', 'unusual_movement'].includes(predicted.body.predictedCategory));
  assert.ok(predicted.body.confidence >= 0 && predicted.body.confidence <= 1);
  assert.ok(predicted.body.inferenceMs >= 0);
  assert.equal((await request('/api/ml/predict', 'POST', { isSimulation: true, samples: samples.slice(0, 20) })).status, 400);
  const huge = samples.map((sample) => ({ ...sample, ax: 200 }));
  assert.equal((await request('/api/ml/predict', 'POST', { isSimulation: true, samples: huge })).status, 400);
});

test('simulation endpoint rejects real incident requests and stores only suppressed test outcomes', async () => {
  const body = { eventType: 'manual_sos', outcome: 'confirmed', detectionMethod: 'manual_test', confidence: null };
  assert.equal((await request('/api/simulation/incidents', 'POST', body)).status, 400);
  const created = await request('/api/simulation/incidents', 'POST', { ...body, isSimulation: true });
  assert.equal(created.status, 201);
  assert.equal(created.body.incident.isSimulation, true);
  assert.match(created.body.incident.label, /SIMULATED/);
  assert.match(created.body.incident.dispatch, /Suppressed/);
  assert.ok(created.body.incident.mockNotice.includes('TEST ONLY'));
  const history = await request('/api/simulation/incidents');
  assert.equal(history.body.records.length, 1);
});

test('journey simulator check-in and missed state only creates a test incident', async () => {
  await request('/api/simulation/reset', 'POST', {});
  assert.equal((await request('/api/simulation/journey', 'POST', { action: 'start', label: 'Test walk', durationMinutes: 5 })).status, 200);
  assert.equal((await request('/api/simulation/journey', 'POST', { action: 'checkin' })).body.journey.checkins, 1);
  const missed = await request('/api/simulation/journey', 'POST', { action: 'missed' });
  assert.equal(missed.body.journey.status, 'missed_simulated');
  const incidents = (await request('/api/simulation/incidents')).body.records;
  assert.equal(incidents.length, 1);
  assert.equal(incidents[0].eventType, 'missed_check_in');
  assert.equal(incidents[0].isSimulation, true);
  assert.equal((await request('/api/simulation/journey', 'POST', { action: 'missed' })).status, 409);
});

test('reset clears simulator memory without affecting real history', async () => {
  await request('/api/simulation/reset', 'POST', {});
  assert.equal((await request('/api/simulation/incidents')).body.records.length, 0);
  assert.equal((await request('/api/history/real')).body.connected, false);
});

test('serves module assets and refuses traversal outside the web root', async () => {
  assert.equal((await fetch(`${base}/src/app.js`)).status, 200);
  assert.equal((await fetch(`${base}/%2e%2e%2fserver.cjs`)).status, 403);
  assert.equal((await fetch(`${base}/api/unknown`)).status, 404);
});
