import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';

class VerificationBanner extends StatelessWidget {
  const VerificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final pending = state.pendingVerificationIncident;
    if (pending == null) return const SizedBox.shrink();

    final title = pending.eventType == 'possible_accident'
        ? 'Possible Accident Detected. Are you okay?'
        : (pending.eventType == 'possible_fall'
            ? 'Possible Fall Detected. Are you okay?'
            : 'Unusual Movement Detected. Are you okay?');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.emergencyRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.emergencyRed, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.emergencyRed, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emergencyRed,
                      ),
                ),
              ),
              if (pending.isSimulation)
                Chip(
                  label: const Text('SIMULATION',
                      style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: AppTheme.warningAmber,
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(pending.detectionReason),
          const SizedBox(height: 10),
          Text(
            'Auto-escalating in ${state.verificationSecondsLeft}s if no response...',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.safetyGreen,
                  ),
                  onPressed: () => state.cancelPendingIncident(),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("I'm Safe"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emergencyRed,
                  ),
                  onPressed: () => state.confirmPendingIncident(userResponded: true),
                  icon: const Icon(Icons.sos),
                  label: const Text('Confirm Emergency'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatusBadgesBar extends StatelessWidget {
  const StatusBadgesBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final monitoringActive = state.sensorService.isMonitoring;
    final online = state.effectiveOnline;
    final gpsOk = state.currentLocation.hasValidCoordinates &&
        !state.currentLocation.isStale;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(
          icon: monitoringActive ? Icons.sensors : Icons.sensors_off,
          label: monitoringActive ? 'Sensors Active' : 'Monitoring Paused',
          color: monitoringActive ? AppTheme.safetyGreen : AppTheme.warningAmber,
        ),
        _StatusChip(
          icon: online ? Icons.cloud_done : Icons.cloud_off,
          label: online ? 'Online' : 'Offline Mode',
          color: online ? AppTheme.safetyGreen : AppTheme.emergencyRed,
        ),
        _StatusChip(
          icon: gpsOk ? Icons.gps_fixed : Icons.gps_off,
          label: gpsOk
              ? 'GPS Ready'
              : 'GPS: ${state.currentLocation.statusLabel}',
          color: gpsOk ? AppTheme.safetyGreen : AppTheme.warningAmber,
        ),
        if (state.queuedOfflineCount > 0)
          _StatusChip(
            icon: Icons.queue,
            label: 'Queued: ${state.queuedOfflineCount}',
            color: AppTheme.warningAmber,
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
