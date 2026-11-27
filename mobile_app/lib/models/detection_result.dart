class DetectionResult {
  final String predictedCategory; // normal, fall_like, crash_candidate, unusual_movement
  final double confidence;
  final String detectionMethod; // random_forest_on_device, rule_based_baseline, hybrid
  final String reason;
  final Map<String, double> features;
  final DateTime timestamp;

  const DetectionResult({
    required this.predictedCategory,
    required this.confidence,
    required this.detectionMethod,
    required this.reason,
    required this.features,
    required this.timestamp,
  });

  bool get isEmergencyCandidate => predictedCategory != 'normal';

  String get humanTitle {
    switch (predictedCategory) {
      case 'crash_candidate':
        return 'Possible Accident Detected';
      case 'fall_like':
        return 'Possible Fall Detected';
      case 'unusual_movement':
        return 'Unusual Movement Detected';
      default:
        return 'Normal Activity';
    }
  }
}
