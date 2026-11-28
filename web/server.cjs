const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { performance } = require('node:perf_hooks');
const { handleSafetyRequest } = require('../backend/functions/src/safetyService');

const ROOT = path.resolve(__dirname);
const PROJECT = path.resolve(__dirname, '..');
const STATIC_TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml' };

function readJson(file, fallback = null) {
  try { return JSON.parse(fs.readFileSync(path.join(PROJECT, file), 'utf8')); }
  catch (_) { return fallback; }
}

function createServer() {
  const model = readJson('data_science/models/sosense_inference_bundle.json');
  const metrics = readJson('data_science/reports/ml_evaluation_results.json', {});
  const quality = readJson('data_science/reports/data_quality_report.json', {});
  const snapshot = readJson('backend/functions/safety_summary.json', {});
  const registry = readJson('backend/functions/safety_registry.json', { datasets: [] });
  const testIncidents = [];
  let incidentCounter = 0;
  let journey = null;
  let sensorSession = { state: 'stopped', scenario: null, updatedAt: null };
  let enginePromise;

  const json = (res, status, body) => {
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    res.end(JSON.stringify(body));
  };

  async function readBody(req) {
    const chunks = [];
    let size = 0;
    for await (const chunk of req) {
      size += chunk.length;
      if (size > 1024 * 1024) throw Object.assign(new Error('Request body exceeds 1 MB.'), { status: 413 });
      chunks.push(chunk);
    }
    try { return chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {}; }
    catch (_) { throw Object.assign(new Error('Request body must be valid JSON.'), { status: 400 }); }
  }

  function createTestIncident(body) {
    if (body.isSimulation !== true) throw Object.assign(new Error('Only explicitly simulated incidents are accepted.'), { status: 400 });
    const allowedTypes = new Set(['manual_sos', 'crash_candidate', 'fall_like', 'unusual_movement', 'missed_check_in']);
    const allowedOutcomes = new Set(['confirmed', 'cancelled', 'timeout']);
    if (!allowedTypes.has(body.eventType) || !allowedOutcomes.has(body.outcome)) throw Object.assign(new Error('Unsupported simulated event type or outcome.'), { status: 400 });
    const confidence = body.confidence == null ? null : Number(body.confidence);
    if (confidence != null && (!Number.isFinite(confidence) || confidence < 0 || confidence > 1)) throw Object.assign(new Error('Confidence must be between zero and one.'), { status: 400 });
    const incident = {
      id: `SIM-${String(++incidentCounter).padStart(5, '0')}`,
      eventType: body.eventType,
      triggerSource: body.triggerSource === 'manual' ? 'manual_simulation' : 'sensor_simulation',
      detectionMethod: String(body.detectionMethod || 'manual_test').slice(0, 80),
      confidence,
      status: body.outcome === 'confirmed' ? 'simulation_confirmed' : body.outcome === 'cancelled' ? 'simulation_cancelled' : 'simulation_no_response',
      outcome: body.outcome,
      isSimulation: true,
      label: 'SIMULATED · NOT A REAL EMERGENCY',
      createdAt: new Date().toISOString(),
      dispatch: 'Suppressed. No SMS, email, FCM, or external contact was sent.',
      mockNotice: body.outcome === 'confirmed' ? '[TEST ONLY] A mock notification preview is available in this browser.' : null,
    };
    testIncidents.unshift(incident);
    if (testIncidents.length > 500) testIncidents.length = 500;
    return incident;
  }

  async function route(req, res) {
    let url;
    try { url = new URL(req.url, 'http://127.0.0.1'); }
    catch (_) { return json(res, 400, { error: 'bad_request' }); }
    const pathname = url.pathname.replace(/\/$/, '') || '/';

    try {
      if (pathname === '/api/health' && req.method === 'GET') {
        return json(res, 200, { ok: true, service: 'SOS Local Demo Server', simulationOnly: true, modelReady: Boolean(model?.trees?.length), timestamp: new Date().toISOString() });
      }
      if (pathname === '/api/dashboard' && req.method === 'GET') {
        const modelRows = metrics.model_comparison || [];
        return json(res, 200, {
          model: { name: model?.model_type || null, version: model?.version || null, trees: model?.trees?.length || 0 },
          corpus: { rows: quality.after_cleaning?.row_count ?? null, sources: (readJson('data_science/datasets/raw/dataset_manifest.json', {}).datasets || []).map((d) => ({ id: d.id, name: d.name, containsRealAccidents: d.contains_real_accidents === true, role: d.role_in_pipeline })) },
          evaluation: { testRows: (metrics.uci_har_real_only_6class_eval || {}).real_only_test_samples ?? null, realHarAccuracy: (metrics.uci_har_real_only_6class_eval || {}).accuracy ?? null, realHarMacroF1: (metrics.uci_har_real_only_6class_eval || {}).macro_f1 ?? null, benchmark: modelRows.find((item) => item.model_name === 'Random Forest') || null },
          safetyAvailability: snapshot.availability || 'unavailable',
          realIncidentConnection: 'not_configured',
          testIncidentCount: testIncidents.length,
          sensorState: sensorSession.state,
          journeyActive: Boolean(journey?.active),
        });
      }
      if (pathname === '/api/ml/status' && req.method === 'GET') {
        return json(res, 200, {
          ready: Boolean(model?.trees?.length),
          modelName: model?.model_type || null,
          version: model?.version || null,
          nEstimators: model?.trees?.length || 0,
          featureColumns: model?.feature_columns || [],
          classes: model?.classes || [],
          inference: 'existing exported model bundle; same 20 model features and scaler as Flutter',
          confidenceSupported: true,
          caveat: 'Existing benchmark includes controlled synthetic anomaly windows; metrics are not real-world accident/fall performance.',
          evaluation: metrics.model_comparison || [],
          realHar: metrics.uci_har_real_only_6class_eval || null,
        });
      }
      if (pathname === '/api/ml/predict' && req.method === 'POST') {
        if (!model?.trees?.length) return json(res, 503, { error: 'model_unavailable' });
        const body = await readBody(req);
        if (body.isSimulation !== true) return json(res, 400, { error: 'local_model_endpoint_requires_simulation_flag' });
        if (body.sensitivity != null && !['low', 'medium', 'high'].includes(body.sensitivity)) return json(res, 400, { error: 'invalid_sensitivity' });
        if (!enginePromise) enginePromise = import('./src/sensor-engine.mjs');
        const engine = await enginePromise;
        const started = performance.now();
        let features;
        try { features = engine.extractFeatures(body.samples); }
        catch (error) { throw Object.assign(error, { status: 400 }); }
        const prediction = engine.predictWithModel(features, model, body.sensitivity || 'medium');
        prediction.inferenceMs = Number((performance.now() - started).toFixed(3));
        prediction.isSimulation = true;
        return json(res, 200, prediction);
      }
      if (pathname === '/api/history/real' && req.method === 'GET') {
        return json(res, 200, { connected: false, records: [], message: 'Configure a Firebase web project and sign in to view a user’s real incident history.' });
      }
      if (pathname === '/api/simulation/incidents' && req.method === 'GET') {
        return json(res, 200, { records: testIncidents, persistence: 'in-memory for this local server session', simulationOnly: true });
      }
      if (pathname === '/api/simulation/incidents' && req.method === 'POST') {
        return json(res, 201, { incident: createTestIncident(await readBody(req)) });
      }
      if (pathname === '/api/simulation/reset' && req.method === 'POST') {
        testIncidents.length = 0;
        incidentCounter = 0;
        journey = null;
        sensorSession = { state: 'stopped', scenario: null, updatedAt: new Date().toISOString() };
        return json(res, 200, { reset: true, simulationOnly: true });
      }
      if (pathname === '/api/simulation/sensors' && req.method === 'GET') return json(res, 200, sensorSession);
      if (pathname === '/api/simulation/sensors' && req.method === 'POST') {
        const body = await readBody(req);
        if (!['start', 'pause', 'resume', 'stop', 'reset'].includes(body.action)) return json(res, 400, { error: 'invalid_sensor_action' });
        sensorSession = { state: body.action === 'start' || body.action === 'resume' ? 'running' : body.action === 'pause' ? 'paused' : 'stopped', scenario: ['stop', 'reset'].includes(body.action) ? null : String(body.scenario || sensorSession.scenario || 'custom').slice(0, 50), updatedAt: new Date().toISOString() };
        return json(res, 200, sensorSession);
      }
      if (pathname === '/api/simulation/journey' && req.method === 'GET') return json(res, 200, { journey, simulationOnly: true });
      if (pathname === '/api/simulation/journey' && req.method === 'POST') {
        const body = await readBody(req);
        if (body.action === 'start') {
          const label = String(body.label || 'Laptop safety check-in').trim().slice(0, 80);
          const minutes = Number(body.durationMinutes);
          if (!Number.isFinite(minutes) || minutes < 1 || minutes > 480) return json(res, 400, { error: 'duration must be 1-480 minutes' });
          journey = { id: `JOURNEY-${Date.now()}`, label, startedAt: new Date().toISOString(), dueAt: new Date(Date.now() + minutes * 60000).toISOString(), active: true, status: 'active', checkins: 0, isSimulation: true };
        } else if (body.action === 'checkin' && journey?.active) {
          journey = { ...journey, status: 'checked_in', checkins: journey.checkins + 1, lastCheckinAt: new Date().toISOString() };
        } else if (['finish', 'missed'].includes(body.action) && journey?.active) {
          journey = { ...journey, active: false, status: body.action === 'finish' ? 'completed' : 'missed_simulated', finishedAt: new Date().toISOString() };
          if (body.action === 'missed') createTestIncident({ isSimulation: true, eventType: 'missed_check_in', outcome: 'confirmed', triggerSource: 'sensor', detectionMethod: 'journey_simulation', confidence: null });
        } else {
          return json(res, 409, { error: 'no_active_journey_or_invalid_action' });
        }
        return json(res, 200, { journey });
      }

      const safetyMatch = pathname.match(/^\/api\/safety(\/.*)?$/);
      if (safetyMatch && req.method === 'GET') {
        const safetyPath = safetyMatch[1] || '';
        const result = handleSafetyRequest({ method: 'GET', path: safetyPath, snapshot, registry });
        return json(res, result.status, result.body);
      }
      if (pathname === '/api/diagnostics' && req.method === 'GET') {
        return json(res, 200, {
          node: process.version,
          api: 'online',
          modelLoaded: Boolean(model?.trees?.length),
          firebaseProjectConfigured: Boolean(process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PROJECT_ID !== 'your-firebase-project-id'),
          firebase: 'not connected by the local demo server',
          simulationMode: 'enforced; external notifications are unreachable from simulation routes',
          safetyData: snapshot.availability || 'unavailable',
          userChangesDetected: false,
        });
      }
      if (pathname.startsWith('/api/')) return json(res, 404, { error: 'not_found' });

      let requestPath;
      try { requestPath = decodeURIComponent(pathname); }
      catch (_) { return json(res, 400, { error: 'bad_path' }); }
      const target = path.resolve(ROOT, `.${requestPath === '/' ? '/index.html' : requestPath}`);
      if (target !== ROOT && !target.startsWith(`${ROOT}${path.sep}`)) return json(res, 403, { error: 'forbidden' });
      if (!fs.existsSync(target) || !fs.statSync(target).isFile()) return json(res, 404, { error: 'not_found' });
      res.writeHead(200, {
        'Content-Type': STATIC_TYPES[path.extname(target)] || 'application/octet-stream',
        'X-Content-Type-Options': 'nosniff',
        'Referrer-Policy': 'no-referrer',
        'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://tile.openstreetmap.org; connect-src 'self'; frame-src https://www.openstreetmap.org; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
        'Cache-Control': target.endsWith('index.html') ? 'no-cache' : 'public, max-age=300',
      });
      fs.createReadStream(target).pipe(res);
    } catch (error) {
      json(res, error.status || 500, { error: error.status ? 'invalid_request' : 'internal_error', message: error.status ? error.message : 'Local server request failed.' });
    }
  }

  return http.createServer((req, res) => { void route(req, res); });
}

if (require.main === module) {
  const port = Number(process.env.SOS_PORT || process.env.PORT || 3000);
  const host = process.env.SOS_HOST || '127.0.0.1';
  const server = createServer();
  server.on('error', (error) => {
    if (error.code === 'EADDRINUSE') {
      console.error(`Port ${port} is already in use. Set SOS_PORT to another free port and retry.`);
    } else console.error(`SOS local server failed: ${error.message}`);
    process.exitCode = 1;
  });
  server.listen(port, host, () => {
    console.log(`SOS local platform is ready at http://${host}:${port}`);
    console.log('Simulation-only server. No Firebase, SMS, email or FCM dispatch is connected. Press Ctrl+C to stop.');
  });
}

module.exports = { createServer };
