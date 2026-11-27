import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sosense_mobile/providers/app_state_provider.dart';
import 'package:sosense_mobile/screens/settings_screens.dart';
import 'package:sosense_mobile/screens/sos_screen.dart';
import 'package:sosense_mobile/widgets/verification_banner.dart';

void main() {
  testWidgets('Manual SOS screen renders prominent trigger button',
      (tester) async {
    final provider = AppStateProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: SosScreen()),
      ),
    );
    expect(find.text('TAP OR HOLD'), findsOneWidget);
    expect(find.text('Manual SOS'), findsOneWidget);
  });

  testWidgets('Demo Center runs simulation and shows verification banner',
      (tester) async {
    final provider = AppStateProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                VerificationBanner(),
                Expanded(child: DemoCenterScreen()),
              ],
            ),
          ),
        ),
      ),
    );

    await provider.runDemoScenario('possible_fall');
    await tester.pump();

    expect(find.textContaining('Possible Fall Detected'), findsWidgets);
    expect(find.text("I'm Safe"), findsOneWidget);
    expect(find.text('Confirm Emergency'), findsOneWidget);

    await provider.cancelPendingIncident();
    await tester.pump();
    expect(find.text("I'm Safe"), findsNothing);
  });
}
