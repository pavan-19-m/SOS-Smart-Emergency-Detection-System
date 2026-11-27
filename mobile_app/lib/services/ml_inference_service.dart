import 'dart:convert';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../models/detection_result.dart';
import '../models/user_profile.dart';
import 'sensor_pipeline_service.dart';

/// Pure-Dart on-device Random Forest inference engine loaded from
/// `assets/models/sosense_inference_bundle.json` (exported from scikit-learn).
/// Eliminates dependency on a remote Python server during emergencies.
class MlInferenceService {
  bool _loaded = false;
  List<String> _classes = const [];
  List<String> _featureCols = const [];
  List<double> _scalerMean = const [];
  List<double> _scalerScale = const [];
  List<Map<String, dynamic>> _trees = const [];

  bool get isLoaded => _loaded;
  int get treeCount => _trees.length;

  Future<void> loadFromAsset({String assetPath = AppConstants.modelBundleAsset}) async {
    try {
      final rawJson = await rootBundle.loadString(assetPath);
      loadFromJsonString(rawJson);
    } catch (_) {
      _loaded = false;
    }
  }

  void loadFromJsonString(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    _classes = List<String>.from(decoded['classes'] as List);
    _featureCols = List<String>.from(decoded['feature_columns'] as List);
    _scalerMean = (decoded['scaler_mean'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    _scalerScale = (decoded['scaler_scale'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    _trees = List<Map<String, dynamic>>.from(decoded['trees'] as List);
    _loaded = _trees.isNotEmpty && _classes.isNotEmpty;
  }

  /// Runs local Random Forest inference; falls back gracefully to rule-based
  /// logic if model bundle has not been loaded.
  DetectionResult predict(
    Map<String, double> features, {
    DetectionSensitivity sensitivity = DetectionSensitivity.medium,
  }) {
    final ruleResult = SensorPipelineService.classifyRuleBased(
      features,
      sensitivity: sensitivity,
    );

    if (!_loaded || features.isEmpty) {
      return ruleResult;
    }

    // Standardize features using training StandardScaler parameters
    final scaled = List<double>.filled(_featureCols.length, 0.0);
    for (int i = 0; i < _featureCols.length; i++) {
      final val = features[_featureCols[i]] ?? 0.0;
      final scale = _scalerScale[i] == 0 ? 1.0 : _scalerScale[i];
      scaled[i] = (val - _scalerMean[i]) / scale;
    }

    final classProbs = List<double>.filled(_classes.length, 0.0);
    for (final tree in _trees) {
      final childrenLeft = List<int>.from(tree['children_left'] as List);
      final childrenRight = List<int>.from(tree['children_right'] as List);
      final featIdxList = List<int>.from(tree['feature'] as List);
      final thresholds = (tree['threshold'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final values = tree['value'] as List;

      int node = 0;
      while (childrenLeft[node] != -1 && childrenRight[node] != -1) {
        final fIdx = featIdxList[node];
        if (scaled[fIdx] <= thresholds[node]) {
          node = childrenLeft[node];
        } else {
          node = childrenRight[node];
        }
      }

      final leafCounts = (values[node] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final sum = leafCounts.fold<double>(0.0, (a, b) => a + b);
      if (sum > 0) {
        for (int c = 0; c < _classes.length; c++) {
          classProbs[c] += leafCounts[c] / sum;
        }
      }
    }

    for (int c = 0; c < _classes.length; c++) {
      classProbs[c] /= _trees.length;
    }

    int bestIdx = 0;
    for (int c = 1; c < classProbs.length; c++) {
      if (classProbs[c] > classProbs[bestIdx]) {
        bestIdx = c;
      }
    }

    final predicted = _classes[bestIdx];
    final confidence = classProbs[bestIdx];

    // Sensitivity adjustment: require slightly higher confidence on Low sensitivity
    final minConf = sensitivity == DetectionSensitivity.high
        ? 0.45
        : (sensitivity == DetectionSensitivity.low ? 0.70 : 0.55);

    final finalCategory =
        (predicted != 'normal' && confidence < minConf) ? 'normal' : predicted;

    final reason = finalCategory == 'normal'
        ? 'On-device Random Forest (${_trees.length} trees) classified window as normal motion.'
        : 'On-device Random Forest classified $finalCategory (${(confidence * 100).toStringAsFixed(1)}% confidence). ${ruleResult.reason}';

    return DetectionResult(
      predictedCategory: finalCategory,
      confidence: confidence,
      detectionMethod: 'random_forest_on_device',
      reason: reason,
      features: features,
      timestamp: DateTime.now(),
    );
  }
}
