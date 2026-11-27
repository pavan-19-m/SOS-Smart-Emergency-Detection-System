enum DetectionSensitivity { low, medium, high }

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String phone;
  final bool emailVerified;
  final DetectionSensitivity sensitivity;
  final int alertCountdownSeconds;
  final int checkInIntervalMinutes;
  final int escalationDelaySeconds;
  final bool fallDetectionEnabled;
  final bool accidentDetectionEnabled;
  final bool anomalyDetectionEnabled;
  final bool backgroundMonitoringEnabled;
  final String bloodGroup;
  final String medicalNotes;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.phone = '',
    this.emailVerified = false,
    this.sensitivity = DetectionSensitivity.medium,
    this.alertCountdownSeconds = 15,
    this.checkInIntervalMinutes = 30,
    this.escalationDelaySeconds = 120,
    this.fallDetectionEnabled = true,
    this.accidentDetectionEnabled = true,
    this.anomalyDetectionEnabled = true,
    this.backgroundMonitoringEnabled = true,
    this.bloodGroup = '',
    this.medicalNotes = '',
  });

  UserProfile copyWith({
    String? displayName,
    String? phone,
    bool? emailVerified,
    DetectionSensitivity? sensitivity,
    int? alertCountdownSeconds,
    int? checkInIntervalMinutes,
    int? escalationDelaySeconds,
    bool? fallDetectionEnabled,
    bool? accidentDetectionEnabled,
    bool? anomalyDetectionEnabled,
    bool? backgroundMonitoringEnabled,
    String? bloodGroup,
    String? medicalNotes,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email,
      phone: phone ?? this.phone,
      emailVerified: emailVerified ?? this.emailVerified,
      sensitivity: sensitivity ?? this.sensitivity,
      alertCountdownSeconds:
          alertCountdownSeconds ?? this.alertCountdownSeconds,
      checkInIntervalMinutes:
          checkInIntervalMinutes ?? this.checkInIntervalMinutes,
      escalationDelaySeconds:
          escalationDelaySeconds ?? this.escalationDelaySeconds,
      fallDetectionEnabled: fallDetectionEnabled ?? this.fallDetectionEnabled,
      accidentDetectionEnabled:
          accidentDetectionEnabled ?? this.accidentDetectionEnabled,
      anomalyDetectionEnabled:
          anomalyDetectionEnabled ?? this.anomalyDetectionEnabled,
      backgroundMonitoringEnabled:
          backgroundMonitoringEnabled ?? this.backgroundMonitoringEnabled,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      medicalNotes: medicalNotes ?? this.medicalNotes,
    );
  }

  /// Never includes passwords or tokens in Firestore documents.
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'emailVerified': emailVerified,
        'sensitivity': sensitivity.name,
        'alertCountdownSeconds': alertCountdownSeconds,
        'checkInIntervalMinutes': checkInIntervalMinutes,
        'escalationDelaySeconds': escalationDelaySeconds,
        'fallDetectionEnabled': fallDetectionEnabled,
        'accidentDetectionEnabled': accidentDetectionEnabled,
        'anomalyDetectionEnabled': anomalyDetectionEnabled,
        'backgroundMonitoringEnabled': backgroundMonitoringEnabled,
        'bloodGroup': bloodGroup,
        'medicalNotes': medicalNotes,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? 'SOSense User',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      emailVerified: map['emailVerified'] == true,
      sensitivity: DetectionSensitivity.values.firstWhere(
        (e) => e.name == map['sensitivity'],
        orElse: () => DetectionSensitivity.medium,
      ),
      alertCountdownSeconds:
          (map['alertCountdownSeconds'] as num?)?.toInt() ?? 15,
      checkInIntervalMinutes:
          (map['checkInIntervalMinutes'] as num?)?.toInt() ?? 30,
      escalationDelaySeconds:
          (map['escalationDelaySeconds'] as num?)?.toInt() ?? 120,
      fallDetectionEnabled: map['fallDetectionEnabled'] != false,
      accidentDetectionEnabled: map['accidentDetectionEnabled'] != false,
      anomalyDetectionEnabled: map['anomalyDetectionEnabled'] != false,
      backgroundMonitoringEnabled: map['backgroundMonitoringEnabled'] != false,
      bloodGroup: map['bloodGroup']?.toString() ?? '',
      medicalNotes: map['medicalNotes']?.toString() ?? '',
    );
  }
}
