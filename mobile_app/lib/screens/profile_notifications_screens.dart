import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';

class EmergencyProfileScreen extends StatefulWidget {
  const EmergencyProfileScreen({super.key});

  @override
  State<EmergencyProfileScreen> createState() => _EmergencyProfileScreenState();
}

class _EmergencyProfileScreenState extends State<EmergencyProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bloodCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final u = context.read<AppStateProvider>().currentUser;
    if (u != null) {
      _nameCtrl.text = u.displayName;
      _phoneCtrl.text = u.phone;
      _bloodCtrl.text = u.bloodGroup;
      _notesCtrl.text = u.medicalNotes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final user = state.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sign in required.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Profile & Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(labelText: 'Phone Number'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bloodCtrl,
            decoration:
                const InputDecoration(labelText: 'Blood Group (Optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Allergies / Medical Notes (Optional)'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              state.updateProfile(user.copyWith(
                displayName: _nameCtrl.text.trim(),
                phone: _phoneCtrl.text.trim(),
                bloodGroup: _bloodCtrl.text.trim(),
                medicalNotes: _notesCtrl.text.trim(),
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Emergency profile saved.')),
              );
            },
            child: const Text('Save Emergency Profile'),
          ),
          const Divider(height: 36),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.emergencyRed),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Account & Data?'),
                  content: const Text(
                      'This permanently removes your profile, contacts, and incidents.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emergencyRed),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await state.deleteAccount();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, AppRoutes.welcome, (_) => false);
                }
              }
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete Account & All User Data'),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final items = state.notifications;

    return Scaffold(
      appBar: AppBar(title: const Text('Family Notifications Log')),
      body: items.isEmpty
          ? const Center(
              child: Text(
                  'No notifications dispatched yet. Trigger SOS or test in Demo Center.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final n = items[i];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      n.acknowledged
                          ? Icons.mark_email_read
                          : Icons.notifications_active,
                      color: n.acknowledged
                          ? AppTheme.safetyGreen
                          : AppTheme.emergencyRed,
                    ),
                    title: Text(n.title),
                    subtitle: Text(
                      '${n.body}\n${DateFormat('HH:mm:ss').format(n.createdAt)} • ${n.priority.toUpperCase()} • ${n.deliveryState}',
                    ),
                    isThreeLine: true,
                    trailing: n.acknowledged
                        ? const Chip(label: Text('ACK'))
                        : TextButton(
                            onPressed: () =>
                                state.acknowledgeIncident(n.incidentId),
                            child: const Text('Acknowledge'),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
