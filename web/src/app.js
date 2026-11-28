import { SCENARIOS, sampleScenario } from './sensor-scenarios.mjs';

const content = document.querySelector('#content');
const crumb = document.querySelector('#page-crumb');
const dialog = document.querySelector('#verification-dialog');
const titles = { overview: 'Overview', safety: 'Safety map', analytics: 'Analytics', sensor: 'Sensor simulation lab', emergency: 'Emergency test', journey: 'Journey simulator', incidents: 'Incident history', contacts: 'Profile & contacts', model: 'Model & data', diagnostics: 'Diagnostics' };
const state = {
  page: 'overview', scenario: 'walking', running: false, paused: false, speed: 1,
  sampleIndex: 0, samples: [], window: [], lastInferenceIndex: 0, predictionBusy: false,
  latestPrediction: null, predictions: 0, anomalies: 0, timer: null, chartTimer: null,
  countdownTimer: null, countdownSec: 10, emergency: null, incidents: [], journey: null,
  startedAtMs: 0, alertLatched: false,
  safety: null, safetyFilter: '', incidentFilter: 'all', notice: '',
};

const esc = (value = '') => String(value).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const pretty = (value) => String(value ?? '').replaceAll('_', ' ').replace(/\b\w/g, (c) => c.toUpperCase());
const num = (value, places = 2) => Number.isFinite(Number(value)) ? Number(value).toFixed(places) : '—';
const when = (value) => value ? new Date(value).toLocaleString() : '—';

async function api(path, options = {}) {
  const response = await fetch(path, { ...options, headers: { ...(options.body ? { 'Content-Type': 'application/json' } : {}), ...(options.headers || {}) } });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.message || body.error || `Local API returned ${response.status}`);
  return body;
}

function toast(message) {
  const node = document.querySelector('#toast');
  node.textContent = message;
  node.classList.add('show');
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => node.classList.remove('show'), 3000);
}

function heading(title, subtitle, actions = '') {
  return `<div class="page-heading"><div><span class="eyebrow">SOSENSE LOCAL WORKSPACE</span><h1>${title}</h1><p>${subtitle}</p></div><div class="heading-actions">${actions}</div></div>`;
}

function metric(label, value, foot, icon, color = '#168f80', soft = '#e8f5f1') {
  return `<article class="card metric-card" style="--metric:${color};--metric-soft:${soft}"><div class="metric-top"><span class="metric-label">${label}</span><span class="metric-icon">${icon}</span></div><div class="metric-value">${value}</div><div class="metric-foot">${foot}</div></article>`;
}

function emptyState(title, description, icon = '◎') {
  return `<div class="empty-state"><div class="empty-icon">${icon}</div><strong>${esc(title)}</strong><p>${esc(description)}</p></div>`;
}

function barChart(rows, valueKey, labelKey, { max = 1, color = 'teal', percent = false } = {}) {
  if (!rows?.length) return `<div class="chart-empty">No measured rows available.</div>`;
  const fill = color === 'blue' ? '#668bc4' : color === 'amber' ? '#e2a343' : '#16a18f';
  return `<div class="metric-bar-list">${rows.map((r) => {
    const value = Number(r[valueKey]);
    const width = Math.max(0, Math.min(100, value / max * 100));
    return `<div class="metric-bar" title="${esc(r[labelKey])}: ${percent ? (value * 100).toFixed(1) + '%' : value}"><span>${esc(r[labelKey])}</span><div class="progress-track"><div class="progress-fill" style="width:${width}%;background:${fill}"></div></div><b>${percent ? (value * 100).toFixed(1) + '%' : value}</b></div>`;
  }).join('')}</div>`;
}

function lineChart(samples, fields, labels, colors) {
  if (!samples.length) return `<div class="chart-empty">Start the sensor simulator to draw live samples.</div>`;
  const width = 640, height = 150, pad = 12;
  const values = samples.flatMap((s) => fields.map((f) => s[f]));
  const min = Math.min(...values), max = Math.max(...values), span = Math.max(0.01, max - min);
  const paths = fields.map((field, series) => {
    const d = samples.map((sample, i) => {
      const x = pad + (i / Math.max(1, samples.length - 1)) * (width - 2 * pad);
      const y = height - pad - ((sample[field] - min) / span) * (height - 2 * pad);
      return `${i ? 'L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`;
    }).join(' ');
    return `<path d="${d}" class="signal-path ${colors[series] || ''}"/>`;
  }).join('');
  return `<svg class="signal-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="Live ${labels.join(', ')} graph"><path class="signal-grid" d="M0 28H640M0 65H640M0 102H640M0 139H640"/>${paths}<text class="signal-axis" x="4" y="12">${num(max, 1)}</text><text class="signal-axis" x="4" y="148">${num(min, 1)}</text></svg>`;
}

function metricCard(title, subtitle, chart, legend = '') {
  return `<section class="card signal-card"><div class="signal-head"><h3>${title}</h3><small>${subtitle}</small></div>${chart}${legend}</section>`;
}

async function render() {
  document.querySelectorAll('.nav-item[data-page]').forEach((button) => button.classList.toggle('active', button.dataset.page === state.page));
  crumb.textContent = titles[state.page] || 'Overview';
  content.innerHTML = `<div class="loading-state"><span class="spinner"></span> Loading ${esc(titles[state.page])}…</div>`;
  try {
    const pageFns = { overview: renderOverview, safety: renderSafety, analytics: renderAnalytics, sensor: renderSensor, emergency: renderEmergency, journey: renderJourney, incidents: renderIncidents, contacts: renderContacts, model: renderModel, diagnostics: renderDiagnostics };
    content.innerHTML = await pageFns[state.page]();
    if (state.page === 'sensor') paintTelemetry();
    if (state.page === 'incidents') filterIncidentRows();
  } catch (error) {
    content.innerHTML = `${heading('Workspace unavailable', 'The local service returned an error. The simulation has not sent any external alert.')}<div class="card">${emptyState('Could not load this page', error.message, '⚠')}<div class="spacer"></div><button class="button secondary" data-action="retry-page">Retry</button></div>`;
  }
}

