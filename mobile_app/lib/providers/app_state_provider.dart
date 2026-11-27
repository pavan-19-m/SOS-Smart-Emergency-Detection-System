import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/detection_result.dart';
import '../models/emergency_contact.dart';
import '../models/incident.dart';
import '../models/safety_session.dart';
import '../models/sensor_reading.dart';
import '../models/user_profile.dart';
import '../repositories/firebase_repository.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/ml_inference_service.dart';
import '../services/notification_service.dart';
import '../services/offline_queue_service.dart';
import '../services/sensor_pipeline_service.dart';

class AppStateProvider extends ChangeNotifier {
  final FirebaseRepository firebaseRepo;
  final AuthService authService;
  final SensorPipelineService sensorService;
  final MlInferenceService mlService;
  final LocationService locationService;
  final OfflineQueueService offlineQueueService;
  final NotificationService notificationService;

  final Uuid _uuid = const Uuid();

  AppStateProvider({
    FirebaseRepository? firebaseRepo,
    AuthService? authService,
    SensorPipelineService? sensorService,
    MlInferenceService? mlService,
    LocationService? locationService,
    OfflineQueueService? offlineQueueService,
    NotificationService? notificationService,
  })  : firebaseRepo = firebaseRepo ?? FirebaseRepository(),
        authService = authService ?? AuthService(),
        sensorService = sensorService ?? SensorPipelineService(),
        mlService = mlService ?? MlInferenceService(),
        locationService = locationService ?? LocationService(),
        offlineQueueService = offlineQueueService ?? OfflineQueueService(),
        notificationService = notificationService ?? NotificationService();

  ThemeMode themeMode = ThemeMode.light;
  UserProfile? currentUser;
  bool isOnline = true;
  bool simulateOffline = false;
  bool simulateGpsUnavailable = false;
  bool backgroundRestrictionsDetected = false;

  LocationSnapshot currentLocation = const LocationSnapshot();
  SensorSample? latestSensorSample;
  DetectionResult? latestDetection;

  // Pending emergency verification prompt state
  Incident? pendingVerificationIncident;
  int verificationSecondsLeft = 0;
  Timer? _verificationTimer;

  // Active safety check-in session
  SafetySession? activeSafetySession;
  Timer? _checkInTimer;
  Timer? _escalationTimer;

  final List<EmergencyContact> contacts = [];
  final List<Incident> incidents = [];
  final List<AppNotification> notifications = [];
  int queuedOfflineCount = 0;

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  bool get effectiveOnline => isOnline && !simulateOffline;
  bool get isAuthenticated => currentUser != null;

  Future<void> initialize() async {
    await mlService.loadFromAsset();
    await _refreshOfflineQueueCount();
    _startConnectivityWatcher();
  }

