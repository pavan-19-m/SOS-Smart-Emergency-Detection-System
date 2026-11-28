import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { FEATURE_COLUMNS, extractFeatures, predictWithModel } from '../src/sensor-engine.mjs';
import { SCENARIOS, sampleScenario } from '../src/sensor-scenarios.mjs';

const model = JSON.parse(readFileSync(new URL('../../data_science/models/sosense_inference_bundle.json', import.meta.url), 'utf8'));

function parseTable(path) {
  const lines = readFileSync(new URL(path, import.meta.url), 'utf8').trim().split(/\r?\n/);
  const headers = lines.shift().split(',');
  return lines.map((line) => Object.fromEntries(line.split(',').map((value, index) => [headers[index], value])));
}

test('browser feature schema matches the shipped Flutter model input order', () => {
  assert.deepEqual(FEATURE_COLUMNS, model.feature_columns);
  assert.equal(model.version, '1.0.0');
  assert.equal(model.trees.length, 30);
});

test('JavaScript Random Forest traversal matches exported benchmark predictions', () => {
  const features = parseTable('../../data_science/datasets/testing/test_features.csv');
  const predictions = parseTable('../../analytics/exports/test_predictions.csv');
  const predictionsById = new Map(predictions.map((row) => [row.window_id, row]));
  let checked = 0;
  for (const row of features.slice(0, 100)) {
    const featureMap = Object.fromEntries(FEATURE_COLUMNS.map((column) => [column, Number(row[column])]));
    const expected = predictionsById.get(row.window_id);
    assert.ok(expected, `missing benchmark prediction for ${row.window_id}`);
    const actual = predictWithModel(featureMap, model);
    assert.equal(actual.predictedCategory, expected.random_forest_pred, row.window_id);
    assert.ok(Math.abs(actual.confidence - Number(expected.random_forest_conf)) < 0.00001, row.window_id);
    checked += 1;
  }
  assert.equal(checked, 100);
});

test('feature extractor accepts one 128-sample window and produces 20 finite inputs', () => {
  const window = Array.from({ length: 128 }, (_, index) => sampleScenario('walking', index));
  const features = extractFeatures(window);
  assert.equal(Object.keys(features).length, 20);
  for (const name of FEATURE_COLUMNS) assert.ok(Number.isFinite(features[name]), name);
  assert.ok(features.acc_mag_mean > 8 && features.acc_mag_mean < 13);
  assert.ok(features.inactivity_duration_sec >= 0 && features.inactivity_duration_sec <= 2.56);
  assert.throws(() => extractFeatures(window.slice(0, 127)), /128-sample/);
});

test('all simulator scenarios stay within bounded phone sensor input ranges', () => {
  for (const scenario of SCENARIOS) {
    for (let index = 0; index < 600; index += 1) {
      const sample = sampleScenario(scenario.id, index, { ax: 1, ay: 2, az: 9.8, gx: 0.3, gy: 0.2, gz: 0.1 });
      for (const axis of ['ax', 'ay', 'az']) assert.ok(Math.abs(sample[axis]) <= 156.9, `${scenario.id}.${axis}`);
      for (const axis of ['gx', 'gy', 'gz']) assert.ok(Math.abs(sample[axis]) <= 35, `${scenario.id}.${axis}`);
      for (const value of Object.values(sample)) assert.ok(Number.isFinite(value));
    }
  }
  assert.notDeepEqual(sampleScenario('random', 10), sampleScenario('random', 11));
});

test('feature extraction rejects non-finite and physically out-of-range axis values', () => {
  const window = Array.from({ length: 128 }, (_, index) => sampleScenario('stationary', index));
  window[0].ax = Number.NaN;
  assert.throws(() => extractFeatures(window), /Invalid sensor axis/);
  window[0].ax = 200;
  assert.throws(() => extractFeatures(window), /outside accepted device range/);
});