async function renderOverview() {
  const dash = await api('/api/dashboard');
  const tests = await api('/api/simulation/incidents');
  const journeyData = await api('/api/simulation/journey');
  state.incidents = tests.records;
  state.journey = journeyData.journey;
  const confirmed = tests.records.filter((r) => r.outcome === 'confirmed').length;
  const manualConfirmed = tests.records.filter((r) => r.eventType === 'manual_sos' && r.outcome === 'confirmed').length;
  const statusText = dash.safetyAvailability === 'available' ? 'Historical source rows processed' : dash.safetyAvailability === 'partial' ? 'Some source files are missing' : 'Official source CSVs not ingested';
  const recent = tests.records.slice(0, 5);
  const actions = `<span class="sim-banner"><span class="pulse-dot"></span>SIMULATION ISOLATION ON</span><button class="button primary" data-page="sensor">Open sensor lab <span>↗</span></button>`;
  return `${heading(`Good day, ${esc(getProfile().name || 'there')}`, 'Local safety workspace · test-only data is kept separate from real SOS incidents.', actions)}
    <div class="data-note"><span>ⓘ</span><div><strong>Local demo workspace.</strong> Real incident history and Firebase are not connected. All events made here are marked SIMULATED and cannot reach emergency contacts.</div></div>
    <div class="grid metrics">
      ${metric('REAL INCIDENT HISTORY', 'Not connected', 'Firebase project configuration required', '▣', '#7b8793', '#eef1f4')}
      ${metric('SIMULATED ANOMALIES', state.anomalies, 'Model-labelled test windows this session', '⌁', '#bf872e', '#fbf3e6')}
      ${metric('CONFIRMED MANUAL SOS TESTS', manualConfirmed, 'Local simulated incidents only', '✳', '#4981ba', '#eaf2fa')}
      ${metric('SAFETY JOURNEY', journeyData.journey?.active ? 'Active' : 'None', journeyData.journey?.active ? esc(journeyData.journey.label) : 'No local test journey running', '↗', '#168f80', '#e8f5f1')}
      ${metric('NEARBY ACCIDENTS', 'Unavailable', 'No station coordinates in source data', '↯', '#bd872f', '#fbf3e6')}
      ${metric('NEARBY CRIME', 'Unavailable', 'Crime counts have city-level precision', '⌖', '#9271ae', '#f2edf7')}
      ${metric('SENSOR SIMULATOR', state.running ? 'Running' : 'Stopped', state.running ? `${state.sampleIndex} simulated samples` : 'No laptop sensor is being read', '⌁', '#527fb5', '#eaf1f8')}
      ${metric('EMERGENCY TEST', state.emergency ? 'Awaiting response' : 'Idle', state.emergency ? 'Simulation verification open' : `${confirmed} test outcomes in local history`, '✳', '#c05a5a', '#faeded')}
    </div>
    <div class="grid two">
      <section class="card"><div class="section-title"><div><h2>Sensor stream</h2><p>${state.running ? 'Live simulated stream' : 'Waiting for a simulation'} · 50 Hz model window</p></div><span class="status-badge ${state.running ? 'green' : ''}"><span class="dot"></span>${state.running ? 'SIMULATING' : 'STOPPED'}</span></div>
        ${metricCard('Acceleration · m/s²', 'X / Y / Z', lineChart(state.samples.slice(-120), ['ax', 'ay', 'az'], ['X', 'Y', 'Z'], ['', 'blue', 'amber']), '<div class="legend"><span><i></i>X axis</span><span><i class="blue"></i>Y axis</span><span><i class="amber"></i>Z axis</span></div>')}
        <div class="spacer"></div><button class="button secondary" data-page="sensor">Open sensor lab →</button>
      </section>
      <section class="card"><div class="section-title"><div><h2>Model snapshot</h2><p>Actual held-out evaluation results from the repository report</p></div><span class="status-badge green"><span class="dot"></span>${esc(dash.model?.name || 'Model unavailable')}</span></div>
        <div class="callout-stat"><strong>${dash.evaluation.realHarAccuracy == null ? '—' : (dash.evaluation.realHarAccuracy * 100).toFixed(1) + '%'}</strong><span>real-only UCI HAR activity accuracy</span></div>
        <p>On real HAR activity windows only; this is activity recognition, not real-world fall or crash performance.</p>
        <div class="metric-bar-list"><div class="metric-bar"><span>Real HAR test windows</span><div class="progress-track"><div class="progress-fill blue" style="width:100%"></div></div><b>${dash.evaluation.testRows ?? '—'}</b></div><div class="metric-bar"><span>Exported RF trees</span><div class="progress-track"><div class="progress-fill" style="width:${Math.min(100, dash.model?.trees / 30 * 100 || 0)}%"></div></div><b>${dash.model?.trees ?? '—'}</b></div></div>
        <div class="spacer"></div><button class="text-link" data-page="model">Review model details →</button>
      </section>
      <section class="card"><div class="section-title"><div><h2>Latest test events</h2><p>Simulation-only records from this local server session</p></div><button class="text-link" data-page="incidents">View history →</button></div>
        ${recent.length ? `<div class="table-scroll"><table class="data-table"><thead><tr><th>Test event</th><th>Outcome</th><th>Time</th></tr></thead><tbody>${recent.map((r) => `<tr><td><span class="badge-sim">SIM</span> ${esc(pretty(r.eventType))}</td><td>${esc(pretty(r.outcome))}</td><td>${esc(new Date(r.createdAt).toLocaleTimeString())}</td></tr>`).join('')}</tbody></table></div>` : emptyState('No test events yet', 'Start a scenario or run a manual emergency test. Nothing here represents a real incident.', '☷')}
      </section>
      <section class="card"><div class="section-title"><div><h2>Safety data status</h2><p>Historical awareness sources only</p></div><span class="status-badge amber"><span class="dot"></span>${esc(pretty(dash.safetyAvailability))}</span></div>
        <div class="source-row"><span class="source-icon">↯</span><div class="source-copy"><strong>Bengaluru road crashes · 2023</strong><small>Police-station aggregate. No event coordinates or dates.</small></div><span class="source-state">${esc(statusText)}</span></div>
        <div class="source-row"><span class="source-icon">⌖</span><div class="source-copy"><strong>Bengaluru crime · 2021–2023</strong><small>City totals by category. No street-level location.</small></div><span class="source-state">${esc(statusText)}</span></div>
        <div class="spacer"></div><button class="button secondary small" data-page="safety">Open safety data →</button>
      </section>
    </div>`;
}

async function renderAnalytics() {
  const info = await api('/api/ml/status');
  const dash = await api('/api/dashboard');
  const rows = info.evaluation || [];
  const rf = rows.find((row) => row.model_name === 'Random Forest');
  const warnings = `<div class="data-note"><span>ⓘ</span><div>Model benchmark includes controlled synthetic anomaly windows and held-out real HAR activity windows. Use the real-only HAR result as activity recognition context. Neither is a measured real-world emergency detection rate.</div></div>`;
  return `${heading('Analytics', 'Measured training results and quality context from the project reports.', '<span class="status-badge green"><span class="dot"></span>SOURCE-BASED</span>')}${warnings}
    <div class="grid metrics">${metric('MODEL TEST WINDOWS', dash.evaluation.testRows ?? '—', 'Real-only UCI HAR held-out set', '⌁', '#527fb5', '#eaf1f8')}${metric('ACTIVITY ACCURACY', dash.evaluation.realHarAccuracy == null ? '—' : `${(dash.evaluation.realHarAccuracy * 100).toFixed(1)}%`, 'Real-only UCI HAR 6-class result', '◈')}${metric('REAL HAR MACRO F1', dash.evaluation.realHarMacroF1 == null ? '—' : num(dash.evaluation.realHarMacroF1 * 100, 1) + '%', 'Across six activity labels', '▥', '#a17bb5', '#f3eef8')}${metric('RF TREE COUNT', info.nEstimators || '—', `Bundle version ${esc(info.version || 'unavailable')}`, '⌘')}</div>
    <div class="grid two"><section class="card"><div class="section-title"><div><h2>Model comparison · test accuracy</h2><p>Controlled event benchmark results from ml_evaluation_results.json</p></div></div>${barChart(rows, 'test_accuracy', 'model_name', { max: 1, percent: true })}<p class="small-copy">Random Forest benchmark accuracy: ${rf ? (rf.test_accuracy * 100).toFixed(1) + '%' : 'not available'}. These held-out windows include controlled simulated anomaly classes; they do not establish real-world emergency accuracy.</p></section>
      <section class="card"><div class="section-title"><div><h2>Model comparison · macro F1</h2><p>Reported class-balanced metric</p></div></div>${barChart(rows, 'macro_f1', 'model_name', { max: 1, percent: true, color: 'blue' })}<div class="notice-box">Macro F1 and the related confusion matrix are from the documented test split. Synthetic anomaly classes make these figures unsuitable as field safety claims.</div></section>
      <section class="card"><div class="section-title"><div><h2>Real activity baseline</h2><p>UCI HAR six-class test set · 2,947 real smartphone windows</p></div></div>${barChart(Object.entries(info.realHar?.classification_report || {}).filter(([key]) => !['accuracy', 'macro avg', 'weighted avg'].includes(key)).map(([name, values]) => ({ name, f1: values['f1-score'] })), 'f1', 'name', { max: 1, percent: true, color: 'amber' })}</section>
      <section class="card"><div class="section-title"><div><h2>Sensor corpus provenance</h2><p>Quality report and dataset manifest</p></div></div>
        <div class="source-row"><span class="source-icon">◉</span><div class="source-copy"><strong>Real UCI HAR activity windows</strong><small>10,299 smartphone windows · 30 participants · does not contain real falls or crashes.</small></div><span class="source-state" style="color:#18836f;background:#e6f5f0">REAL ACTIVITY</span></div>
        <div class="source-row"><span class="source-icon">⌁</span><div class="source-copy"><strong>Controlled anomaly windows</strong><small>1,200 physics-informed test/training windows tagged as synthetic, not real emergency data.</small></div><span class="source-state">SIMULATED</span></div>
        <div class="source-row"><span class="source-icon">✓</span><div class="source-copy"><strong>Feature pipeline</strong><small>4th order low-pass filter offline; 20 features; subject-disjoint training/testing splits.</small></div><span class="source-state" style="color:#18836f;background:#e6f5f0">DOCUMENTED</span></div>
      </section></div>`;
}