  void _startConnectivityWatcher() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      final connected = results.any((r) => r != ConnectivityResult.none);
      isOnline = connected;
      if (effectiveOnline) {
        await syncOfflineQueue();
      }
      notifyListeners();
    });
  }

  void toggleThemeMode() {
    themeMode = themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      String uid = 'local_${email.hashCode.abs()}';
      if (firebaseRepo.isFirebaseInitialized) {
        final fbUid = await firebaseRepo.signInWithEmail(email, password);
        if (fbUid != null) uid = fbUid;
      }
      currentUser = authService.buildDefaultProfile(
        uid: uid,
        displayName: email.split('@').first,
        email: email.trim(),
      );
      _seedDefaultEvaluatorContactsIfEmpty();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> register({
    required String displayName,
    required String email,
    required String password,
    required String phone,
  }) async {
    try {
      String uid = 'local_${email.hashCode.abs()}';
      if (firebaseRepo.isFirebaseInitialized) {
        final fbUid = await firebaseRepo.registerWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        );
        if (fbUid != null) uid = fbUid;
      }
      currentUser = authService.buildDefaultProfile(
        uid: uid,
        displayName: displayName.trim(),
        email: email.trim(),
        phone: phone.trim(),
      );
      await firebaseRepo.saveUserProfile(currentUser!);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await firebaseRepo.sendPasswordReset(email);
  }

  Future<void> logout() async {
    stopSensorMonitoring();
    _verificationTimer?.cancel();
    _checkInTimer?.cancel();
    _escalationTimer?.cancel();
    await firebaseRepo.signOut();
    currentUser = null;
    pendingVerificationIncident = null;
    activeSafetySession = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final uid = currentUser?.uid;
    if (uid != null) {
      await firebaseRepo.deleteAllUserData(uid);
    }
    contacts.clear();
    incidents.clear();
    notifications.clear();
    await offlineQueueService.clearAll();
    queuedOfflineCount = 0;
    await logout();
  }

  void updateProfile(UserProfile updated) {
    currentUser = updated;
    firebaseRepo.saveUserProfile(updated);
    notifyListeners();
  }

  void _seedDefaultEvaluatorContactsIfEmpty() {
    if (contacts.isNotEmpty) return;
    contacts.addAll([
      const EmergencyContact(
        id: 'contact_primary_demo',
        name: 'Primary Family Contact',
        relationship: 'Parent',
        phone: '+10000000001',
        email: 'primary.family@example.com',
        priority: ContactPriority.primary,
        isVerified: true,
      ),
      const EmergencyContact(
        id: 'contact_secondary_demo',
        name: 'Secondary Trusted Contact',
        relationship: 'Sibling',
        phone: '+10000000002',
        email: 'secondary.family@example.com',
        priority: ContactPriority.secondary,
        isVerified: false,
      ),
    ]);
  }

  void addOrUpdateContact(EmergencyContact contact) {
    final idx = contacts.indexWhere((c) => c.id == contact.id);
    if (idx >= 0) {
      contacts[idx] = contact;
    } else {
      contacts.add(contact);
    }
    if (currentUser != null) {
      firebaseRepo.saveContact(currentUser!.uid, contact);
    }
    notifyListeners();
  }

  void removeContact(String contactId) {
    contacts.removeWhere((c) => c.id == contactId);
    if (currentUser != null) {
      firebaseRepo.deleteContact(currentUser!.uid, contactId);
    }
    notifyListeners();
  }

  Future<void> refreshLocation() async {
    currentLocation = await locationService.getCurrentLocation(
      simulateGpsUnavailable: simulateGpsUnavailable,
    );
    notifyListeners();
  }

  void startSensorMonitoring() {
    sensorService.startListening(
      onSample: (sample) {
        latestSensorSample = sample;
        notifyListeners();
      },
      onWindowReady: (window) {
        final features = SensorPipelineService.extractFeatures(window);
        final res = mlService.predict(
          features,
          sensitivity:
              currentUser?.sensitivity ?? DetectionSensitivity.medium,
        );
        latestDetection = res;

        final user = currentUser;
        if (user != null && res.isEmergencyCandidate) {
          final allowed = (res.predictedCategory == 'fall_like' &&
                  user.fallDetectionEnabled) ||
              (res.predictedCategory == 'crash_candidate' &&
                  user.accidentDetectionEnabled) ||
              (res.predictedCategory == 'unusual_movement' &&
                  user.anomalyDetectionEnabled);
          if (allowed && pendingVerificationIncident == null) {
            triggerSensorDetectionVerification(res, isSimulation: false);
          }
        }
        notifyListeners();
      },
      onSensorError: (_) => notifyListeners(),
    );
    notifyListeners();
  }

  void stopSensorMonitoring() {
    sensorService.stopListening();
    notifyListeners();
  }

  /// Manual SOS activation (immediate or after optional short countdown).
  Future<Incident> triggerManualSos({
    bool isSimulation = false,
    String note = 'Manual SOS button activated by user.',
  }) async {
    await refreshLocation();
    final user = currentUser;
    final inc = Incident(
      id: 'INC-${_uuid.v4().substring(0, 8).toUpperCase()}',
      userId: user?.uid ?? 'anonymous',
      eventType: 'manual_sos',
      triggerSource: isSimulation ? 'demo_simulator' : 'user_button',
      createdAt: DateTime.now(),
      detectionMethod: 'manual_trigger',
      detectionReason: note,
      modelConfidence: 1.0,
      userResponse: 'confirmed_emergency',
      status: effectiveOnline || isSimulation
          ? IncidentStatus.active
          : IncidentStatus.queuedOffline,
      authorizedContactUids: contacts
          .where((c) => c.linkedUid != null)
          .map((c) => c.linkedUid!)
          .toList(),
      authorizedContactEmails: contacts.map((c) => c.email).toList(),
      location: currentLocation,
      isSimulation: isSimulation,
    );

    return _finalizeAndDispatchIncident(inc);
  }

  /// Starts user verification countdown ("Are you okay?") for sensor detections.
  Future<void> triggerSensorDetectionVerification(
    DetectionResult result, {
    required bool isSimulation,
  }) async {
    await refreshLocation();
    final eventType = result.predictedCategory == 'crash_candidate'
        ? 'possible_accident'
        : (result.predictedCategory == 'fall_like'
            ? 'possible_fall'
            : 'unusual_movement');

    final inc = Incident(
      id: 'INC-${_uuid.v4().substring(0, 8).toUpperCase()}',
      userId: currentUser?.uid ?? 'anonymous',
      eventType: eventType,
      triggerSource: isSimulation ? 'demo_simulator' : 'sensor_pipeline',
      createdAt: DateTime.now(),
      detectionMethod: result.detectionMethod,
      detectionReason: result.reason,
      modelConfidence: result.confidence,
      userResponse: 'pending',
      status: IncidentStatus.pendingVerification,
      authorizedContactEmails: contacts.map((c) => c.email).toList(),
      location: currentLocation,
      isSimulation: isSimulation,
      sensorFeatureSnapshot: result.features,
    );

    pendingVerificationIncident = inc;
    verificationSecondsLeft =
        currentUser?.alertCountdownSeconds ?? AppConstants.defaultVerificationCountdownSec;
    notifyListeners();

    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (verificationSecondsLeft > 1) {
        verificationSecondsLeft--;
        notifyListeners();
      } else {
        timer.cancel();
        await confirmPendingIncident(userResponded: false);
      }
    });
  }

  /// User taps "I'm Safe" during verification countdown.
  Future<void> cancelPendingIncident() async {
    _verificationTimer?.cancel();
    final pending = pendingVerificationIncident;
    pendingVerificationIncident = null;
    verificationSecondsLeft = 0;

    if (pending != null) {
      final cancelled = pending.copyWith(
        status: IncidentStatus.cancelled,
        userResponse: 'i_am_safe',
        isFalseAlarm: true,
        dispatchMessage: 'Cancelled by user during verification countdown.',
      );
      incidents.insert(0, cancelled);
      await firebaseRepo.saveIncident(cancelled);
    }
    notifyListeners();
  }

  /// User taps "Confirm Emergency" OR countdown expires without response.
  Future<void> confirmPendingIncident({bool userResponded = true}) async {
    _verificationTimer?.cancel();
    final pending = pendingVerificationIncident;
    pendingVerificationIncident = null;
    verificationSecondsLeft = 0;
    if (pending == null) return;

    final confirmed = pending.copyWith(
      status: effectiveOnline || pending.isSimulation
          ? IncidentStatus.active
          : IncidentStatus.queuedOffline,
      userResponse: userResponded ? 'confirmed_emergency' : 'no_response_timeout',
    );
    await _finalizeAndDispatchIncident(confirmed);
  }

  Future<Incident> _finalizeAndDispatchIncident(Incident inc) async {
    final batch = notificationService.buildDispatchBatch(
      incident: inc,
      userName: currentUser?.displayName ?? 'SOSense User',
      contacts: contacts,
      isOnline: effectiveOnline,
    );

    IncidentStatus finalStatus;
    if (inc.isSimulation) {
      finalStatus = IncidentStatus.dispatched;
    } else if (!effectiveOnline) {
      finalStatus = IncidentStatus.queuedOffline;
      await offlineQueueService.enqueue(inc);
      await _refreshOfflineQueueCount();
    } else if (batch.notifiedContactNames.isEmpty) {
      finalStatus = IncidentStatus.active;
    } else {
      finalStatus = IncidentStatus.dispatched;
    }

    final saved = inc.copyWith(
      status: finalStatus,
      notifiedContactNames: batch.notifiedContactNames,
      dispatchMessage: batch.deliverySummary,
    );

    incidents.insert(0, saved);
    notifications.insertAll(0, batch.createdNotifications);
    if (effectiveOnline && !inc.isSimulation) {
      await firebaseRepo.saveIncident(saved);
      _scheduleEscalationCheck(saved.id);
    }
    notifyListeners();
    return saved;
  }

  void _scheduleEscalationCheck(String incidentId) {
    final delaySec = currentUser?.escalationDelaySeconds ??
        AppConstants.defaultEscalationDelaySec;
    _escalationTimer?.cancel();
    _escalationTimer = Timer(Duration(seconds: delaySec), () {
      escalateIncident(incidentId);
    });
  }

  /// Escalates an unacknowledged incident to secondary contacts (never duplicates).
  void escalateIncident(String incidentId) {
    final idx = incidents.indexWhere((i) => i.id == incidentId);
    if (idx < 0) return;
    final inc = incidents[idx];
    if (inc.status == IncidentStatus.acknowledged ||
        inc.status == IncidentStatus.resolved ||
        inc.status == IncidentStatus.cancelled ||
        inc.status == IncidentStatus.escalated) {
      return;
    }

    final batch = notificationService.buildDispatchBatch(
      incident: inc,
      userName: currentUser?.displayName ?? 'SOSense User',
      contacts: contacts,
      isOnline: effectiveOnline,
      escalationOnly: true,
    );

    final mergedNames = {
      ...inc.notifiedContactNames,
      ...batch.notifiedContactNames,
    }.toList();

    incidents[idx] = inc.copyWith(
      status: IncidentStatus.escalated,
      notifiedContactNames: mergedNames,
      dispatchMessage: inc.isSimulation
          ? 'Demo Mode: simulated escalation to secondary contacts.'
          : 'Escalated to secondary contacts (${batch.notifiedContactNames.join(', ')}).',
    );
    notifications.insertAll(0, batch.createdNotifications);
    notifyListeners();
  }

  void acknowledgeIncident(String incidentId, {String responderName = 'Primary Contact'}) {
    final idx = incidents.indexWhere((i) => i.id == incidentId);
    if (idx < 0) return;
    incidents[idx] = incidents[idx].copyWith(
      status: IncidentStatus.acknowledged,
      acknowledgedBy: responderName,
      acknowledgedAt: DateTime.now(),
      dispatchMessage: 'Acknowledged by $responderName. Escalation stopped.',
    );
    for (int i = 0; i < notifications.length; i++) {
      if (notifications[i].incidentId == incidentId) {
        notifications[i] = notifications[i].copyWith(acknowledged: true);
      }
    }
    if (effectiveOnline && !incidents[idx].isSimulation) {
      firebaseRepo.saveIncident(incidents[idx]);
    }
    notifyListeners();
  }

  void resolveIncident(String incidentId, {bool markFalseAlarm = false}) {
    final idx = incidents.indexWhere((i) => i.id == incidentId);
    if (idx < 0) return;
    incidents[idx] = incidents[idx].copyWith(
      status: markFalseAlarm ? IncidentStatus.falseAlarm : IncidentStatus.resolved,
      isFalseAlarm: markFalseAlarm,
    );
    if (effectiveOnline && !incidents[idx].isSimulation) {
      firebaseRepo.saveIncident(incidents[idx]);
    }
    notifyListeners();
  }

  void deleteIncident(String incidentId) {
    incidents.removeWhere((i) => i.id == incidentId);
    firebaseRepo.deleteIncident(incidentId);
    notifyListeners();
  }

  // --- Safe Check-In System ---
  void startSafetySession({
    required String label,
    required int durationMinutes,
    required int intervalMinutes,
    bool isSimulation = false,
  }) {
    final now = DateTime.now();
    activeSafetySession = SafetySession(
      id: 'SESS-${_uuid.v4().substring(0, 8).toUpperCase()}',
      userId: currentUser?.uid ?? 'anonymous',
      label: label,
      startedAt: now,
      expectedArrivalAt: now.add(Duration(minutes: durationMinutes)),
      checkInIntervalMinutes: intervalMinutes,
      nextCheckInDueAt: now.add(Duration(minutes: intervalMinutes)),
      isSimulation: isSimulation,
    );
    _checkInTimer?.cancel();
    _checkInTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final s = activeSafetySession;
      if (s == null) return;
      if (DateTime.now().isAfter(s.nextCheckInDueAt) && s.status == 'active') {
        activeSafetySession = s.copyWith(status: 'warning_grace');
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void confirmCheckInSafe() {
    final s = activeSafetySession;
    if (s == null) return;
    activeSafetySession = s.copyWith(
      status: 'active',
      nextCheckInDueAt:
          DateTime.now().add(Duration(minutes: s.checkInIntervalMinutes)),
    );
    notifyListeners();
  }

  void extendSafetySession(int extraMinutes) {
    final s = activeSafetySession;
    if (s == null) return;
    activeSafetySession = s.copyWith(
      expectedArrivalAt: s.expectedArrivalAt.add(Duration(minutes: extraMinutes)),
      nextCheckInDueAt:
          DateTime.now().add(Duration(minutes: s.checkInIntervalMinutes)),
      status: 'active',
    );
    notifyListeners();
  }

  void endSafetySession() {
    _checkInTimer?.cancel();
    activeSafetySession = null;
    notifyListeners();
  }

  Future<Incident> triggerMissedCheckIn({bool isSimulation = false}) async {
    await refreshLocation();
    final inc = Incident(
      id: 'INC-${_uuid.v4().substring(0, 8).toUpperCase()}',
      userId: currentUser?.uid ?? 'anonymous',
      eventType: 'missed_check_in',
      triggerSource: isSimulation ? 'demo_simulator' : 'check_in_timer',
      createdAt: DateTime.now(),
      detectionMethod: 'check_in_grace_timeout',
      detectionReason:
          'Scheduled safety check-in was missed after grace period. Note: does not prove an accident occurred.',
      modelConfidence: 1.0,
      userResponse: 'missed_check_in',
      status: IncidentStatus.active,
      authorizedContactEmails: contacts.map((c) => c.email).toList(),
      location: currentLocation,
      isSimulation: isSimulation,
    );
    if (activeSafetySession != null) {
      activeSafetySession = activeSafetySession!.copyWith(status: 'missed');
    }
    return _finalizeAndDispatchIncident(inc);
  }

  Future<void> syncOfflineQueue() async {
    if (!effectiveOnline) return;
    final queued = await offlineQueueService.getQueuedIncidents();
    for (final q in queued) {
      await firebaseRepo.saveIncident(
        q.copyWith(status: IncidentStatus.dispatched),
      );
      await offlineQueueService.removeById(q.id);
    }
    await _refreshOfflineQueueCount();
    notifyListeners();
  }

  Future<void> _refreshOfflineQueueCount() async {
    final queued = await offlineQueueService.getQueuedIncidents();
    queuedOfflineCount = queued.length;
  }

  // --- Safe Demo Mode Scenarios ---
  Future<void> runDemoScenario(String scenarioKey) async {
    switch (scenarioKey) {
      case 'manual_sos':
        await triggerManualSos(
          isSimulation: true,
          note: '[SIMULATION] Manual SOS evaluation drill.',
        );
        break;
      case 'possible_accident':
        await triggerSensorDetectionVerification(
          DetectionResult(
            predictedCategory: 'crash_candidate',
            confidence: 0.94,
            detectionMethod: 'random_forest_on_device',
            reason:
                '[SIMULATION] High deceleration peak (6.8g), rotational impulse (6.1 rad/s), and post-event stillness.',
            features: const {'acc_mag_max': 66.7, 'gyro_mag_max': 6.1},
            timestamp: DateTime.now(),
          ),
          isSimulation: true,
        );
        break;
      case 'possible_fall':
        await triggerSensorDetectionVerification(
          DetectionResult(
            predictedCategory: 'fall_like',
            confidence: 0.89,
            detectionMethod: 'random_forest_on_device',
            reason:
                '[SIMULATION] Free-fall dip (0.31g) -> 3.9g impact -> 82 deg orientation shift -> stillness.',
            features: const {'acc_mag_max': 38.2, 'orientation_change_deg': 82.0},
            timestamp: DateTime.now(),
          ),
          isSimulation: true,
        );
        break;
      case 'unusual_movement':
        await triggerSensorDetectionVerification(
          DetectionResult(
            predictedCategory: 'unusual_movement',
            confidence: 0.81,
            detectionMethod: 'random_forest_on_device',
            reason: '[SIMULATION] Abnormal rotational tumble burst (5.7 rad/s).',
            features: const {'gyro_mag_max': 5.7},
            timestamp: DateTime.now(),
          ),
          isSimulation: true,
        );
        break;
      case 'missed_check_in':
        await triggerMissedCheckIn(isSimulation: true);
        break;
      case 'family_ack':
        if (incidents.isNotEmpty) {
          acknowledgeIncident(incidents.first.id,
              responderName: 'Primary Contact [SIMULATION]');
        }
        break;
      case 'escalation':
        if (incidents.isNotEmpty) {
          escalateIncident(incidents.first.id);
        }
        break;
      case 'user_cancel':
        if (pendingVerificationIncident != null) {
          await cancelPendingIncident();
        }
        break;
      case 'gps_unavailable':
        simulateGpsUnavailable = !simulateGpsUnavailable;
        await refreshLocation();
        break;
      case 'internet_unavailable':
        simulateOffline = !simulateOffline;
        notifyListeners();
        break;
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _verificationTimer?.cancel();
    _checkInTimer?.cancel();
    _escalationTimer?.cancel();
    sensorService.stopListening();
    super.dispose();
  }
}
