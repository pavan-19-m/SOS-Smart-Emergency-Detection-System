import 'package:uuid/uuid.dart';
import '../models/emergency_contact.dart';
import '../models/incident.dart';
import '../models/safety_session.dart';

/// Handles alert message formatting, notification ledger creation,
/// Demo Mode isolation, and escalation policy selection.
class NotificationService {
  final Uuid _uuid = const Uuid();

  ({String title, String body}) formatMessage({
    required String userName,
    required String eventType,
  }) {
    switch (eventType) {
      case 'manual_sos':
        return (
          title: 'Emergency SOS Activated',
          body: 'Emergency SOS activated by $userName. Please check immediately.',
        );
      case 'possible_accident':
        return (
          title: 'Possible Accident Detected',
          body: 'Possible accident detected for $userName. Please check on the user.',
        );
      case 'possible_fall':
        return (
          title: 'Possible Fall Detected',
          body:
              'Possible fall detected for $userName. User did not respond to verification.',
        );
      case 'missed_check_in':
        return (
          title: 'Safety Check-In Missed',
          body: 'Safety check-in missed by $userName. Please verify their status.',
        );
      default:
        return (
          title: 'Unusual Motion Detected',
          body: 'Unusual movement anomaly detected for $userName.',
        );
    }
  }

  /// Dispatches notifications to primary contacts first (or secondary on escalation).
  /// Strictly blocks external delivery when `incident.isSimulation == true` or `isOnline == false`.
  ({
    List<AppNotification> createdNotifications,
    List<String> notifiedContactNames,
    String deliverySummary,
  }) buildDispatchBatch({
    required Incident incident,
    required String userName,
    required List<EmergencyContact> contacts,
    required bool isOnline,
    bool escalationOnly = false,
  }) {
    if (incident.isSimulation) {
      return (
        createdNotifications: const [],
        notifiedContactNames: const [],
        deliverySummary:
            'Demo Mode: external family notifications suppressed safely.',
      );
    }

    if (!isOnline) {
      return (
        createdNotifications: const [],
        notifiedContactNames: const [],
        deliverySummary:
            'Offline: incident queued locally; family notifications pending network.',
      );
    }

    final primary =
        contacts.where((c) => c.priority == ContactPriority.primary).toList();
    final secondary =
        contacts.where((c) => c.priority == ContactPriority.secondary).toList();

    final targets = escalationOnly
        ? secondary
        : (primary.isNotEmpty ? primary : contacts);

    if (targets.isEmpty) {
      return (
        createdNotifications: const [],
        notifiedContactNames: const [],
        deliverySummary: 'No emergency contacts configured.',
      );
    }

    final msg = formatMessage(
      userName: userName,
      eventType: incident.eventType,
    );
    final mapsUrl = incident.location.isStale
        ? null
        : incident.location.googleMapsUrl;

    final batch = <AppNotification>[];
    final names = <String>[];
    for (final c in targets) {
      names.add(c.name);
      batch.add(AppNotification(
        id: _uuid.v4(),
        incidentId: incident.id,
        title: escalationOnly ? '[ESCALATION] ${msg.title}' : msg.title,
        body: mapsUrl != null ? '${msg.body} Location: $mapsUrl' : msg.body,
        priority: c.priority.name,
        deliveryState: 'submitted_to_fcm',
        locationLink: mapsUrl,
        createdAt: DateTime.now(),
        isSimulation: false,
      ));
    }

    return (
      createdNotifications: batch,
      notifiedContactNames: names,
      deliverySummary:
          'Alert submitted to ${names.join(', ')} (awaiting acknowledgement).',
    );
  }
}