async function renderSafety() {
  const [snapshot, sources, quality] = await Promise.all([api('/api/safety'), api('/api/safety/sources'), api('/api/safety/refresh-status')]);
  state.safety = { snapshot, sources };
  const accidentRows = snapshot.accidents?.records || [];
  const crimeRows = snapshot.crimes?.records || [];
  return `${heading('Safety map', 'Historical reported-incident awareness. Counts are shown only at source-supported precision.', '<button class="button secondary" data-action="refresh-safety">↻ Refresh source status</button>')}
    <div class="data-note"><span>ⓘ</span><div><strong>No live feed.</strong> Road crash totals are by police station; crime totals are city/category aggregates. The actual source files are not currently bundled, and neither source provides incident coordinates. No incident pins, precise nearby distances, or street-level safety score are displayed.</div></div>
    <div class="grid metrics">${metric('ACCIDENT TABLE', accidentRows.length ? accidentRows.length : 'Unavailable', accidentRows.length ? 'Validated station aggregate rows' : 'CSV download was blocked; no rows ingested', '↯', '#bd872f', '#fbf3e6')}${metric('CRIME TABLE', crimeRows.length ? crimeRows.length : 'Unavailable', crimeRows.length ? 'Validated city category rows' : 'CSV download was blocked; no rows ingested', '⌖', '#9271ae', '#f2edf7')}${metric('GEOGRAPHIC PRECISION', 'Aggregate', 'No GPS/event geometries', '◎', '#527fb5', '#eaf1f8')}${metric('DATA STATUS', 'Historical', 'Never labelled as live', '◷', '#168f80', '#e8f5f1')}</div>
    <div class="grid two"><section class="card"><div class="section-title"><div><h2>Bengaluru city view</h2><p>Reference basemap only · no source-supported incident markers</p></div><span class="status-badge amber"><span class="dot"></span>NO GEO RECORDS</span></div>
      <div class="map-wrap"><iframe class="map-frame" title="OpenStreetMap Bengaluru city reference basemap" loading="lazy" src="https://www.openstreetmap.org/export/embed.html?bbox=77.35%2C12.78%2C77.78%2C13.12&amp;layer=mapnik"></iframe><div class="map-overlay">City framing · no incidents plotted</div></div><p class="map-caption">Map data © OpenStreetMap contributors. The basemap frames Bengaluru; it does not represent safety records or hotspot coordinates.</p>
      <div class="map-legend"><div class="legend-line"><span class="legend-dot"></span>Accident layer · no spatial records available</div><div class="legend-line"><span class="legend-dot crime"></span>Crime layer · no spatial records available</div><div class="legend-line"><span class="legend-dot combined"></span>Combined layer · no joinable geographies</div></div>
      <div class="filter-row"><label class="checkbox-row"><input type="checkbox" checked disabled> Accident source</label><label class="checkbox-row"><input type="checkbox" checked disabled> Crime source</label><select class="search-input" disabled aria-label="Historical year filter"><option>Source periods: 2023 / 2021–2023</option></select></div>
      <p class="small-copy">Search and nearby filters require official spatial records or boundaries. Aggregate station/city totals cannot be geocoded as incidents.</p>
    </section>
    <section class="card"><div class="section-title"><div><h2>Dataset registry</h2><p>Publisher metadata and refresh state from the repository registry</p></div></div>${sources.map((source) => {
      const update = quality.find((r) => r.id === source.id);
      return `<div class="source-row"><span class="source-icon">${source.format === 'PDF' ? '▤' : '▦'}</span><div class="source-copy"><strong>${esc(source.title)}</strong><small>${esc(source.publisher)} · Period ${esc(source.reportingPeriod)} · ${esc(source.spatialPrecision)} · ${esc(source.license)}</small><small>Refresh: ${esc(pretty(update?.status || source.status))} · last successful processing: ${esc(when(update?.lastSuccessfulUpdateAt))}</small><small><a href="${esc(source.sourceUrl)}" target="_blank" rel="noreferrer">Open source catalogue ↗</a></small></div></div>`;
    }).join('')}</section>
    <section class="card"><div class="section-title"><div><h2>Accident station totals</h2><p>2023 · fatal and non-fatal figures remain separate</p></div></div>${accidentRows.length ? `<div class="table-scroll"><table class="data-table"><thead><tr><th>Station</th><th>Total</th><th>Fatal cases</th><th>People killed</th></tr></thead><tbody>${accidentRows.map((r) => `<tr><td>${esc(r.station)}</td><td>${esc(r.totalCases ?? '—')}</td><td>${esc(r.fatalCases ?? '—')}</td><td>${esc(r.peopleKilled ?? '—')}</td></tr>`).join('')}</tbody></table></div>` : emptyState('Crash CSV is not ingested', 'The OpenCity file has station totals but no incident coordinates. A validated file is required before counts can be calculated.', '↯')}</section>
    <section class="card"><div class="section-title"><div><h2>Crime categories</h2><p>City-level reported/detected counts · 2021–2023</p></div><input class="search-input" id="safety-search" placeholder="Filter source category…" ${crimeRows.length ? '' : 'disabled'}></div>${crimeRows.length ? `<div class="table-scroll"><table class="data-table" id="crime-table"><thead><tr><th>Source crime type</th><th>Reported 2021</th><th>Reported 2022</th><th>Reported 2023</th></tr></thead><tbody>${crimeRows.map((r) => `<tr data-category="${esc(r.sourceCategory.toLowerCase())}"><td>${esc(r.sourceCategory)}</td><td>${esc(r.reported2021 ?? '—')}</td><td>${esc(r.reported2022 ?? '—')}</td><td>${esc(r.reported2023 ?? '—')}</td></tr>`).join('')}</tbody></table></div>` : emptyState('Crime CSV is not ingested', 'The discovered resource is a citywide crime-type aggregate, not police-station or incident-level data.', '⌖')}</section></div>
    <div class="spacer"></div><div class="notice-box">${esc(snapshot.message || 'Safety information is based on available reported historical or periodically updated records. Data may be incomplete, delayed, or affected by reporting bias. Concentration levels do not guarantee the safety or danger of a location.')}</div>`;
}

