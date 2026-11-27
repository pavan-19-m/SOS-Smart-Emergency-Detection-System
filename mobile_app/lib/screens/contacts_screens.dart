import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../models/emergency_contact.dart';
import '../providers/app_state_provider.dart';
import '../services/auth_service.dart';

class FamilyContactsScreen extends StatelessWidget {
  const FamilyContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final contacts = state.contacts;

    return Scaffold(
      appBar: AppBar(title: const Text('Family & Emergency Contacts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.addContact),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Contact'),
      ),
      body: contacts.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No trusted contacts added yet. Add at least one primary contact to receive emergency alerts.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: contacts.length,
              itemBuilder: (ctx, idx) {
                final c = contacts[idx];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: c.priority == ContactPriority.primary
                          ? AppTheme.emergencyRed
                          : AppTheme.deepNavy,
                      child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(c.name)),
                        Chip(
                          label: Text(c.priority.name.toUpperCase(),
                              style: const TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${c.relationship} • ${c.phone}\n${c.email} • ${c.isVerified ? "Verified" : "Unverified"}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') {
                          Navigator.pushNamed(context, AppRoutes.addContact,
                              arguments: c);
                        } else if (action == 'verify') {
                          state.addOrUpdateContact(
                              c.copyWith(isVerified: !c.isVerified));
                        } else if (action == 'delete') {
                          state.removeContact(c.id);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                            value: 'verify',
                            child: Text(c.isVerified
                                ? 'Mark Unverified'
                                : 'Mark Verified')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Remove')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _relCtrl = TextEditingController(text: 'Family');
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  ContactPriority _priority = ContactPriority.primary;
  bool _notifySos = true;
  bool _notifyFall = true;
  bool _notifyCheckIn = true;
  EmergencyContact? _editing;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is EmergencyContact) {
      _editing = arg;
      _nameCtrl.text = arg.name;
      _relCtrl.text = arg.relationship;
      _phoneCtrl.text = arg.phone;
      _emailCtrl.text = arg.email;
      _priority = arg.priority;
      _notifySos = arg.notifyOnSos;
      _notifyFall = arg.notifyOnFall;
      _notifyCheckIn = arg.notifyOnMissedCheckIn;
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final contact = EmergencyContact(
      id: _editing?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      relationship: _relCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      priority: _priority,
      notifyOnSos: _notifySos,
      notifyOnFall: _notifyFall,
      notifyOnMissedCheckIn: _notifyCheckIn,
      isVerified: _editing?.isVerified ?? false,
    );
    context.read<AppStateProvider>().addOrUpdateContact(contact);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_editing == null ? 'Add Trusted Contact' : 'Edit Contact')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Contact Name'),
                validator: AuthService.validateName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _relCtrl,
                decoration: const InputDecoration(labelText: 'Relationship'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Relationship required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                validator: AuthService.validatePhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address'),
                validator: AuthService.validateEmail,
              ),
              const SizedBox(height: 16),
              SegmentedButton<ContactPriority>(
                segments: const [
                  ButtonSegment(
                      value: ContactPriority.primary,
                      label: Text('Primary Contact')),
                  ButtonSegment(
                      value: ContactPriority.secondary,
                      label: Text('Secondary (Escalation)')),
                ],
                selected: {_priority},
                onSelectionChanged: (s) =>
                    setState(() => _priority = s.first),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Notify on Manual SOS / Accident'),
                value: _notifySos,
                onChanged: (v) => setState(() => _notifySos = v),
              ),
              SwitchListTile(
                title: const Text('Notify on Possible Fall'),
                value: _notifyFall,
                onChanged: (v) => setState(() => _notifyFall = v),
              ),
              SwitchListTile(
                title: const Text('Notify on Missed Check-In'),
                value: _notifyCheckIn,
                onChanged: (v) => setState(() => _notifyCheckIn = v),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save Contact'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
