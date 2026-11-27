import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/incident.dart';

/// Persists incidents locally when internet/Firebase is unavailable and prevents
/// duplicate incident submissions during connectivity recovery.
class OfflineQueueService {
  static const String _queueKey = 'sosense_offline_incident_queue_v1';

  Future<List<Incident>> getQueuedIncidents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? const [];
    return raw
        .map((item) => Incident.fromMap(jsonDecode(item) as Map<String, dynamic>))
        .toList();
  }

  Future<void> enqueue(Incident incident) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getQueuedIncidents();
    if (existing.any((e) => e.id == incident.id)) {
      return; // Duplicate prevention
    }
    final updated = [...existing, incident];
    await prefs.setStringList(
      _queueKey,
      updated.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  Future<void> removeById(String incidentId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getQueuedIncidents();
    final filtered = existing.where((e) => e.id != incidentId).toList();
    await prefs.setStringList(
      _queueKey,
      filtered.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }
}
