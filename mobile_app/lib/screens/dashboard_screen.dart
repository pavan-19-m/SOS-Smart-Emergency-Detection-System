import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';
import '../widgets/verification_banner.dart';
import 'incident_screens.dart';
import 'monitoring_screens.dart';
import 'settings_screens.dart';
import 'sos_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeOverviewTab(),
      const SosScreen(embedded: true),
      const MonitoringScreen(embedded: true),
      const IncidentHistoryScreen(embedded: true),
      const SettingsScreen(embedded: true),
    ];

    return Scaffold(
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.sos, color: AppTheme.emergencyRed), label: 'SOS'),
          NavigationDestination(icon: Icon(Icons.sensors), label: 'Monitor'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Incidents'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _HomeOverviewTab extends StatelessWidget {
  const _HomeOverviewTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final user = state.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('SOSense • ${user?.displayName ?? 'Safety Hub'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Demo Center',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.demoCenter),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const VerificationBanner(),
          const StatusBadgesBar(),
          const SizedBox(height: 16),
          // Quick Emergency SOS Card
          Card(
            color: AppTheme.emergencyRed,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pushNamed(context, AppRoutes.sos),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.emergency_share, color: Colors.white, size: 42),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manual SOS Control',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tap to trigger immediate or countdown emergency alert with GPS.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (state.activeSafetySession != null)
            Card(
              color: AppTheme.safetyGreen.withValues(alpha: 0.1),
              child: ListTile(
                leading: const Icon(Icons.timer, color: AppTheme.safetyGreen),
                title: Text(
                    'Active Check-In: ${state.activeSafetySession!.label}'),
                subtitle: Text(
                    'Status: ${state.activeSafetySession!.status.toUpperCase()}'),
                trailing: ElevatedButton(
                  onPressed: () => state.confirmCheckInSafe(),
                  child: const Text("I'm Safe"),
                ),
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.safeCheckIn),
              ),
            ),
          const SizedBox(height: 8),
          Text('Safety Modules',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _ModuleTile(
                icon: Icons.family_restroom,
                title: 'Family Contacts',
                subtitle: '${state.contacts.length} configured',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.familyContacts),
              ),
              _ModuleTile(
                icon: Icons.route,
                title: 'Safe Check-In',
                subtitle: state.activeSafetySession == null
                    ? 'Start trip'
                    : 'Session active',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.safeCheckIn),
              ),
              _ModuleTile(
                icon: Icons.my_location,
                title: 'GPS & Location',
                subtitle: state.currentLocation.statusLabel,
                onTap: () => Navigator.pushNamed(context, AppRoutes.location),
              ),
              _ModuleTile(
                icon: Icons.tune,
                title: 'Detection Rules',
                subtitle: 'Sensitivity: ${user?.sensitivity.name ?? 'medium'}',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.detectionSettings),
              ),
              _ModuleTile(
                icon: Icons.science,
                title: 'Demo Center',
                subtitle: '10 safe scenarios',
                onTap: () => Navigator.pushNamed(context, AppRoutes.demoCenter),
              ),
              _ModuleTile(
                icon: Icons.verified_user,
                title: 'Permissions',
                subtitle: 'GPS, Sensors, FCM',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.permissionCenter),
              ),
              _ModuleTile(
                icon: Icons.badge_outlined,
                title: 'Emergency Profile',
                subtitle: 'Medical & privacy',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.emergencyProfile),
              ),
              _ModuleTile(
                icon: Icons.map_outlined,
                title: 'Safety Map',
                subtitle: 'Historical awareness data',
                onTap: () => Navigator.pushNamed(context, AppRoutes.safetyMap),
              ),
              _ModuleTile(
                icon: Icons.info_outline,
                title: 'About SOSense',
                subtitle: 'ML & disclaimers',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.aboutProject),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
