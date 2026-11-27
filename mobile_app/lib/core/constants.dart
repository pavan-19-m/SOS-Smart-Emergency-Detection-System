class AppConstants {
  static const String appName = 'SOSense';
  static const String appTagline =
      'Intelligent Sensor-Based Emergency Detection & Safety Analytics';
  static const String modelBundleAsset =
      'assets/models/sosense_inference_bundle.json';

  static const double gravityMs2 = 9.80665;
  static const double samplingRateHz = 50.0;
  static const int windowSizeSamples = 128;

  static const int defaultVerificationCountdownSec = 15;
  static const int defaultCheckInIntervalMin = 30;
  static const int defaultEscalationDelaySec = 120;

  static const String honestSafetyDisclaimer =
      'SOSense combines smartphone motion sensors, rule-based thresholds, and '
      'machine learning models to identify possible fall-like or impact-like '
      'events. It does not guarantee detection of all road accidents, crimes, '
      'or medical emergencies. Always contact local emergency services directly '
      'whenever possible.';
}
