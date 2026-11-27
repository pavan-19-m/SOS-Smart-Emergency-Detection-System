import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';
import '../widgets/verification_banner.dart';

class SosScreen extends StatefulWidget {
  final bool embedded;
  const SosScreen({super.key, this.embedded = false});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _useCountdown = true;
  int _countdown = 0;
  Timer? _timer;
  String? _lastDispatchFeedback;

  void _startSosFlow() {
    if (!_useCountdown) {
      _fireImmediateSos();
      return;
    }
    setState(() => _countdown = 5);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        setState(() => _countdown = 0);
        _fireImmediateSos();
      }
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    setState(() {
      _countdown = 0;
      _lastDispatchFeedback = 'SOS countdown cancelled by user.';
    });
  }

  Future<void> _fireImmediateSos() async {
    final state = context.read<AppStateProvider>();
    final inc = await state.triggerManualSos();
    if (!mounted) return;
    setState(() {
      _lastDispatchFeedback =
          '${inc.id} (${inc.statusApiValue}): ${inc.dispatchMessage}';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual SOS'),
        automaticallyImplyLeading: !widget.embedded,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StatusBadgesBar(),
            const SizedBox(height: 14),
            SwitchListTile(
              title: const Text('5-second confirmation countdown'),
              subtitle: const Text('Disable for zero-delay immediate SOS'),
              value: _useCountdown,
              onChanged: (v) => setState(() => _useCountdown = v),
            ),
            const Spacer(),
            Center(
              child: GestureDetector(
                onTap: _countdown == 0 ? _startSosFlow : null,
                onLongPress: _countdown == 0 ? _fireImmediateSos : null,
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _countdown > 0
                        ? AppTheme.warningAmber
                        : AppTheme.emergencyRed,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emergencyRed.withValues(alpha: 0.4),
                        blurRadius: 28,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sos, size: 64, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                        _countdown > 0 ? 'Sending in $_countdown' : 'TAP OR HOLD',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_countdown > 0)
              OutlinedButton.icon(
                onPressed: _cancelCountdown,
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel SOS Countdown'),
              ),
            const Spacer(),
            if (_lastDispatchFeedback != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_lastDispatchFeedback!)),
                    ],
                  ),
                ),
              ),
            if (!state.effectiveOnline)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Offline warning: SOS will be queued locally and cannot reach family contacts until connectivity returns.',
                  style: TextStyle(color: AppTheme.emergencyRed, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