async function renderSensor() {
  const [ml, sensorSession] = await Promise.all([api('/api/ml/status'), api('/api/simulation/sensors')]);
  const selected = state.scenario;
  const options = [{ value: .5, label: '0.5×' }, { value: 1, label: '1× real time' }, { value: 2, label: '2×' }, { value: 5, label: '5× fast demo' }];
  const actions = `<span class="sim-banner">SIMULATED SENSOR DATA · NOT A REAL DEVICE</span>`;
  return `${heading('Sensor simulation lab', 'A bounded 50 Hz laptop sensor stream through the existing 128-sample ML pipeline.', actions)}
    <div class="data-note info"><span>⌁</span><div>These values are generated test signals in SI units. The existing model returns a motion classification; it does not establish that a real accident or fall occurred.</div></div>
    <section class="card"><div class="section-title"><div><h2>Scenario presets</h2><p>Select a bounded test signal. Running a preset resets its window and starts the simulator.</p></div><span class="status-badge ${state.running ? 'green' : ''}"><span class="dot"></span>${state.running ? `STREAMING · ${esc(pretty(state.scenario))}` : 'STOPPED'}</span></div>
      <div class="scenario-grid">${SCENARIOS.map((scenario) => `<button class="scenario-button ${selected === scenario.id ? 'selected' : ''}" data-action="scenario" data-scenario="${scenario.id}"><b>${esc(scenario.label)}</b><span>${esc(scenario.description)}</span></button>`).join('')}</div>
      <div class="spacer"></div><div class="control-row"><button class="button primary" data-action="start-sensor">▶ Start / restart</button><button class="button secondary" data-action="pause-sensor" ${state.running && !state.paused ? '' : 'disabled'}>Ⅱ Pause</button><button class="button secondary" data-action="resume-sensor" ${state.paused ? '' : 'disabled'}>▶ Resume</button><button class="button secondary" data-action="stop-sensor" ${state.running || state.paused ? '' : 'disabled'}>■ Stop</button><button class="button secondary" data-action="reset-sensor">↺ Reset</button>
      <label class="range-control">Playback <select id="simulation-speed">${options.map((o) => `<option value="${o.value}" ${state.speed === o.value ? 'selected' : ''}>${o.label}</option>`).join('')}</select></label>
      <label class="checkbox-row"><input id="auto-verification" type="checkbox" ${localStorage.getItem('sos.autoPrompt') !== 'false' ? 'checked' : ''}> Open test verification on model anomaly</label></div>
      ${selected === 'custom' ? `<div class="spacer"></div>${customFields()}` : ''}
    </section>
    <div class="spacer"></div><div class="grid two"><section class="card"><div class="section-title"><div><h2>Current sensor values</h2><p>Last sample · simulated timestamps advance at 50 Hz</p></div><span class="code-badge">${state.sampleIndex} samples</span></div>
      <div class="value-grid">${[['ax','ACC X','m/s²'],['ay','ACC Y','m/s²'],['az','ACC Z','m/s²'],['gx','GYRO X','rad/s'],['gy','GYRO Y','rad/s'],['gz','GYRO Z','rad/s'],['accMagnitude','ACC MAG','m/s²'],['gyroMagnitude','ROTATION MAG','rad/s']].map(([key,label,unit]) => `<div class="value-cell"><span>${label}</span><strong data-value="${key}">—</strong><small>${unit}</small></div>`).join('')}</div>
      <p class="small-copy">The 50 Hz 128-sample window uses the same overlapping window size and 20 model input features as the Flutter service. Browser playback speed changes wall-clock pacing only.</p>
    </section><section class="card"><div class="section-title"><div><h2>Inference status</h2><p>Existing serialized Random Forest · no random prediction fallback</p></div><span class="status-badge ${ml.ready ? 'green' : 'red'}"><span class="dot"></span>${ml.ready ? 'MODEL LOADED' : 'MODEL UNAVAILABLE'}</span></div>
      <div class="source-row"><span class="source-icon">◈</span><div class="source-copy"><strong data-prediction>Awaiting a full sensor window</strong><small data-method>30-tree Random Forest · bundle ${esc(ml.version || 'unavailable')}</small><small data-conf>Confidence: —</small></div></div>
      <div class="source-row"><span class="source-icon">◷</span><div class="source-copy"><strong>Inference duration</strong><small data-latency>Measured per API prediction: —</small></div></div>
      <div class="source-row"><span class="source-icon">⌁</span><div class="source-copy"><strong>Event state</strong><small data-event-state>${state.latestPrediction ? esc(pretty(state.latestPrediction.predictedCategory)) : 'Waiting for 128 samples'}</small></div></div>
      <div class="notice-box">Inference confidence is from the model's class probability for this simulated window. It is not a calibrated real-world emergency probability.</div>
    </section>
    ${metricCard('Acceleration axes', 'm/s² · live window', lineChart(state.samples.slice(-150), ['ax','ay','az'], ['X','Y','Z'], ['', 'blue', 'amber']), '<div class="legend"><span><i></i>X</span><span><i class="blue"></i>Y</span><span><i class="amber"></i>Z</span></div>')}
    <div class="spacer"></div><div class="grid two">${metricCard('Gyroscope axes', 'rad/s · live window', lineChart(state.samples.slice(-150), ['gx','gy','gz'], ['X','Y','Z'], ['purple', '', 'amber']), '<div class="legend"><span><i style="background:#9b76b6"></i>X</span><span><i></i>Y</span><span><i class="amber"></i>Z</span></div>')}${metricCard('Magnitude', 'Acceleration / rotation', lineChart(state.samples.slice(-150), ['accMagnitude','gyroMagnitude'], ['Acceleration magnitude','Rotation magnitude'], ['', 'blue']), '<div class="legend"><span><i></i>Acceleration</span><span><i class="blue"></i>Rotation</span></div>')}</div>
    <div class="spacer"></div><section class="card"><div class="section-title"><div><h2>Recent sample table</h2><p>Latest 10 simulated samples · not persisted</p></div><span class="badge-sim">TEST STREAM</span></div>${sampleTable()}</section>`;
}

function customFields() {
  return `<div class="form-grid custom-grid">${[['ax','Accel X',0,-156.9,156.9],['ay','Accel Y',0,-156.9,156.9],['az','Accel Z',9.80665,-156.9,156.9],['gx','Gyro X',0,-35,35],['gy','Gyro Y',0,-35,35],['gz','Gyro Z',0,-35,35]].map(([key,label,value,min,max]) => `<div class="field"><label for="custom-${key}">${label}</label><input type="number" id="custom-${key}" value="${value}" min="${min}" max="${max}" step="0.1"></div>`).join('')}</div><p class="small-copy">Axis limits shown above are bounded to common phone sensor ranges (acceleration ±16 g, angular velocity ±35 rad/s).</p>`;
}

