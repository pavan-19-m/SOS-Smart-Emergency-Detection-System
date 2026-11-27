import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import '../core/constants.dart';
import '../models/detection_result.dart';
import '../models/sensor_reading.dart';
import '../models/user_profile.dart';

/// Multi-stage smartphone sensor preprocessing & feature extraction pipeline.
/// Mirrors `data_science/scripts/04_feature_engineering.py` for train/serve parity.
class SensorPipelineService {
  final List<SensorSample> _windowBuffer = [];
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  double _latestGx = 0, _latestGy = 0, _latestGz = 0;
  double _filteredAx = 0, _filteredAy = 0, _filteredAz = 9.80665;
  bool _hasFilterInit = false;

  bool isMonitoring = false;
  bool sensorsAvailable = true;
  String? sensorStatusMessage;

  SensorSample? latestSample;

  /// Exponential moving-average low-pass filter (alpha = 0.65 at ~50Hz suppresses high-freq jitter)
  SensorSample ingestRawSample({
    required double ax,
    required double ay,
    required double az,
    required double gx,
    required double gy,
    required double gz,
    DateTime? timestamp,
  }) {
    const alpha = 0.65;
    if (!_hasFilterInit) {
      _filteredAx = ax;
      _filteredAy = ay;
      _filteredAz = az;
      _hasFilterInit = true;
    } else {
      _filteredAx = alpha * ax + (1 - alpha) * _filteredAx;
      _filteredAy = alpha * ay + (1 - alpha) * _filteredAy;
      _filteredAz = alpha * az + (1 - alpha) * _filteredAz;
    }

    final sample = SensorSample(
      ax: _filteredAx,
      ay: _filteredAy,
      az: _filteredAz,
      gx: gx,
      gy: gy,
      gz: gz,
      timestamp: timestamp ?? DateTime.now(),
    );
    latestSample = sample;
    _windowBuffer.add(sample);
    if (_windowBuffer.length > AppConstants.windowSizeSamples) {
      _windowBuffer.removeAt(0);
    }
    return sample;
  }

  List<SensorSample> get currentWindow => List.unmodifiable(_windowBuffer);

  void startListening({
    required void Function(SensorSample sample) onSample,
    required void Function(List<SensorSample> window) onWindowReady,
    void Function(String error)? onSensorError,
  }) {
    if (isMonitoring) return;
    isMonitoring = true;
    sensorStatusMessage = 'Monitoring active';

    try {
      _gyroSub = gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: 20),
      ).listen(
        (event) {
          _latestGx = event.x;
          _latestGy = event.y;
          _latestGz = event.z;
        },
        onError: (err) {
          sensorsAvailable = false;
          sensorStatusMessage = 'Gyroscope unavailable on this device';
          onSensorError?.call(sensorStatusMessage!);
        },
      );

