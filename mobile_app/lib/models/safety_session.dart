class SafetySession {
  final String id;
  final String userId;
  final String label;
  final DateTime startedAt;
  final DateTime expectedArrivalAt;
  final int checkInIntervalMinutes;
  final DateTime nextCheckInDueAt;
  final int gracePeriodSeconds;
  final String status; // active, warning_grace, completed, missed
  final bool shareLiveLocation;
  final bool isSimulation;

  const SafetySession({
    required this.id,
    required this.userId,
    required this.label,
    required this.startedAt,
    required this.expectedArrivalAt,
    required this.checkInIntervalMinutes,
    required this.nextCheckInDueAt,
    this.gracePeriodSeconds = 60,
    this.status = 'active',
    this.shareLiveLocation = true,
    this.isSimulation = false,
  });

  SafetySession copyWith({
    DateTime? expectedArrivalAt,
    DateTime? nextCheckInDueAt,
    String? status,
  }) {
    return SafetySession(
      id: id,
      userId: userId,
      label: label,
      startedAt: startedAt,
      expectedArrivalAt: expectedArrivalAt ?? this.expectedArrivalAt,
      checkInIntervalMinutes: checkInIntervalMinutes,
      nextCheckInDueAt: nextCheckInDueAt ?? this.nextCheckInDueAt,
      gracePeriodSeconds: gracePeriodSeconds,
      status: status ?? this.status,
      shareLiveLocation: shareLiveLocation,
      isSimulation: isSimulation,
    );
  }
}

class AppNotification {
  final String id;
  final String incidentId;
  final String title;
  final String body;
  final String priority;
  final String deliveryState;
  final String? locationLink;
  final DateTime createdAt;
  final bool acknowledged;
  final bool isSimulation;

  const AppNotification({
    required this.id,
    required this.incidentId,
    required this.title,
    required this.body,
    required this.priority,
    required this.deliveryState,
    this.locationLink,
    required this.createdAt,
    this.acknowledged = false,
    this.isSimulation = false,
  });

  AppNotification copyWith({bool? acknowledged, String? deliveryState}) {
    return AppNotification(
      id: id,
      incidentId: incidentId,
      title: title,
      body: body,
      priority: priority,
      deliveryState: deliveryState ?? this.deliveryState,
      locationLink: locationLink,
      createdAt: createdAt,
      acknowledged: acknowledged ?? this.acknowledged,
      isSimulation: isSimulation,
    );
  }
}