function sampleTable() {
  const rows = state.samples.slice(-10).reverse();
  if (!rows.length) return emptyState('No samples yet', 'Start a preset to generate an inspectable test stream.', '⌁');
  return `<div class="table-scroll"><table class="data-table"><thead><tr><th>Simulated time</th><th>Ax</th><th>Ay</th><th>Az</th><th>Gx</th><th>Gy</th><th>Gz</th></tr></thead><tbody>${rows.map((s) => `<tr><td class="mono">${new Date(s.timestamp).toLocaleTimeString()}</td>${['ax','ay','az','gx','gy','gz'].map((k) => `<td class="mono">${num(s[k], 3)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;
}

function paintTelemetry() {
  const sample = state.samples.at(-1);
  if (sample) {
    const values = { ...sample, accMagnitude: Math.hypot(sample.ax, sample.ay, sample.az), gyroMagnitude: Math.hypot(sample.gx, sample.gy, sample.gz) };
    for (const [key, value] of Object.entries(values)) {
      const target = content.querySelector(`[data-value="${key}"]`);
      if (target && typeof value === 'number') target.textContent = num(value, 3);
    }
  }
  const freshCharts = content.querySelectorAll('.signal-svg');
  if (freshCharts.length >= 3) {
    const slices = state.samples.slice(-150);
    const sets = [
      lineChart(slices,['ax','ay','az'],['X','Y','Z'],['','blue','amber']),
      lineChart(slices,['gx','gy','gz'],['X','Y','Z'],['purple','','amber']),
      lineChart(slices,['accMagnitude','gyroMagnitude'],['acc','gyro'],['','blue']),
    ];
    freshCharts.forEach((chart, i) => { const wrapper = document.createElement('div'); wrapper.innerHTML = sets[i]; chart.replaceWith(wrapper.firstElementChild); });
  }
  const table = content.querySelector('section.card:last-child');
  if (table) table.innerHTML = `<div class="section-title"><div><h2>Recent sample table</h2><p>Latest 10 simulated samples · not persisted</p></div><span class="badge-sim">TEST STREAM</span></div>${sampleTable()}`;
  if (state.latestPrediction) updatePredictionUI(state.latestPrediction);
}

function updatePredictionUI(prediction) {
  const category = content.querySelector('[data-prediction]');
  if (!category) return;
  category.textContent = `Potential ${pretty(prediction.predictedCategory)} · simulated input`;
  const method = content.querySelector('[data-method]');
  if (method) method.textContent = `${prediction.modelName} v${prediction.modelVersion} · ${prediction.nEstimators} trees · 20 features`;
  const conf = content.querySelector('[data-conf]');
  if (conf) conf.textContent = `Model class probability: ${(prediction.confidence * 100).toFixed(1)}% · test input only`;
  const latency = content.querySelector('[data-latency]');
  if (latency) latency.textContent = `Measured inference: ${prediction.inferenceMs} ms`;
  const event = content.querySelector('[data-event-state]');
  if (event) event.textContent = prediction.predictedCategory === 'normal' ? 'Normal activity classification from simulated input' : `Potential anomaly from simulated sensor input (${pretty(prediction.predictedCategory)})`;
}

async function renderEmergency() {
  const incidents = await api('/api/simulation/incidents');
  const journey = await api('/api/simulation/journey');
  state.incidents = incidents.records;
  state.journey = journey.journey;
  return `${heading('Emergency simulation', 'Test the detection-to-verification workflow without touching the real emergency dispatch path.', '<span class="sim-banner">SIMULATION MODE · LOCKED</span>')}
    <div class="data-note"><span>!</span><div><strong>External dispatch is unreachable.</strong> The local server accepts only requests with <code>isSimulation: true</code>. It has no SMS/email/FCM client or Firebase incident write in this path.</div></div>
    <div class="grid two"><section class="card"><div class="section-title"><div><h2>Manual SOS test</h2><p>Opens the same response timer UI without calling Firebase.</p></div><span class="status-badge amber"><span class="dot"></span>LOCAL ONLY</span></div>
      <label class="range-control">Verification countdown <input id="countdown-seconds" type="range" min="5" max="45" step="5" value="${state.countdownSec}"><strong id="countdown-label">${state.countdownSec}s</strong></label><div class="spacer"></div>
      <button class="button danger" data-action="manual-sos">✳ Start manual SOS simulation</button>
      <p class="small-copy">Choose Confirm, Cancel, or let the timer expire. Every outcome is written to the local simulation history with isSimulation=true.</p>
    </section><section class="card"><div class="section-title"><div><h2>Automated scenario test</h2><p>Run the actual exported model on generated 128-sample windows.</p></div><span class="status-badge ${state.latestPrediction ? 'green' : ''}"><span class="dot"></span>${state.latestPrediction ? esc(pretty(state.latestPrediction.predictedCategory)) : 'Awaiting inference'}</span></div>
      <div class="control-row"><select id="emergency-scenario" class="search-input">${SCENARIOS.map((s) => `<option value="${s.id}" ${s.id === 'fall' ? 'selected' : ''}>${esc(s.label)}</option>`).join('')}</select><button class="button primary" data-action="run-emergency-scenario">Run scenario</button></div>
      <p class="small-copy">Sensor input must produce a model label other than normal before an automatic verification dialog opens. A model label remains a test classification, not evidence of an actual fall or crash.</p>
    </section>
    <section class="card"><div class="section-title"><div><h2>Local mock notification preview</h2><p>Preview only · nothing is transmitted</p></div><span class="status-badge amber"><span class="dot"></span>NOT SENT</span></div>
      <div class="notice-box">A confirmed simulation shows a mock notice in the history. Firebase Cloud Messaging, SMS, email and phone calls are not connected to this web application.</div>
      <div class="spacer"></div><div class="small-copy">Local contacts: ${getContacts().length ? getContacts().map((c) => esc(c.name)).join(', ') : 'none configured'}. Names stay in browser storage and are never included in API calls.</div>
    </section>
    <section class="card"><div class="section-title"><div><h2>Verification flow</h2><p>Explicit confirmation or cancellation is required</p></div></div><div class="journey-timeline"><div class="journey-step">Simulated sensor window classified by model<small>Same exported Random Forest and feature scaler</small></div><div class="journey-step">Potential anomaly prompt<small>Configurable 5–45 second timer</small></div><div class="journey-step">Confirm / Cancel / No response<small>Each outcome creates a SIMULATED history record</small></div><div class="journey-step">Notification preview only<small>No external service call exists in local simulation</small></div></div></section>
    <section class="card full"><div class="section-title"><div><h2>Recent simulation outcomes</h2><p>${incidents.records.length} test-only events in this server session</p></div><button class="button secondary small" data-action="reset-simulation">Reset simulation records</button></div>${incidents.records.length ? incidentTable(incidents.records.slice(0,6)) : emptyState('No emergency tests run', 'A test stays separate from mobile and Firebase records.', '✳')}</section></div>`;
}

async function renderJourney() {
  const data = await api('/api/simulation/journey');
  state.journey = data.journey;
  const journey = data.journey;
  return `${heading('Journey simulator', 'Exercise the existing timed check-in concept locally. Browser location is not read or stored.', '<span class="sim-banner">SIMULATED JOURNEY</span>')}
    <div class="data-note"><span>ⓘ</span><div>This tests check-in timing only. It has no route geometry, GPS, live contact, or map tracking. A missed check-in creates a SIMULATED history item and no notification is sent.</div></div>
    <div class="grid two"><section class="card"><div class="section-title"><div><h2>${journey?.active ? esc(journey.label) : 'Start a laptop journey'}</h2><p>${journey?.active ? 'All state exists in this local Node server session.' : 'Create a test timer and interact with check-ins.'}</p></div><span class="status-badge ${journey?.active ? 'green' : ''}"><span class="dot"></span>${journey?.active ? 'ACTIVE TEST' : 'STOPPED'}</span></div>
      ${journey?.active ? `<div class="callout-stat"><strong>${esc(when(journey.dueAt))}</strong><span>simulated check-in due time</span></div><div class="metric-bar-list"><div class="metric-bar"><span>Check-ins</span><div class="progress-track"><div class="progress-fill" style="width:${Math.min(100,journey.checkins*20)}%"></div></div><b>${journey.checkins}</b></div></div>
        <div class="control-row"><button class="button primary" data-action="journey-checkin">✓ Confirm check-in</button><button class="button secondary" data-action="journey-finish">End journey</button><button class="button danger" data-action="journey-missed">Simulate missed check-in</button></div>`
      : `<form id="journey-form"><div class="form-grid"><div class="field"><label for="journey-label">Journey label</label><input id="journey-label" maxlength="80" value="Laptop check-in test"></div><div class="field"><label for="journey-duration">Expected duration (minutes)</label><input id="journey-duration" type="number" min="1" max="480" value="15" required></div></div><div class="spacer"></div><button class="button primary" type="submit">▶ Start local journey</button></form>`}
    </section><section class="card"><div class="section-title"><div><h2>Journey activity</h2><p>Test timeline · no phone GPS or route planning</p></div></div>${journey ? `<div class="journey-timeline"><div class="journey-step">${esc(journey.label)}<small>Started ${esc(when(journey.startedAt))}</small></div>${journey.lastCheckinAt ? `<div class="journey-step">Check-in confirmed<small>${esc(when(journey.lastCheckinAt))} · total check-ins ${journey.checkins}</small></div>` : ''}${journey.active ? '<div class="journey-step">Timer active<small>Use Confirm, End, or Simulate missed check-in to complete this test.</small></div>' : `<div class="journey-step">${esc(pretty(journey.status))}<small>${esc(when(journey.finishedAt))} · simulation only</small></div>`}</div>` : emptyState('No journey started', 'This page exercises only the timer and check-in state machine.', '↗')}</section>
    <section class="card full"><div class="section-title"><div><h2>Privacy & integration status</h2><p>Behavior intentionally kept local for this laptop demo</p></div></div><div class="grid three"><div><span class="eyebrow">GPS</span><p class="small-copy">Not requested by the web demo. No browser geolocation call is made.</p></div><div><span class="eyebrow">CONTACTS</span><p class="small-copy">Local labels only; missed tests cannot send messages.</p></div><div><span class="eyebrow">ROUTE CONTEXT</span><p class="small-copy">Not available: existing mobile check-in has no route provider or route geometry integration.</p></div></div></section></div>`;
}

function getContacts() {
  try { return JSON.parse(localStorage.getItem('sos.contacts') || '[]'); } catch (_) { return []; }
}
function getProfile() {
  try { return JSON.parse(localStorage.getItem('sos.profile') || '{"name":""}'); } catch (_) { return { name: '' }; }
}

async function renderIncidents() {
  const [tests, real] = await Promise.all([api('/api/simulation/incidents'), api('/api/history/real')]);
  state.incidents = tests.records;
  const realNotice = real.connected ? '' : `<div class="data-note"><span>ⓘ</span><div>Real incident history is unavailable because Firebase web configuration and user authentication are not set up. The table below contains simulation-only records.</div></div>`;
  return `${heading('Incident history', 'Test events are local, temporary and clearly distinguished from real user incidents.', '<button class="button secondary" data-action="reset-simulation">↺ Clear local simulation</button>')}${realNotice}
    <section class="card"><div class="section-title"><div><h2>Simulation history</h2><p>Stored in memory for this Node server session; restarted server clears it.</p></div><div class="filter-row"><select class="search-input" id="incident-filter"><option value="all">All outcomes</option><option value="confirmed">Confirmed test</option><option value="cancelled">Cancelled</option><option value="timeout">No response</option></select><input class="search-input" id="incident-search" placeholder="Search type or test ID…"></div></div>
      <div id="incident-list">${tests.records.length ? incidentTable(tests.records) : emptyState('No local test incidents', 'Start a sensor scenario or open Emergency test. Real incidents are not connected to this browser.', '☷')}</div>
    </section><div class="spacer"></div><div class="notice-box">SIMULATED records use SIM- IDs and cannot be passed to Firebase or emergency dispatch. They are not durable across server restarts.</div>`;
}

function incidentTable(records) {
  return `<div class="table-scroll"><table class="data-table"><thead><tr><th>Reference</th><th>Event</th><th>Outcome</th><th>Method</th><th>Time</th><th>Dispatch</th></tr></thead><tbody>${records.map((r) => `<tr data-search="${esc(`${r.id} ${r.eventType} ${r.outcome}`.toLowerCase())}" data-outcome="${esc(r.outcome)}"><td class="mono"><span class="badge-sim">SIM</span> ${esc(r.id)}</td><td>${esc(pretty(r.eventType))}</td><td>${esc(pretty(r.outcome))}</td><td>${esc(pretty(r.detectionMethod))}</td><td>${esc(when(r.createdAt))}</td><td>${r.mockNotice ? 'Mock preview only' : 'Suppressed'}</td></tr>`).join('')}</tbody></table></div>`;
}

function filterIncidentRows() {
  const search = content.querySelector('#incident-search')?.value.toLowerCase() || '';
  const outcome = content.querySelector('#incident-filter')?.value || 'all';
  content.querySelectorAll('#incident-list tbody tr').forEach((row) => {
    row.hidden = !(row.dataset.search.includes(search) && (outcome === 'all' || row.dataset.outcome === outcome));
  });
}

async function renderContacts() {
  const contacts = getContacts();
  const profile = getProfile();
  return `${heading('Profile & contacts', 'Browser-local demo profile and test contacts. No SOS account or contact channel is connected.', '<span class="status-badge amber"><span class="dot"></span>LOCAL STORAGE ONLY</span>')}
    <div class="data-note"><span>▣</span><div>Values entered here stay in this browser's local storage and are not sent to the server. Simulation notifications are previews only. Do not treat this as the mobile app's authenticated contact list.</div></div>
    <div class="grid two"><section class="card"><div class="section-title"><div><h2>Demo profile</h2><p>Display label for this browser workspace</p></div></div><form id="profile-form"><div class="field"><label for="profile-name">Display name</label><input id="profile-name" maxlength="60" value="${esc(profile.name || '')}" placeholder="Local user"></div><div class="spacer"></div><button class="button primary" type="submit">Save browser profile</button></form></section>
    <section class="card"><div class="section-title"><div><h2>Add a test contact</h2><p>Name and relationship only · no phone or email captured</p></div></div><form id="contact-form"><div class="form-grid"><div class="field"><label for="contact-name">Name / test label</label><input id="contact-name" maxlength="60" required placeholder="e.g. Test contact"></div><div class="field"><label for="contact-relationship">Relationship</label><input id="contact-relationship" maxlength="40" placeholder="Family, friend…"></div><div class="field"><label for="contact-priority">Notification tier (preview only)</label><select id="contact-priority"><option value="primary">Primary</option><option value="secondary">Secondary</option></select></div></div><div class="spacer"></div><button class="button primary" type="submit">Add local contact</button></form></section>
    <section class="card full"><div class="section-title"><div><h2>Local test contacts</h2><p>${contacts.length} saved in this browser · no external delivery</p></div></div>${contacts.length ? contacts.map((c) => `<div class="contact-item"><span class="contact-avatar">${esc((c.name || '?').slice(0,1).toUpperCase())}</span><div class="contact-info"><strong>${esc(c.name)}</strong><span>${esc(c.relationship || 'Contact')} · ${esc(pretty(c.priority))} tier · local preview only</span></div><button class="button-icon" data-action="remove-contact" data-id="${esc(c.id)}" aria-label="Remove contact">×</button></div>`).join('') : emptyState('No local test contacts', 'You can add a label for the notification preview. Phone and email details are intentionally not collected here.', '♧')}</section></div>`;
}

async function renderModel() {
  const info = await api('/api/ml/status');
  const rows = info.evaluation || [];
  const features = info.featureColumns || [];
  return `${heading('Model & data', 'The laptop uses the same serialized Random Forest exported for Flutter, with matching features and scaler.', `<span class="status-badge ${info.ready ? 'green' : 'red'}"><span class="dot"></span>${info.ready ? 'BUNDLE LOADED' : 'BUNDLE MISSING'}</span>`)}
    <div class="data-note"><span>ⓘ</span><div><strong>Validation boundary.</strong> The model was evaluated on a project dataset containing real HAR activity windows and controlled synthetic anomaly windows. It was not validated on live accident or fall data. A model class is a prompt to verify, not a diagnosis or guaranteed emergency detection.</div></div>
    <div class="grid metrics">${metric('MODEL', esc(info.modelName || 'Unavailable'), `Version ${esc(info.version || '—')}`, '◈')}${metric('TREES', info.nEstimators || '—', 'Portable exported decision trees', '⌘', '#527fb5', '#eaf1f8')}${metric('MODEL INPUTS', features.length || '—', 'Computed over a 2.56-second window', '⌁', '#a17bb5', '#f3eef8')}${metric('CLASSES', (info.classes || []).length || '—', (info.classes || []).map(pretty).join(' · '), '▥', '#bd872f', '#fbf3e6')}</div>
    <div class="grid two"><section class="card"><div class="section-title"><div><h2>Model benchmark</h2><p>Reported held-out synthetic-event benchmark and real HAR activity result</p></div></div>${barChart(rows, 'macro_f1', 'model_name', { max: 1, percent: true })}<p class="small-copy">Figures are reloaded from the tracked report. No new field measurements are implied.</p></section>
      <section class="card"><div class="section-title"><div><h2>Input feature schema</h2><p>${features.length} model features in training order</p></div><span class="code-badge">50 Hz · 128 samples</span></div><div class="filter-row">${features.map((feature) => `<span class="code-badge">${esc(feature)}</span>`).join('')}</div><div class="spacer"></div><p class="small-copy">The browser engine ports the Flutter service's magnitude, variance, energy, jerk, free-fall, gravity-subtracted body motion, orientation, peak-tail quiet, and duration calculations. Node traverses the same exported tree arrays and scaler values.</p></section>
      <section class="card"><div class="section-title"><div><h2>Live local inference</h2><p>Classification from the latest simulated 128-sample window</p></div></div>${state.latestPrediction ? `<div class="callout-stat"><strong>${esc(pretty(state.latestPrediction.predictedCategory))}</strong><span>Potential label from test input</span></div><p>Class probability ${(state.latestPrediction.confidence * 100).toFixed(1)}% · ${state.latestPrediction.inferenceMs} ms measured · ${esc(state.latestPrediction.detectionMethod)}</p>` : emptyState('No inference run yet', 'Start the sensor lab and wait for 128 samples.')}<button class="button secondary small" data-page="sensor">Open sensor lab →</button></section>
      <section class="card"><div class="section-title"><div><h2>Training data provenance</h2><p>Actual dataset counts in the quality report</p></div></div><div class="metric-bar-list"><div class="metric-bar"><span>Normal HAR windows</span><div class="progress-track"><div class="progress-fill blue" style="width:100%"></div></div><b>10,299</b></div><div class="metric-bar"><span>Controlled anomalies</span><div class="progress-track"><div class="progress-fill amber" style="width:12%"></div></div><b>1,200</b></div><div class="metric-bar"><span>Real accident records</span><div class="progress-track"><div class="progress-fill" style="width:0%"></div></div><b>None</b></div></div><p class="small-copy">Real HAR data has everyday motion labels. The fall/crash-like labels in this pipeline come from controlled simulated sensor windows.</p></section>
    </div>`;
}

async function renderDiagnostics() {
  const [diag, health, sensor, safety] = await Promise.all([api('/api/diagnostics'), api('/api/health'), api('/api/simulation/sensors'), api('/api/safety/refresh-status')]);
  const rows = [
    ['Local Node service', 'online', health.ok, 'localhost browser API'],
    ['Portable Random Forest', diag.modelLoaded ? 'loaded' : 'unavailable', diag.modelLoaded, 'Actual exported JSON bundle'],
    ['Firebase project', diag.firebaseProjectConfigured ? 'configured, not connected' : 'not configured', false, 'Local simulation does not call Firebase'],
    ['External dispatch', 'blocked in simulator', true, 'No SMS/email/FCM client in web routes'],
    ['Safety source files', pretty(diag.safetyData), diag.safetyData === 'available', 'Source aggregates unavailable until downloaded and validated'],
    ['Sensor simulator', state.running ? 'running' : sensor.state, state.running, 'Browser-generated test data only'],
    ['Active journey', state.journey?.active ? 'running' : 'none', Boolean(state.journey?.active), 'In-memory simulation'],
  ];
  return `${heading('Testing & diagnostics', 'Read-only local service checks and data-source refresh state.', '<button class="button secondary" data-action="diagnostics-refresh">↻ Run checks</button>')}
    <div class="grid two"><section class="card"><div class="section-title"><div><h2>Runtime status</h2><p>Last checked ${esc(new Date().toLocaleTimeString())}</p></div></div><div class="table-scroll"><table class="data-table"><thead><tr><th>Component</th><th>Status</th><th>Details</th></tr></thead><tbody>${rows.map(([name,status,ok,details]) => `<tr><td>${esc(name)}</td><td><span class="status-badge ${ok ? 'green' : 'amber'}"><span class="dot"></span>${esc(pretty(status))}</span></td><td>${esc(details)}</td></tr>`).join('')}</tbody></table></div><p class="small-copy">Browser tests and simulation records run only on this laptop. Real Firestore, SMS, email and FCM are not connected.</p></section>
    <section class="card"><div class="section-title"><div><h2>Dataset refresh status</h2><p>Registry timestamps reflect actual processing attempts</p></div></div>${safety.map((r) => `<div class="source-row"><span class="source-icon">▦</span><div class="source-copy"><strong>${esc(r.id)}</strong><small>${esc(pretty(r.status))} · checked ${esc(when(r.lastCheckedAt))} · downloaded ${esc(when(r.lastDownloadedAt))} · processed ${esc(when(r.lastSuccessfulUpdateAt))}</small></div></div>`).join('')}</section>
    <section class="card full"><div class="section-title"><div><h2>Portable tests</h2><p>Repeat these from the repository root after changes</p></div><span class="badge-sim">SIMULATION-SAFE</span></div><div class="table-scroll"><table class="data-table"><thead><tr><th>Command</th><th>Purpose</th><th>Required tooling</th></tr></thead><tbody><tr><td class="mono">npm test</td><td>Web API, model parity, scenarios and simulation safety</td><td>Node 18+</td></tr><tr><td class="mono">npm run test:backend</td><td>Firebase Functions unit tests</td><td>Node 20+</td></tr><tr><td class="mono">.venv\Scripts\python.exe -m pytest tests -q</td><td>Python data, ML and pipeline suite</td><td>Existing Python virtualenv</td></tr><tr><td class="mono">flutter test</td><td>Flutter unit/widget regression checks</td><td>Flutter + Android SDK</td></tr></tbody></table></div></section></div>`;
}

function customSensorInput() {
  const input = (key, fallback) => Number(content.querySelector(`#custom-${key}`)?.value ?? fallback);
  return { ax: input('ax', 0), ay: input('ay', 0), az: input('az', 9.80665), gx: input('gx', 0), gy: input('gy', 0), gz: input('gz', 0) };
}

async function startSensor(scenario = state.scenario) {
  if (!SCENARIOS.some((item) => item.id === scenario)) throw new Error('Unknown sensor scenario.');
  if (scenario === 'custom') {
    const values = customSensorInput();
    if (Object.entries(values).some(([axis, value]) => !Number.isFinite(value) || Math.abs(value) > (['ax', 'ay', 'az'].includes(axis) ? 156.9 : 35))) {
      toast('Custom inputs are outside the accepted sensor ranges.');
      return;
    }
    state.customValues = values;
  }
  clearInterval(state.timer);
  state.scenario = scenario;
  state.sampleIndex = 0;
  state.samples = [];
  state.window = [];
  state.lastInferenceIndex = 0;
  state.latestPrediction = null;
  state.predictionBusy = false;
  state.alertLatched = false;
  state.running = true;
  state.paused = false;
  state.startedAtMs = Date.now();
  await api('/api/simulation/sensors', { method: 'POST', body: JSON.stringify({ action: 'start', scenario }) });
  clearInterval(state.chartTimer);
  state.timer = setInterval(tickSensor, Math.max(4, Math.round(20 / state.speed)));
  state.chartTimer = setInterval(() => { if (state.page === 'sensor') paintTelemetry(); }, 120);
  if (state.page !== 'sensor') state.page = 'sensor';
  await render();
  toast(`${pretty(scenario)} simulation started. Data is labelled as simulated.`);
}

function tickSensor() {
  if (!state.running || state.paused) return;
  const index = state.sampleIndex;
  const values = sampleScenario(state.scenario, index, state.customValues || {});
  const sample = { ...values, timestamp: new Date(state.startedAtMs + index * 20).toISOString() };
  sample.accMagnitude = Math.hypot(sample.ax, sample.ay, sample.az);
  sample.gyroMagnitude = Math.hypot(sample.gx, sample.gy, sample.gz);
  state.sampleIndex += 1;
  state.samples.push(sample);
  if (state.samples.length > 350) state.samples.shift();
  state.window.push(sample);
  if (state.window.length > 128) state.window.shift();
  if (state.window.length === 128 && (state.sampleIndex - 128) % 64 === 0 && !state.predictionBusy) {
    state.predictionBusy = true;
    void predictWindow(state.window.slice());
  }
}

async function predictWindow(windowSamples) {
  try {
    const prediction = await api('/api/ml/predict', {
      method: 'POST',
      body: JSON.stringify({ isSimulation: true, samples: windowSamples, sensitivity: 'medium' }),
    });
    state.latestPrediction = prediction;
    state.predictions += 1;
    if (prediction.predictedCategory !== 'normal') state.anomalies += 1;
    const auto = localStorage.getItem('sos.autoPrompt') !== 'false';
    if (prediction.predictedCategory === 'normal') state.alertLatched = false;
    else if (auto && !state.alertLatched && !state.emergency) {
      state.alertLatched = true;
      openVerification({
        eventType: prediction.predictedCategory,
        confidence: prediction.confidence,
        detectionMethod: prediction.detectionMethod,
        triggerSource: 'sensor',
      });
    }
    if (state.page === 'sensor') updatePredictionUI(prediction);
  } catch (error) {
    state.latestPrediction = { predictedCategory: 'unavailable', inferenceMs: null, reason: error.message };
    if (state.page === 'sensor') {
      const node = content.querySelector('[data-prediction]');
      if (node) node.textContent = `Inference unavailable · ${error.message}`;
    }
  } finally {
    state.predictionBusy = false;
  }
}

async function pauseSensor() {
  clearInterval(state.timer);
  state.running = false;
  state.paused = true;
  await api('/api/simulation/sensors', { method: 'POST', body: JSON.stringify({ action: 'pause', scenario: state.scenario }) });
  await render();
  toast('Sensor stream paused.');
}

async function resumeSensor() {
  state.paused = false;
  state.running = true;
  await api('/api/simulation/sensors', { method: 'POST', body: JSON.stringify({ action: 'resume', scenario: state.scenario }) });
  state.timer = setInterval(tickSensor, Math.max(4, Math.round(20 / state.speed)));
  await render();
  toast('Sensor stream resumed.');
}

async function stopSensor() {
  clearInterval(state.timer);
  state.running = false;
  state.paused = false;
  await api('/api/simulation/sensors', { method: 'POST', body: JSON.stringify({ action: 'stop' }) });
  await render();
  toast('Sensor stream stopped. Existing samples remain visible until reset.');
}

async function resetSensor() {
  clearInterval(state.timer);
  state.running = false;
  state.paused = false;
  state.sampleIndex = 0;
  state.samples = [];
  state.window = [];
  state.latestPrediction = null;
  state.predictionBusy = false;
  state.predictions = 0;
  state.anomalies = 0;
  state.alertLatched = false;
  await api('/api/simulation/sensors', { method: 'POST', body: JSON.stringify({ action: 'reset' }) });
  await render();
  toast('Sensor simulation reset. No history was written.');
}

function openVerification({ eventType, confidence = null, detectionMethod = 'manual_simulation', triggerSource = 'manual' }) {
  if (state.emergency) return;
  state.emergency = { eventType, confidence, detectionMethod, triggerSource };
  let remaining = state.countdownSec;
  document.querySelector('#verification-title').textContent = eventType === 'manual_sos' ? 'Manual SOS test' : `Potential ${pretty(eventType)} label`;
  document.querySelector('#verification-description').textContent = triggerSource === 'manual'
    ? 'Manual SOS simulation started. This is not a real emergency and no contact will be notified.'
    : 'Potential anomaly detected from simulated sensor input. Please choose a test response.';
  document.querySelector('#countdown-value').textContent = remaining;
  if (!dialog.open) dialog.showModal();
  clearInterval(state.countdownTimer);
  state.countdownTimer = setInterval(() => {
    remaining -= 1;
    document.querySelector('#countdown-value').textContent = Math.max(0, remaining);
    if (remaining <= 0) void finishVerification('timeout');
  }, 1000);
}

async function finishVerification(outcome) {
  if (!state.emergency) return;
  clearInterval(state.countdownTimer);
  const incidentData = { ...state.emergency, isSimulation: true, outcome };
  state.emergency = null;
  if (dialog.open) dialog.close();
  try {
    const result = await api('/api/simulation/incidents', { method: 'POST', body: JSON.stringify(incidentData) });
    state.incidents.unshift(result.incident);
    toast(outcome === 'confirmed' ? 'Simulated SOS confirmed. Mock notice only; no message was sent.' : outcome === 'cancelled' ? 'Test alert cancelled and recorded locally.' : 'No response recorded as a simulation timeout.');
    if (state.page === 'incidents' || state.page === 'emergency' || state.page === 'overview') await render();
  } catch (error) { toast(`Could not record the local simulation: ${error.message}`); }
}

async function resetSimulation() {
  clearInterval(state.countdownTimer);
  state.emergency = null;
  if (dialog.open) dialog.close();
  await api('/api/simulation/reset', { method: 'POST', body: '{}' });
  state.incidents = [];
  state.journey = null;
  await render();
  toast('Local simulation history and journey state cleared.');
}

async function submitJourney(action, extra = {}) {
  const result = await api('/api/simulation/journey', { method: 'POST', body: JSON.stringify({ action, ...extra }) });
  state.journey = result.journey;
  if (action === 'missed') toast('Missed check-in simulated; no contacts were notified.');
  else toast(action === 'start' ? 'Local journey simulation started.' : action === 'checkin' ? 'Check-in recorded locally.' : 'Local journey test ended.');
  await render();
}

function saveProfile(event) {
  event.preventDefault();
  const name = content.querySelector('#profile-name').value.trim().slice(0, 60);
  localStorage.setItem('sos.profile', JSON.stringify({ name }));
  document.querySelector('#side-user-name').textContent = name || 'Local user';
  document.querySelector('#top-avatar').textContent = (name || 'S').slice(0, 1).toUpperCase();
  toast('Browser-local profile saved.');
}

function addContact(event) {
  event.preventDefault();
  const name = content.querySelector('#contact-name').value.trim().slice(0, 60);
  const relationship = content.querySelector('#contact-relationship').value.trim().slice(0, 40);
  const priority = content.querySelector('#contact-priority').value;
  if (!name) return toast('Add a contact label first.');
  const contacts = getContacts();
  contacts.push({ id: crypto.randomUUID(), name, relationship, priority });
  localStorage.setItem('sos.contacts', JSON.stringify(contacts));
  void render().then(() => toast('Local test contact saved. It cannot receive an alert.'));
}

function removeContact(id) {
  localStorage.setItem('sos.contacts', JSON.stringify(getContacts().filter((c) => c.id !== id)));
  void render().then(() => toast('Local contact removed.'));
}

async function runAction(action, button) {
  switch (action) {
    case 'start-sensor': return startSensor(state.scenario);
    case 'pause-sensor': return pauseSensor();
    case 'resume-sensor': return resumeSensor();
    case 'stop-sensor': return stopSensor();
    case 'reset-sensor': return resetSensor();
    case 'scenario': {
      const scenario = button.dataset.scenario;
      state.scenario = scenario;
      if (scenario === 'custom') { state.page = 'sensor'; await render(); toast('Enter the six custom axes, then press Start / restart.'); return; }
      return startSensor(scenario);
    }
    case 'manual-sos': return openVerification({ eventType: 'manual_sos', triggerSource: 'manual' });
    case 'run-emergency-scenario': {
      const scenario = content.querySelector('#emergency-scenario').value;
      return startSensor(scenario);
    }
    case 'reset-simulation': return resetSimulation();
    case 'refresh-safety': await api('/api/safety/refresh-status'); return render().then(() => toast('Latest local source status loaded.'));
    case 'diagnostics-refresh': return render().then(() => toast('Local diagnostics refreshed.'));
    case 'journey-checkin': return submitJourney('checkin');
    case 'journey-finish': return submitJourney('finish');
    case 'journey-missed': return submitJourney('missed');
    case 'remove-contact': return removeContact(button.dataset.id);
    case 'retry-page': return render();
    default: return;
  }
}

document.querySelectorAll('.nav-item[data-page], [data-page].icon-button').forEach((button) => button.addEventListener('click', () => {
  state.page = button.dataset.page;
  document.querySelector('#sidebar').classList.remove('open');
  void render();
}));
document.querySelector('#mobile-menu').addEventListener('click', () => document.querySelector('#sidebar').classList.toggle('open'));
document.querySelector('#content').addEventListener('click', (event) => {
  const nav = event.target.closest('[data-page]');
  if (nav && !nav.classList.contains('nav-item')) { state.page = nav.dataset.page; void render(); return; }
  const button = event.target.closest('[data-action]');
  if (button) void runAction(button.dataset.action, button).catch((error) => toast(error.message));
});
document.querySelector('#content').addEventListener('submit', (event) => {
  if (event.target.id === 'profile-form') saveProfile(event);
  if (event.target.id === 'contact-form') addContact(event);
  if (event.target.id === 'journey-form') {
    event.preventDefault();
    const label = content.querySelector('#journey-label').value.trim();
    const durationMinutes = Number(content.querySelector('#journey-duration').value);
    void submitJourney('start', { label, durationMinutes }).catch((error) => toast(error.message));
  }
});
document.querySelector('#content').addEventListener('input', (event) => {
  if (event.target.id === 'incident-search' || event.target.id === 'incident-filter') filterIncidentRows();
  if (event.target.id === 'safety-search') {
    const query = event.target.value.toLowerCase();
    content.querySelectorAll('#crime-table tbody tr').forEach((row) => { row.hidden = !row.dataset.category.includes(query); });
  }
  if (event.target.id === 'countdown-seconds') {
    state.countdownSec = Number(event.target.value);
    const label = content.querySelector('#countdown-label');
    if (label) label.textContent = `${state.countdownSec}s`;
  }
  if (event.target.id === 'auto-verification') localStorage.setItem('sos.autoPrompt', String(event.target.checked));
});
document.querySelector('#content').addEventListener('change', (event) => {
  if (event.target.id === 'simulation-speed') {
    state.speed = Number(event.target.value);
    if (state.running && !state.paused) {
      clearInterval(state.timer);
      state.timer = setInterval(tickSensor, Math.max(4, Math.round(20 / state.speed)));
    }
    toast(`Playback set to ${state.speed}×. Simulated sample values are unchanged.`);
  }
});
document.querySelector('#cancel-emergency').addEventListener('click', () => void finishVerification('cancelled'));
document.querySelector('#confirm-emergency').addEventListener('click', () => void finishVerification('confirmed'));
dialog.addEventListener('cancel', (event) => { event.preventDefault(); void finishVerification('cancelled'); });

api('/api/health').then((health) => {
  document.querySelector('#connection-label').textContent = health.ok ? 'Local services online' : 'Local service unavailable';
}).catch(() => { document.querySelector('#connection-label').textContent = 'Local service unavailable'; });
const initialName = getProfile().name;
document.querySelector('#side-user-name').textContent = initialName || 'Local user';
document.querySelector('#top-avatar').textContent = (initialName || 'S').slice(0,1).toUpperCase();
void render();
