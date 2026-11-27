import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sosense_mobile/models/sensor_reading.dart';
import 'package:sosense_mobile/models/user_profile.dart';
import 'package:sosense_mobile/services/auth_service.dart';
import 'package:sosense_mobile/services/ml_inference_service.dart';
import 'package:sosense_mobile/services/notification_service.dart';
import 'package:sosense_mobile/services/sensor_pipeline_service.dart';
import 'package:sosense_mobile/models/emergency_contact.dart';
import 'package:sosense_mobile/models/incident.dart';

void main() {
  group('Form Validators', () {
    test('rejects invalid email and short password', () {
      expect(AuthService.validateEmail('bad-email'), isNotNull);
      expect(AuthService.validateEmail('user@example.com'), isNull);
      expect(AuthService.validatePassword('1234'), isNotNull);
      expect(AuthService.validatePassword('StrongPass123'), isNull);
    });
  });

  group('Sensor Feature Extraction & Rule-Based Classifier', () {
    test('detects high-G crash candidate with stillness', () {
      final samples = List<SensorSample>.generate(128, (i) {
        final isImpact = i >= 40 && i <= 44;
        return SensorSample(
          ax: isImpact ? 62.0 : 0.0,
          ay: 0.0,
          az: 9.81,
          gx: isImpact ? 5.2 : 0.01,
          gy: 0.0,
          gz: 0.0,
          timestamp: DateTime.now(),
        );
      });
      final feats = SensorPipelineService.extractFeatures(samples);
      expect(feats.length, 20);
      expect(feats['acc_mag_max']!, greaterThan(55.0));

      final ruleRes = SensorPipelineService.classifyRuleBased(feats);
      expect(ruleRes.predictedCategory, 'crash_candidate');
    });

    test('loads exported Random Forest JSON bundle and predicts cleanly', () {
      final file = File('assets/models/sosense_inference_bundle.json');
      expect(file.existsSync(), isTrue);

      final ml = MlInferenceService();
      ml.loadFromJsonString(file.readAsStringSync());
      expect(ml.isLoaded, isTrue);
      expect(ml.treeCount, greaterThan(10));

      final normalSamples = List<SensorSample>.generate(
        128,
        (_) => SensorSample(
          ax: 0.1,
          ay: 0.2,
          az: 9.81,
          gx: 0.05,
          gy: 0.03,
          gz: 0.02,
          timestamp: DateTime.now(),
        ),
      );
      final feats = SensorPipelineService.extractFeatures(normalSamples);
      final pred = ml.predict(feats, sensitivity: DetectionSensitivity.medium);
      expect(pred.predictedCategory, isNotEmpty);
      expect(pred.confidence, inInclusiveRange(0.0, 1.0));
    });
  });

  group('Notification Service Safety Guards', () {
    test('suppresses notifications in simulation mode and offline mode', () {
      final svc = NotificationService();
      const contact = EmergencyContact(
        id: 'c1',
        name: 'Mom',
        relationship: 'Parent',
        phone: '+19999999999',
        email: 'mom@example.com',
      );
      final simIncident = Incident(
        id: 'INC-SIM',
        userId: 'u1',
        eventType: 'manual_sos',
        triggerSource: 'demo_simulator',
        createdAt: DateTime.now(),
        detectionMethod: 'manual',
        detectionReason: 'Demo',
        modelConfidence: 1.0,
        userResponse: 'confirmed_emergency',
        status: IncidentStatus.active,
        isSimulation: true,
      );

      final simRes = svc.buildDispatchBatch(
        incident: simIncident,
        userName: 'Aarav',
        contacts: [contact],
        isOnline: true,
      );
      expect(simRes.createdNotifications, isEmpty);

      final realIncident = simIncident.copyWith();
      final offlineRes = svc.buildDispatchBatch(
        incident: Incident(
          id: 'INC-OFF',
          userId: 'u1',
          eventType: 'manual_sos',
          triggerSource: 'user_button',
          createdAt: DateTime.now(),
          detectionMethod: 'manual',
          detectionReason: 'Real',
          modelConfidence: 1.0,
          userResponse: 'confirmed_emergency',
          status: IncidentStatus.active,
          isSimulation: false,
        ),
        userName: 'Aarav',
        contacts: [contact],
        isOnline: false,
      );
      expect(offlineRes.createdNotifications, isEmpty);
      expect(realIncident.id, 'INC-SIM');
    });
  });
}
