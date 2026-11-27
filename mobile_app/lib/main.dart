import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routes.dart';
import 'core/theme.dart';
import 'providers/app_state_provider.dart';
import 'screens/auth_screens.dart';
import 'screens/contacts_screens.dart';
import 'screens/dashboard_screen.dart';
import 'screens/incident_screens.dart';
import 'screens/location_checkin_screens.dart';
import 'screens/monitoring_screens.dart';
import 'screens/onboarding_screens.dart';
import 'screens/profile_notifications_screens.dart';
import 'screens/settings_screens.dart';
import 'screens/sos_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Runs safely in local/evaluator mode if google-services.json is not yet added.
  }
  runApp(const SosenseApp());
}

class SosenseApp extends StatelessWidget {
  final AppStateProvider? overrideProvider;
  const SosenseApp({super.key, this.overrideProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppStateProvider>(
      create: (_) => overrideProvider ?? AppStateProvider(),
      child: Consumer<AppStateProvider>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'SOSense',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.themeMode,
            initialRoute: AppRoutes.splash,
            routes: {
              AppRoutes.splash: (_) => const SplashScreen(),
              AppRoutes.welcome: (_) => const WelcomeScreen(),
              AppRoutes.login: (_) => const LoginScreen(),
              AppRoutes.register: (_) => const RegisterScreen(),
              AppRoutes.dashboard: (_) => const DashboardScreen(),
              AppRoutes.sos: (_) => const SosScreen(),
              AppRoutes.monitoring: (_) => const MonitoringScreen(),
              AppRoutes.detectionSettings: (_) =>
                  const DetectionSettingsScreen(),
              AppRoutes.familyContacts: (_) => const FamilyContactsScreen(),
              AppRoutes.addContact: (_) => const AddContactScreen(),
              AppRoutes.incidentHistory: (_) => const IncidentHistoryScreen(),
              AppRoutes.incidentDetail: (_) => const IncidentDetailScreen(),
              AppRoutes.location: (_) => const LocationScreen(),
              AppRoutes.safeCheckIn: (_) => const SafeCheckInScreen(),
              AppRoutes.emergencyProfile: (_) =>
                  const EmergencyProfileScreen(),
              AppRoutes.notifications: (_) => const NotificationsScreen(),
              AppRoutes.settings: (_) => const SettingsScreen(),
              AppRoutes.permissionCenter: (_) =>
                  const PermissionCenterScreen(),
              AppRoutes.demoCenter: (_) => const DemoCenterScreen(),
              AppRoutes.aboutProject: (_) => const AboutProjectScreen(),
            },
          );
        },
      ),
    );
  }
}
