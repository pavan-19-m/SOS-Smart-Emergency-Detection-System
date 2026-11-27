enum ContactPriority { primary, secondary }

class EmergencyContact {
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String email;
  final ContactPriority priority;
  final bool notifyOnSos;
  final bool notifyOnFall;
  final bool notifyOnMissedCheckIn;
  final bool isVerified;
  final String? linkedUid;
  final String lastAckStatus;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    this.priority = ContactPriority.primary,
    this.notifyOnSos = true,
    this.notifyOnFall = true,
    this.notifyOnMissedCheckIn = true,
    this.isVerified = false,
    this.linkedUid,
    this.lastAckStatus = 'none',
  });

  EmergencyContact copyWith({
    String? name,
    String? relationship,
    String? phone,
    String? email,
    ContactPriority? priority,
    bool? notifyOnSos,
    bool? notifyOnFall,
    bool? notifyOnMissedCheckIn,
    bool? isVerified,
    String? linkedUid,
    String? lastAckStatus,
  }) {
    return EmergencyContact(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      priority: priority ?? this.priority,
      notifyOnSos: notifyOnSos ?? this.notifyOnSos,
      notifyOnFall: notifyOnFall ?? this.notifyOnFall,
      notifyOnMissedCheckIn:
          notifyOnMissedCheckIn ?? this.notifyOnMissedCheckIn,
      isVerified: isVerified ?? this.isVerified,
      linkedUid: linkedUid ?? this.linkedUid,
      lastAckStatus: lastAckStatus ?? this.lastAckStatus,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'relationship': relationship,
        'phone': phone,
        'email': email,
        'priority': priority.name,
        'notifyOnSos': notifyOnSos,
        'notifyOnFall': notifyOnFall,
        'notifyOnMissedCheckIn': notifyOnMissedCheckIn,
        'isVerified': isVerified,
        'linkedUid': linkedUid,
        'lastAckStatus': lastAckStatus,
      };

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      relationship: map['relationship']?.toString() ?? 'Family',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      priority: map['priority'] == 'secondary'
          ? ContactPriority.secondary
          : ContactPriority.primary,
      notifyOnSos: map['notifyOnSos'] != false,
      notifyOnFall: map['notifyOnFall'] != false,
      notifyOnMissedCheckIn: map['notifyOnMissedCheckIn'] != false,
      isVerified: map['isVerified'] == true,
      linkedUid: map['linkedUid']?.toString(),
      lastAckStatus: map['lastAckStatus']?.toString() ?? 'none',
    );
  }
}
