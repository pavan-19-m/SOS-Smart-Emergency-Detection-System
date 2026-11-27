import 'package:flutter_test/flutter_test.dart';
import 'package:sosense_mobile/providers/app_state_provider.dart';

void main() {
  test('End-to-end simulated emergency lifecycle without hardware', () async {
    final state = AppStateProvider();
    await state.login(email: 'evaluator@sosense.dev', password: 'Password123');
    expect(state.isAuthenticated, isTrue);

    await state.runDemoScenario('possible_accident');
    expect(state.pendingVerificationIncident, isNotNull);

    await state.confirmPendingIncident(userResponded: true);
    expect(state.incidents.length, 1);
    expect(state.incidents.first.isSimulation, isTrue);

    await state.runDemoScenario('family_ack');
    expect(state.incidents.first.acknowledgedBy, contains('SIMULATION'));
  });
}
