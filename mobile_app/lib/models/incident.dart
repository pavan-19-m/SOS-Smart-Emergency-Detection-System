import 'sensor_reading.dart';

enum IncidentStatus {
  pendingVerification,
  active,
  dispatched,
  acknowledged,
  escalated,
  cancelled,
  resolved,
  falseAlarm,
  queuedOffline,
}

class Incident {
  final String id;
  final String userId;
  final String eventType; // manual_sos, possible_accident, possible_fall, unusual_movement, missed_check_in
  final String triggerSource; // user_button, sensor_pipeline, check_in_timer, demo_simulator
  final DateTime createdAt;
  final String detectionMethod;
  final String detectionReason;
  final double modelConfidence;
  final String userResponse; // pending, confirmed_emergency, i_am_safe, no_response_timeout
  final IncidentStatus status;
  final List<String> notifiedContactNames;
  final List<String> authorizedContactUids;
  final List<String> authorizedContactEmails;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final LocationSnapshot location;
  final bool isFalseAlarm;
  final bool isSimulation;
  final String dispatchMessage;
  final Map<String, double> sensorFeatureSnapshot;

  const Incident({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.triggerSource,
    required this.createdAt,
    required this.detectionMethod,
    required this.detectionReason,
    required this.modelConfidence,
    required this.userResponse,
    required this.status,
    this.notifiedContactNames = const [],
    this.authorizedContactUids = const [],
    this.authorizedContactEmails = const [],
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.location = const LocationSnapshot(),
    this.isFalseAlarm = false,
    this.isSimulation = false,
    this.dispatchMessage = '',
    this.sensorFeatureSnapshot = const {},
  });

  Incident copyWith({
    String? userResponse,
    IncidentStatus? status,
    List<String>? notifiedContactNames,
    String? acknowledgedBy,
    DateTime? acknowledgedAt,
    LocationSnapshot? location,
    bool? isFalseAlarm,
    String? dispatchMessage,
  }) {
    return Incident(
      id: id,
      userId: userId,
      eventType: eventType,
      triggerSource: triggerSource,
      createdAt: createdAt,
      detectionMethod: detectionMethod,
      detectionReason: detectionReason,
      modelConfidence: modelConfidence,
      userResponse: userResponse ?? this.userResponse,
      status: status ?? this.status,
      notifiedContactNames: notifiedContactNames ?? this.notifiedContactNames,
      authorizedContactUids: authorizedContactUids,
      authorizedContactEmails: authorizedContactEmails,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      location: location ?? this.location,
      isFalseAlarm: isFalseAlarm ?? this.isFalseAlarm,
      isSimulation: isSimulation,
      dispatchMessage: dispatchMessage ?? this.dispatchMessage,
      sensorFeatureSnapshot: sensorFeatureSnapshot,
    );
  }

  String get statusApiValue {
    switch (status) {
      case IncidentStatus.pendingVerification:
        return 'pending_verification';
      case IncidentStatus.active:
        return 'active';
      case IncidentStatus.dispatched:
        return 'dispatched';
      case IncidentStatus.acknowledged:
        return 'acknowledged';
      case IncidentStatus.escalated:
        return 'escalated';
      case IncidentStatus.cancelled:
        return 'cancelled';
      case IncidentStatus.resolved:
        return 'resolved';
      case IncidentStatus.falseAlarm:
        return 'false_alarm';
      case IncidentStatus.queuedOffline:
        return 'queued_offline';
    }
  }

  static IncidentStatus parseStatus(String? val) {
    switch (val) {
      case 'pending_verification':
        return IncidentStatus.pendingVerification;
      case 'active':
        return IncidentStatus.active;
      case 'dispatched':
        return IncidentStatus.dispatched;
      case 'acknowledged':
        return IncidentStatus.acknowledged;
      case 'escalated':
        return IncidentStatus.escalated;
      case 'cancelled':
        return IncidentStatus.cancelled;
      case 'resolved':
        return IncidentStatus.resolved;
      case 'false_alarm':
        return IncidentStatus.falseAlarm;
      case 'queued_offline':
        return IncidentStatus.queuedOffline;
      default:
        return IncidentStatus.active;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'eventType': eventType,
        'triggerSource': triggerSource,
        'createdAt': createdAt.toIso8601String(),
        'detectionMethod': detectionMethod,
        'detectionReason': detectionReason,
        'modelConfidence': modelConfidence,
        'userResponse': userResponse,
        'status': statusApiValue,
        'notifiedContactNames': notifiedContactNames,
        'authorizedContactUids': authorizedContactUids,
        'authorizedContactEmails': authorizedContactEmails,
        'acknowledgedBy': acknowledgedBy,
        'acknowledgedAt': acknowledgedAt?.toIso8601String(),
        'location': location.toMap(),
        'isFalseAlarm': isFalseAlarm,
        'isSimulation': isSimulation,
        'dispatchMessage': dispatchMessage,
        'sensorFeatureSnapshot': sensorFeatureSnapshot,
      };

  factory Incident.fromMap(Map<String, dynamic> map) {
    final rawFeatures = map['sensorFeatureSnapshot'];
    final parsedFeatures = <String, double>{};
    if (rawFeatures is Map) {
      rawFeatures.forEach((k, v) {
        if (v is num) parsedFeatures[k.toString()] = v.toDouble();
      });
    }
    return Incident(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      eventType: map['eventType']?.toString() ?? 'manual_sos',
      triggerSource: map['triggerSource']?.toString() ?? 'user_button',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      detectionMethod: map['detectionMethod']?.toString() ?? 'manual',
      detectionReason: map['detectionReason']?.toString() ?? '',
      modelConfidence: (map['modelConfidence'] as num?)?.toDouble() ?? 1.0,
      userResponse: map['userResponse']?.toString() ?? 'pending',
      status: parseStatus(map['status']?.toString()),
      notifiedContactNames: List<String>.from(
        (map['notifiedContactNames'] as List?) ?? const [],
      ),
      authorizedContactUids: List<String>.from(
        (map['authorizedContactUids'] as List?) ?? const [],
      ),
      authorizedContactEmails: List<String>.from(
        (map['authorizedContactEmails'] as List?) ?? const [],
      ),
      acknowledgedBy: map['acknowledgedBy']?.toString(),
      acknowledgedAt: map['acknowledgedAt'] != null
          ? DateTime.tryParse(map['acknowledgedAt'].toString())
          : null,
      location: LocationSnapshot.fromMap(
        map['location'] is Map<String, dynamic>
            ? map['location'] as Map<String, dynamic>
            : null,
      ),
      isFalseAlarm: map['isFalseAlarm'] == true,
      isSimulation: map['isSimulation'] == true,
      dispatchMessage: map['dispatchMessage']?.toString() ?? '',
      sensorFeatureSnapshot: parsedFeatures,
    );
  }
}