      _accSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 20),
      ).listen(
        (event) {
          final sample = ingestRawSample(
            ax: event.x,
            ay: event.y,
            az: event.z,
            gx: _latestGx,
            gy: _latestGy,
            gz: _latestGz,
            timestamp: DateTime.now(),
          );
          onSample(sample);
          if (_windowBuffer.length >= AppConstants.windowSizeSamples) {
            onWindowReady(List<SensorSample>.from(_windowBuffer));
            // 50% sliding overlap (advance by 64 samples)
            _windowBuffer.removeRange(0, 64);
          }
        },
        onError: (err) {
          sensorsAvailable = false;
          isMonitoring = false;
          sensorStatusMessage = 'Accelerometer unavailable on this device';
          onSensorError?.call(sensorStatusMessage!);
        },
      );
    } catch (e) {
      sensorsAvailable = false;
      isMonitoring = false;
      sensorStatusMessage = 'Hardware sensor stream failed: $e';
      onSensorError?.call(sensorStatusMessage!);
    }
  }

  void stopListening({String reason = 'Monitoring paused by user'}) {
    _accSub?.cancel();
    _gyroSub?.cancel();
    _accSub = null;
    _gyroSub = null;
    isMonitoring = false;
    sensorStatusMessage = reason;
  }

  /// Computes the exact 20 time-domain features expected by the trained ML model.
  static Map<String, double> extractFeatures(
    List<SensorSample> window, {
    double fsHz = 50.0,
  }) {
    if (window.isEmpty) {
      return {};
    }
    final n = window.length;
    final dt = 1.0 / fsHz;

    final accMags = <double>[];
    final gyroMags = <double>[];
    final bodyMags = <double>[];

    double accMean = 0;
    double gyroMean = 0;
    for (final s in window) {
      final am = s.accMagnitude;
      final gm = s.gyroMagnitude;
      accMags.add(am);
      gyroMags.add(gm);
      accMean += am;
      gyroMean += gm;
    }
    accMean /= n;
    gyroMean /= n;

    double accMax = accMags.first;
    double accMin = accMags.first;
    double accVar = 0;
    double accEnergy = 0;
    double gyroMax = gyroMags.first;
    double gyroVar = 0;
    double gyroEnergy = 0;
    int peakCount = 0;
    int freeFallCount = 0;
    double smaSum = 0;
    double bodyMean = 0;

    // Approximate gravity vector using window mean per axis for body-acc separation
    double meanAx = 0, meanAy = 0, meanAz = 0;
    for (final s in window) {
      meanAx += s.ax;
      meanAy += s.ay;
      meanAz += s.az;
    }
    meanAx /= n;
    meanAy /= n;
    meanAz /= n;

    for (int i = 0; i < n; i++) {
      final am = accMags[i];
      final gm = gyroMags[i];
      if (am > accMax) accMax = am;
      if (am < accMin) accMin = am;
      if (gm > gyroMax) gyroMax = gm;

      accVar += math.pow(am - accMean, 2);
      accEnergy += am * am;
      gyroVar += math.pow(gm - gyroMean, 2);
      gyroEnergy += gm * gm;

      if (am > 17.65) peakCount++;
      if (am < 5.4) freeFallCount++;

      final bx = window[i].ax - meanAx;
      final by = window[i].ay - meanAy;
      final bz = window[i].az - meanAz;
      smaSum += bx.abs() + by.abs() + bz.abs();
      final bm = math.sqrt(bx * bx + by * by + bz * bz);
      bodyMags.add(bm);
      bodyMean += bm;
    }

    accVar /= n;
    final accStd = math.sqrt(accVar);
    accEnergy /= n;
    gyroVar /= n;
    final gyroStd = math.sqrt(gyroVar);
    gyroEnergy /= n;
    bodyMean /= n;

    double bodyVar = 0;
    for (final bm in bodyMags) {
      bodyVar += math.pow(bm - bodyMean, 2);
    }
    final bodyStd = math.sqrt(bodyVar / n);

    double jerkMax = 0;
    for (int i = 1; i < n; i++) {
      final j = (accMags[i] - accMags[i - 1]).abs() / dt;
      if (j > jerkMax) jerkMax = j;
    }

    // Orientation shift between first 16 and last 16 samples
    final k = math.min(16, n);
    double sx = 0, sy = 0, sz = 0, ex = 0, ey = 0, ez = 0;
    for (int i = 0; i < k; i++) {
      sx += window[i].ax;
      sy += window[i].ay;
      sz += window[i].az;
      final tail = window[n - 1 - i];
      ex += tail.ax;
      ey += tail.ay;
      ez += tail.az;
    }
    sx /= k;
    sy /= k;
    sz /= k;
    ex /= k;
    ey /= k;
    ez /= k;

    final dot = sx * ex + sy * ey + sz * ez;
    final normProd =
        math.sqrt(sx * sx + sy * sy + sz * sz) *
                math.sqrt(ex * ex + ey * ey + ez * ez) +
            1e-8;
    final cosTheta = (dot / normProd).clamp(-1.0, 1.0);
    final orientDeg = math.acos(cosTheta) * (180.0 / math.pi);

    // Post-peak inactivity ratio & active duration
    final peakIdx = accMags.indexOf(accMax);
    final tailStart = math.min(peakIdx + 6, n - 1);
    int tailQuiet = 0;
    int totalQuiet = 0;
    int activeSamples = 0;
    for (int i = 0; i < n; i++) {
      final isQuiet = bodyMags[i] < 1.2 && gyroMags[i] < 0.35;
      if (isQuiet) totalQuiet++;
      if (i >= tailStart && isQuiet) tailQuiet++;
      if (bodyMags[i] > 2.5 || gyroMags[i] > 1.0) activeSamples++;
    }
    final tailLen = math.max(1, n - tailStart);

    return {
      'acc_mag_mean': accMean,
      'acc_mag_max': accMax,
      'acc_mag_min': accMin,
      'acc_mag_std': accStd,
      'acc_mag_var': accVar,
      'acc_sma': smaSum / n,
      'acc_energy': accEnergy,
      'acc_jerk_max': jerkMax,
      'acc_peak_count': peakCount.toDouble(),
      'free_fall_ratio': freeFallCount / n,
      'gyro_mag_mean': gyroMean,
      'gyro_mag_max': gyroMax,
      'gyro_mag_std': gyroStd,
      'gyro_energy': gyroEnergy,
      'orientation_change_deg': orientDeg,
      'post_peak_inactivity_ratio': tailQuiet / tailLen,
      'body_acc_mag_mean': bodyMean,
      'body_acc_mag_std': bodyStd,
      'event_duration_sec': activeSamples * dt,
      'inactivity_duration_sec': totalQuiet * dt,
    };
  }

  /// Interpretable rule-based baseline classifier (mirrors 05_rule_based_detector.py).
  static DetectionResult classifyRuleBased(
    Map<String, double> f, {
    DetectionSensitivity sensitivity = DetectionSensitivity.medium,
  }) {
    final factor = sensitivity == DetectionSensitivity.high
        ? 0.85
        : (sensitivity == DetectionSensitivity.low ? 1.15 : 1.0);

    final accMaxG = (f['acc_mag_max'] ?? 9.81) / AppConstants.gravityMs2;
    final accMinG = (f['acc_mag_min'] ?? 9.81) / AppConstants.gravityMs2;
    final gyroMax = f['gyro_mag_max'] ?? 0.0;
    final orientDeg = f['orientation_change_deg'] ?? 0.0;
    final postQuiet = f['post_peak_inactivity_ratio'] ?? 0.0;
    final freeFall = f['free_fall_ratio'] ?? 0.0;
    final bodyStd = f['body_acc_mag_std'] ?? 0.0;
    final gyroMean = f['gyro_mag_mean'] ?? 0.0;
    final inactivityDur = f['inactivity_duration_sec'] ?? 0.0;

    if (accMaxG >= 4.2 * factor &&
        gyroMax >= 3.2 * factor &&
        postQuiet >= 0.45) {
      return DetectionResult(
        predictedCategory: 'crash_candidate',
        confidence: (0.65 + (accMaxG - 4.2) * 0.06).clamp(0.65, 0.95),
        detectionMethod: 'rule_based_baseline',
        reason:
            'High impact peak (${accMaxG.toStringAsFixed(2)}g), angular spike (${gyroMax.toStringAsFixed(2)} rad/s), and post-event stillness.',
        features: f,
        timestamp: DateTime.now(),
      );
    }

    if (accMaxG >= 2.5 * factor &&
        (freeFall >= 0.04 || accMinG <= 0.55) &&
        orientDeg >= 30.0 * factor &&
        postQuiet >= 0.45) {
      return DetectionResult(
        predictedCategory: 'fall_like',
        confidence: (0.60 + (orientDeg / 180.0) * 0.25).clamp(0.60, 0.92),
        detectionMethod: 'rule_based_baseline',
        reason:
            'Free-fall dip (${accMinG.toStringAsFixed(2)}g), impact (${accMaxG.toStringAsFixed(2)}g), orientation shift (${orientDeg.toStringAsFixed(1)} deg).',
        features: f,
        timestamp: DateTime.now(),
      );
    }

    if (gyroMax >= 4.0 * factor && accMaxG < 4.2 * factor) {
      return DetectionResult(
        predictedCategory: 'unusual_movement',
        confidence: 0.72,
        detectionMethod: 'rule_based_baseline',
        reason:
            'Abnormal rotational velocity burst (${gyroMax.toStringAsFixed(2)} rad/s).',
        features: f,
        timestamp: DateTime.now(),
      );
    }

    if (bodyStd < 0.05 && gyroMean < 0.025 && inactivityDur >= 2.5) {
      return DetectionResult(
        predictedCategory: 'unusual_movement',
        confidence: 0.65,
        detectionMethod: 'rule_based_baseline',
        reason: 'Prolonged near-zero motion across active monitoring window.',
        features: f,
        timestamp: DateTime.now(),
      );
    }

    return DetectionResult(
      predictedCategory: 'normal',
      confidence: 0.88,
      detectionMethod: 'rule_based_baseline',
      reason: 'Motion energy and angular velocity within normal activity bounds.',
      features: f,
      timestamp: DateTime.now(),
    );
  }
}
