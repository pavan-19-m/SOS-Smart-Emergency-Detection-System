import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../models/incident.dart';
import '../providers/app_state_provider.dart';

class IncidentHistoryScreen extends StatefulWidget {
  final bool embedded;
  const IncidentHistoryScreen({super.key, this.embedded = false});

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  String _search = '';
  String _filterType = 'all';
  bool _newestFirst = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    var filtered = state.incidents.where((inc) {
      if (_filterType == 'simulation' && !inc.isSimulation) return false;
      if (_filterType != 'all' &&
          _filterType != 'simulation' &&
          inc.eventType != _filterType) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return inc.id.toLowerCase().contains(q) ||
            inc.eventType.toLowerCase().contains(q) ||
            inc.detectionReason.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    filtered.sort((a, b) => _newestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident History'),
        automaticallyImplyLeading: !widget.embedded,
        actions: [
          IconButton(
            icon: Icon(_newestFirst ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: 'Toggle sort order',
            onPressed: () => setState(() => _newestFirst = !_newestFirst),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search incidents by ID, type, or reason...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final entry in const [
                  ('all', 'All'),
                  ('manual_sos', 'Manual SOS'),
                  ('possible_accident', 'Accident'),
                  ('possible_fall', 'Fall'),
                  ('missed_check_in', 'Missed Check-In'),
                  ('simulation', 'Simulations'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: _filterType == entry.$1,
                      onSelected: (_) => setState(() => _filterType = entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No matching incident records found.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final inc = filtered[i];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            inc.isFalseAlarm ||
                                    inc.status == IncidentStatus.cancelled
                                ? Icons.cancel_outlined
                                : Icons.emergency,
                            color: inc.status == IncidentStatus.acknowledged ||
                                    inc.status == IncidentStatus.resolved
                                ? AppTheme.safetyGreen
                                : AppTheme.emergencyRed,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text('${inc.id} • ${inc.eventType}'),
                              ),
                              if (inc.isSimulation)
                                const Chip(
                                  label: Text('SIM',
                                      style: TextStyle(fontSize: 10)),
                                  padding: EdgeInsets.zero,
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${DateFormat('yyyy-MM-dd HH:mm').format(inc.createdAt)} • Status: ${inc.statusApiValue}\n${inc.detectionReason}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.incidentDetail,
                            arguments: inc.id,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class IncidentDetailScreen extends StatelessWidget {
  const IncidentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    final state = context.watch<AppStateProvider>();
    final idx = state.incidents.indexWhere((i) => i.id == id);
    if (idx < 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Incident Detail')),
        body: const Center(child: Text('Incident not found.')),
      );
    }
    final inc = state.incidents[idx];

    return Scaffold(
      appBar: AppBar(
        title: Text(inc.id),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              state.deleteIncident(inc.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (inc.isSimulation)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'DEMO SIMULATION RECORD — External emergency contacts were NOT notified.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('Event Type', inc.eventType),
                  _kv('Status', inc.statusApiValue),
                  _kv('Trigger Source', inc.triggerSource),
                  _kv('Detection Method', inc.detectionMethod),
                  _kv('Confidence',
                      '${(inc.modelConfidence * 100).toStringAsFixed(1)}%'),
                  _kv('User Response', inc.userResponse),
                  _kv('Timestamp', inc.createdAt.toIso8601String()),
                  _kv('Notified Contacts',
                      inc.notifiedContactNames.isEmpty ? 'None' : inc.notifiedContactNames.join(', ')),
                  _kv('Acknowledged By', inc.acknowledgedBy ?? 'Pending'),
                  const Divider(),
                  Text('Reason: ${inc.detectionReason}'),
                  if (inc.dispatchMessage.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Dispatch: ${inc.dispatchMessage}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (inc.location.hasValidCoordinates)
            OutlinedButton.icon(
              onPressed: () {
                final url = inc.location.googleMapsUrl;
                if (url != null) launchUrl(Uri.parse(url));
              },
              icon: const Icon(Icons.map_outlined),
              label: Text(
                inc.location.isStale
                    ? 'Open Last Known Location (Stale)'
                    : 'Open Live Location in Maps',
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.safetyGreen),
                onPressed: () => state.acknowledgeIncident(inc.id),
                icon: const Icon(Icons.check),
                label: const Text('Acknowledge'),
              ),
              ElevatedButton.icon(
                onPressed: () => state.resolveIncident(inc.id),
                icon: const Icon(Icons.verified),
                label: const Text('Resolve'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    state.resolveIncident(inc.id, markFalseAlarm: true),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Mark False Alarm'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          Flexible(child: Text(v, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
