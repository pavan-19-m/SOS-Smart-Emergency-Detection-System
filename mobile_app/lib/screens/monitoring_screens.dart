import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../models/user_profile.dart';
import '../providers/app_state_provider.dart';
import '../widgets/verification_banner.dart';

class MonitoringScreen extends StatelessWidget {
  final bool embedded;
  const MonitoringScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final sample = state.latestSensorSample;
    final det = state.latestDetection;
    final isMonitoring = state.sensorService.isMonitoring;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor & ML Monitoring'),
        automaticallyImplyLeading: !embedded,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.detectionSettings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const VerificationBanner(),
          const StatusBadgesBar(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monitoring Control',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    state.sensorService.sensorStatusMessage ??
                        'Tap Start to stream 50 Hz accelerometer & gyroscope windows.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMonitoring
                                ? AppTheme.warningAmber
                                : AppTheme.safetyGreen,
                          ),
                          onPressed: () => isMonitoring
                              ? state.stopSensorMonitoring()
                              : state.startSensorMonitoring(),
                          icon: Icon(
                              isMonitoring ? Icons.pause : Icons.play_arrow),
                          label: Text(isMonitoring
                              ? 'Pause Monitoring'
                              : 'Start Monitoring'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Note: Android OS battery optimization may pause background sensor listeners when the screen is off unless foreground service is permitted.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Filtered Sensor Telemetry',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  if (sample == null)
                    const Text(
                        'No live samples yet. Start monitoring or use Demo Center.')
                  else ...[
                    _MetricRow('Accelerometer X / Y / Z',
                        '${sample.ax.toStringAsFixed(2)} / ${sample.ay.toStringAsFixed(2)} / ${sample.az.toStringAsFixed(2)} m/s²'),
                    _MetricRow('Acceleration Magnitude',
                        '${sample.accMagnitude.toStringAsFixed(3)} m/s²'),
                    _MetricRow('Gyroscope X / Y / Z',
                        '${sample.gx.toStringAsFixed(2)} / ${sample.gy.toStringAsFixed(2)} / ${sample.gz.toStringAsFixed(2)} rad/s'),
                    _MetricRow('Rotation Magnitude',
                        '${sample.gyroMagnitude.toStringAsFixed(3)} rad/s'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('On-Device ML Inference Engine',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(state.mlService.isLoaded
                      ? 'Random Forest loaded (${state.mlService.treeCount} decision trees)'
                      : 'Rule-based fallback active (ML asset loading/unavailable)'),
                  if (det != null) ...[
                    const Divider(height: 20),
                    _MetricRow('Latest Classification', det.humanTitle),
                    _MetricRow('Confidence',
                        '${(det.confidence * 100).toStringAsFixed(1)}%'),
                    _MetricRow('Method', det.detectionMethod),
                    const SizedBox(height: 6),
                    Text('Reason: ${det.reason}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetricRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

class DetectionSettingsScreen extends StatelessWidget {
  const DetectionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final user = state.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sign in required.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detection & Alert Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Detection Sensitivity',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SegmentedButton<DetectionSensitivity>(
                    segments: const [
                      ButtonSegment(
                          value: DetectionSensitivity.low, label: Text('Low')),
                      ButtonSegment(
                          value: DetectionSensitivity.medium,
                          label: Text('Medium')),
                      ButtonSegment(
                          value: DetectionSensitivity.high,
                          label: Text('High')),
                    ],
                    selected: {user.sensitivity},
                    onSelectionChanged: (sel) => state.updateProfile(
                        user.copyWith(sensitivity: sel.first)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Smart Accident Candidate Detection'),
            subtitle: const Text(
                'Detects high-G impact + angular spike + stillness (does not guarantee all road crashes).'),
            value: user.accidentDetectionEnabled,
            onChanged: (v) =>
                state.updateProfile(user.copyWith(accidentDetectionEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('Possible Fall Detection'),
            subtitle: const Text(
                'Free-fall dip, impact peak, orientation change, and verification countdown.'),
            value: user.fallDetectionEnabled,
            onChanged: (v) =>
                state.updateProfile(user.copyWith(fallDetectionEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('Unusual Motion & Inactivity Anomaly Detection'),
            value: user.anomalyDetectionEnabled,
            onChanged: (v) =>
                state.updateProfile(user.copyWith(anomalyDetectionEnabled: v)),
          ),
          SwitchListTile(
            title: const Text('Background Monitoring Preference'),
            value: user.backgroundMonitoringEnabled,
            onChanged: (v) => state.updateProfile(
                user.copyWith(backgroundMonitoringEnabled: v)),
          ),
          const Divider(),
          ListTile(
            title: Text(
                'Verification Countdown: ${user.alertCountdownSeconds}s'),
            subtitle: Slider(
              min: 5,
              max: 45,
              divisions: 8,
              value: user.alertCountdownSeconds.toDouble(),
              label: '${user.alertCountdownSeconds}s',
              onChanged: (v) => state.updateProfile(
                  user.copyWith(alertCountdownSeconds: v.round())),
            ),
          ),
          ListTile(
            title: Text(
                'Escalation Delay to Secondary Contacts: ${user.escalationDelaySeconds}s'),
            subtitle: Slider(
              min: 30,
              max: 300,
              divisions: 9,
              value: user.escalationDelaySeconds.toDouble(),
              label: '${user.escalationDelaySeconds}s',
              onChanged: (v) => state.updateProfile(
                  user.copyWith(escalationDelaySeconds: v.round())),
            ),
          ),
        ],
      ),
    );
  }
}
