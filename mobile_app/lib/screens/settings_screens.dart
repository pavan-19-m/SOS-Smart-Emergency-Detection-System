import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';

class SettingsScreen extends StatelessWidget {
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: !embedded,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: state.themeMode == ThemeMode.dark,
            onChanged: (_) => state.toggleThemeMode(),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync Offline Incident Queue'),
            subtitle: Text('Pending items: ${state.queuedOfflineCount}'),
            onTap: () async {
              await state.syncOfflineQueue();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Offline queue sync attempted.')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('Permission Center'),
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.permissionCenter),
          ),
          ListTile(
            leading: const Icon(Icons.science),
            title: const Text('Demo Mode Center'),
            onTap: () => Navigator.pushNamed(context, AppRoutes.demoCenter),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About SOSense & Model Disclosures'),
            onTap: () => Navigator.pushNamed(context, AppRoutes.aboutProject),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.emergencyRed),
            title: const Text('Sign Out',
                style: TextStyle(color: AppTheme.emergencyRed)),
            onTap: () async {
              await state.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRoutes.welcome, (_) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class PermissionCenterScreen extends StatefulWidget {
  const PermissionCenterScreen({super.key});

  @override
  State<PermissionCenterScreen> createState() => _PermissionCenterScreenState();
}

class _PermissionCenterScreenState extends State<PermissionCenterScreen> {
  PermissionStatus _locStatus = PermissionStatus.denied;
  PermissionStatus _notifStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final loc = await Permission.locationWhenInUse.status;
      final notif = await Permission.notification.status;
      if (mounted) {
        setState(() {
          _locStatus = loc;
          _notifStatus = notif;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Permission & Diagnostics Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Location Permission'),
              subtitle: Text('Current: ${_locStatus.name}'),
              trailing: ElevatedButton(
                onPressed: () async {
                  await state.locationService.requestPermission();
                  await _check();
                },
                child: const Text('Request'),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications (FCM) Permission'),
              subtitle: Text('Current: ${_notifStatus.name}'),
              trailing: ElevatedButton(
                onPressed: () async {
                  await Permission.notification.request();
                  await _check();
                },
                child: const Text('Request'),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sensors),
              title: const Text('Accelerometer & Gyroscope'),
              subtitle: Text(state.sensorService.sensorsAvailable
                  ? 'Supported by OS / hardware'
                  : 'Unavailable on this device'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.battery_alert),
              title: Text('Android Background Monitoring Note'),
              subtitle: Text(
                'Modern Android restricts background sensor polling when battery optimization is enabled. Exclude SOSense from battery optimization for reliable foreground monitoring.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DemoCenterScreen extends StatelessWidget {
  const DemoCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final scenarios = const [
      ('manual_sos', 'Manual SOS Drill', Icons.sos),
      ('possible_accident', 'Possible Accident Detection', Icons.car_crash),
      ('possible_fall', 'Possible Fall Detection', Icons.personal_injury),
      ('unusual_movement', 'Unusual Motion Anomaly', Icons.waves),
      ('missed_check_in', 'Missed Check-In Trigger', Icons.timer_off),
      ('family_ack', 'Simulate Family Acknowledgement', Icons.check_circle),
      ('escalation', 'Simulate Alert Escalation', Icons.trending_up),
      ('user_cancel', 'Simulate User Safe Cancel', Icons.cancel),
      ('gps_unavailable', 'Toggle GPS Unavailable', Icons.gps_off),
      ('internet_unavailable', 'Toggle Offline / No Internet', Icons.cloud_off),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Demo Center (Safe Sandbox)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningAmber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Demo Mode: All events triggered here are strictly labeled [SIMULATION] and NEVER send notifications to real emergency contacts.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          for (final s in scenarios)
            Card(
              child: ListTile(
                leading: Icon(s.$3, color: AppTheme.deepNavy),
                title: Text(s.$2),
                trailing: ElevatedButton(
                  onPressed: () async {
                    await state.runDemoScenario(s.$1);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Executed simulation: ${s.$2}')),
                      );
                    }
                  },
                  child: const Text('Run'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AboutProjectScreen extends StatelessWidget {
  const AboutProjectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About SOSense')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SOSense Architecture & ML Transparency',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text(
                    '• Track A (AI/ML): 50 Hz accelerometer + gyroscope windowing (2.56s), Butterworth filtering, 20 time-domain features, Rule-Based baseline, Random Forest on-device inference, and Isolation Forest anomaly benchmarks.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Track B (Data Analytics): UCI HAR real human activity corpus + clearly labeled controlled anomaly simulations, SQLite analytical queries, and Power BI 5-page dashboard exports.',
                  ),
                  SizedBox(height: 12),
                  Text('Honest Safety Disclaimer',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(AppConstants.honestSafetyDisclaimer),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
