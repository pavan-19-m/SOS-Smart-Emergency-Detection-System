import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';

class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final loc = state.currentLocation;

    return Scaffold(
      appBar: AppBar(title: const Text('GPS & Location Services')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          loc.hasValidCoordinates && !loc.isStale
                              ? Icons.gps_fixed
                              : Icons.gps_off,
                          color: loc.hasValidCoordinates && !loc.isStale
                              ? AppTheme.safetyGreen
                              : AppTheme.warningAmber,
                        ),
                        const SizedBox(width: 8),
                        Text('Status: ${loc.statusLabel}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                        'Latitude: ${loc.latitude?.toStringAsFixed(6) ?? "Unavailable"}'),
                    Text(
                        'Longitude: ${loc.longitude?.toStringAsFixed(6) ?? "Unavailable"}'),
                    Text(
                        'Accuracy: ${loc.accuracyMeters != null ? "${loc.accuracyMeters!.toStringAsFixed(1)} m" : "N/A"}'),
                    Text(
                        'Last Updated: ${loc.updatedAt?.toIso8601String() ?? "Never"}'),
                    if (loc.isStale)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Warning: Coordinates are stale or unavailable and are never displayed as live.',
                          style: TextStyle(color: AppTheme.warningAmber),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => state.refreshLocation(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Current GPS Location'),
            ),
            const SizedBox(height: 10),
            if (loc.googleMapsUrl != null)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(loc.googleMapsUrl!)),
                icon: const Icon(Icons.map),
                label: const Text('Open Coordinates in Google Maps'),
              ),
            const SizedBox(height: 16),
            const Text(
              'Privacy: Location coordinates are shared only with configured trusted contacts during an active emergency or safety check-in session.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class SafeCheckInScreen extends StatefulWidget {
  const SafeCheckInScreen({super.key});

  @override
  State<SafeCheckInScreen> createState() => _SafeCheckInScreenState();
}

class _SafeCheckInScreenState extends State<SafeCheckInScreen> {
  final _labelCtrl = TextEditingController(text: 'Late-Night Solo Commute');
  int _durationMin = 30;
  int _intervalMin = 10;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final session = state.activeSafetySession;

    return Scaffold(
      appBar: AppBar(title: const Text('Safe Check-In / Journey')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (session == null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Start Safety Session',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _labelCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Journey Label'),
                    ),
                    const SizedBox(height: 12),
                    Text('Expected Arrival Duration: $_durationMin min'),
                    Slider(
                      min: 10,
                      max: 180,
                      divisions: 17,
                      value: _durationMin.toDouble(),
                      onChanged: (v) =>
                          setState(() => _durationMin = v.round()),
                    ),
                    Text('Check-In Interval: $_intervalMin min'),
                    Slider(
                      min: 5,
                      max: 60,
                      divisions: 11,
                      value: _intervalMin.toDouble(),
                      onChanged: (v) =>
                          setState(() => _intervalMin = v.round()),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => state.startSafetySession(
                        label: _labelCtrl.text.trim().isEmpty
                            ? 'Safety Trip'
                            : _labelCtrl.text.trim(),
                        durationMinutes: _durationMin,
                        intervalMinutes: _intervalMin,
                      ),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Start Safe Check-In Session'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              color: session.status == 'warning_grace' ||
                      session.status == 'missed'
                  ? AppTheme.warningAmber.withValues(alpha: 0.15)
                  : AppTheme.safetyGreen.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.label,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Status: ${session.status.toUpperCase()}'),
                    Text(
                        'Expected Arrival: ${session.expectedArrivalAt.toLocal()}'),
                    Text('Next Check-In Due: ${session.nextCheckInDueAt.toLocal()}'),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.safetyGreen),
                          onPressed: () => state.confirmCheckInSafe(),
                          icon: const Icon(Icons.check),
                          label: const Text("Confirm I'm Safe"),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => state.extendSafetySession(15),
                          icon: const Icon(Icons.more_time),
                          label: const Text('Extend +15m'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => state.triggerMissedCheckIn(),
                          icon: const Icon(Icons.warning_amber),
                          label: const Text('Simulate Missed Grace'),
                        ),
                        TextButton(
                          onPressed: () => state.endSafetySession(),
                          child: const Text('End Session'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Note: A missed safety check-in triggers a grace warning and notifies contacts if unconfirmed. It does not prove a road accident occurred.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
