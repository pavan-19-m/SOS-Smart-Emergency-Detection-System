/** 20-feature extraction and portable Random Forest traversal matching Flutter. */
export const FEATURE_COLUMNS = [
  'acc_mag_mean', 'acc_mag_max', 'acc_mag_min', 'acc_mag_std', 'acc_mag_var',
  'acc_sma', 'acc_energy', 'acc_jerk_max', 'acc_peak_count', 'free_fall_ratio',
  'gyro_mag_mean', 'gyro_mag_max', 'gyro_mag_std', 'gyro_energy',
  'orientation_change_deg', 'post_peak_inactivity_ratio', 'body_acc_mag_mean',
  'body_acc_mag_std', 'event_duration_sec', 'inactivity_duration_sec',
];

const magnitude = (x, y, z) => Math.sqrt(x * x + y * y + z * z);
const average = (xs) => xs.reduce((sum, value) => sum + value, 0) / xs.length;

export function extractFeatures(samples, fsHz = 50) {
  if (!Array.isArray(samples) || samples.length !== 128) {
    throw new Error('Expected one 128-sample (2.56 s at 50 Hz) sensor window.');
  }
  if (!Number.isFinite(fsHz) || fsHz <= 0) throw new Error('fsHz must be positive.');
  for (const sample of samples) {
    for (const axis of ['ax', 'ay', 'az', 'gx', 'gy', 'gz']) {
      if (!Number.isFinite(sample?.[axis])) throw new Error(`Invalid sensor axis ${axis}.`);
      if (Math.abs(sample[axis]) > (axis.startsWith('a') ? 156.9 : 35)) {
        throw new Error(`Sensor axis ${axis} is outside accepted device range.`);
      }
    }
  }

  const acc = samples.map((s) => magnitude(s.ax, s.ay, s.az));
  const gyro = samples.map((s) => magnitude(s.gx, s.gy, s.gz));
  const meanAcc = average(acc);
  const meanGyro = average(gyro);
  const accVar = average(acc.map((v) => (v - meanAcc) ** 2));
  const gyroVar = average(gyro.map((v) => (v - meanGyro) ** 2));
  const meanAxes = ['ax', 'ay', 'az'].map((axis) => average(samples.map((s) => s[axis])));
  const body = samples.map((s) => magnitude(s.ax - meanAxes[0], s.ay - meanAxes[1], s.az - meanAxes[2]));
  const bodyMean = average(body);
  const bodyStd = Math.sqrt(average(body.map((v) => (v - bodyMean) ** 2)));
  const peak = Math.max(...acc);
  const peakIdx = acc.indexOf(peak);
  const tailStart = Math.min(peakIdx + 6, samples.length - 1);
  let totalQuiet = 0;
  let tailQuiet = 0;
  let active = 0;
  for (let i = 0; i < samples.length; i += 1) {
    const quiet = body[i] < 1.2 && gyro[i] < 0.35;
    if (quiet) totalQuiet += 1;
    if (i >= tailStart && quiet) tailQuiet += 1;
    if (body[i] > 2.5 || gyro[i] > 1) active += 1;
  }
  const k = Math.min(16, samples.length);
  const start = ['ax', 'ay', 'az'].map((axis) => average(samples.slice(0, k).map((s) => s[axis])));
  const end = ['ax', 'ay', 'az'].map((axis) => average(samples.slice(-k).map((s) => s[axis])));
  const dot = start.reduce((sum, v, i) => sum + v * end[i], 0);
  const norms = magnitude(...start) * magnitude(...end) + 1e-8;
  const orient = Math.acos(Math.max(-1, Math.min(1, dot / norms))) * (180 / Math.PI);
  let jerkMax = 0;
  for (let i = 1; i < acc.length; i += 1) jerkMax = Math.max(jerkMax, Math.abs(acc[i] - acc[i - 1]) * fsHz);
  const n = samples.length;
  return {
    acc_mag_mean: meanAcc,
    acc_mag_max: peak,
    acc_mag_min: Math.min(...acc),
    acc_mag_std: Math.sqrt(accVar),
    acc_mag_var: accVar,
    acc_sma: average(samples.map((s) => Math.abs(s.ax - meanAxes[0]) + Math.abs(s.ay - meanAxes[1]) + Math.abs(s.az - meanAxes[2]))),
    acc_energy: average(acc.map((v) => v * v)),
    acc_jerk_max: jerkMax,
    acc_peak_count: acc.filter((v) => v > 17.65).length,
    free_fall_ratio: acc.filter((v) => v < 5.4).length / n,
    gyro_mag_mean: meanGyro,
    gyro_mag_max: Math.max(...gyro),
    gyro_mag_std: Math.sqrt(gyroVar),
    gyro_energy: average(gyro.map((v) => v * v)),
    orientation_change_deg: orient,
    post_peak_inactivity_ratio: tailQuiet / Math.max(1, n - tailStart),
    body_acc_mag_mean: bodyMean,
    body_acc_mag_std: bodyStd,
    event_duration_sec: active / fsHz,
    inactivity_duration_sec: totalQuiet / fsHz,
  };
}

export function predictWithModel(features, model, sensitivity = 'medium') {
  if (!model || model.model_type !== 'RandomForestClassifier' || !Array.isArray(model.trees) || !model.trees.length) {
    throw new Error('The exported Random Forest model bundle is missing or invalid.');
  }
  if (model.feature_columns.length !== model.scaler_mean.length || model.feature_columns.length !== model.scaler_scale.length) {
    throw new Error('Model scaler metadata does not match its feature list.');
  }
  const scaled = model.feature_columns.map((column, i) => {
    if (!Number.isFinite(features[column])) throw new Error(`Missing model feature ${column}.`);
    const scale = model.scaler_scale[i] === 0 ? 1 : model.scaler_scale[i];
    return (features[column] - model.scaler_mean[i]) / scale;
  });
  const sums = model.classes.map(() => 0);
  for (const tree of model.trees) {
    let node = 0;
    while (tree.children_left[node] !== -1 && tree.children_right[node] !== -1) {
      const featureIndex = tree.feature[node];
      node = scaled[featureIndex] <= tree.threshold[node] ? tree.children_left[node] : tree.children_right[node];
    }
    const leaf = tree.value[node];
    const normalizer = leaf.reduce((sum, value) => sum + value, 0);
    if (normalizer > 0) leaf.forEach((value, i) => { sums[i] += value / normalizer; });
  }
  const probabilities = sums.map((sum) => sum / model.trees.length);
  const winner = probabilities.indexOf(Math.max(...probabilities));
  const rawCategory = model.classes[winner];
  const threshold = sensitivity === 'high' ? 0.45 : sensitivity === 'low' ? 0.70 : 0.55;
  const category = rawCategory !== 'normal' && probabilities[winner] < threshold ? 'normal' : rawCategory;
  return {
    predictedCategory: category,
    rawCategory,
    confidence: probabilities[winner],
    probabilities: Object.fromEntries(model.classes.map((name, i) => [name, probabilities[i]])),
    detectionMethod: 'random_forest_json_port',
    modelName: model.model_type,
    modelVersion: model.version,
    nEstimators: model.trees.length,
    features,
  };
}
