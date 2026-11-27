import 'dart:math' as math;

class SensorSample {
  final double ax;
  final double ay;
  final double az;
  final double gx;
  final double gy;
  final double gz;
  final DateTime timestamp;

  const SensorSample({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.timestamp,
  });

  double get accMagnitude => math.sqrt(ax * ax + ay * ay + az * az);
  double get gyroMagnitude => math.sqrt(gx * gx + gy * gy + gz * gz);
}

class LocationSnapshot {
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? updatedAt;
  final bool isStale;
  final String statusLabel;

  const LocationSnapshot({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.updatedAt,
    this.isStale = true,
    this.statusLabel = 'unavailable',
  });

  bool get hasValidCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite;

  String? get googleMapsUrl {
    if (!hasValidCoordinates) return null;
    return 'https://maps.google.com/?q=${latitude!.toStringAsFixed(6)},${longitude!.toStringAsFixed(6)}';
  }

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'updatedAt': updatedAt?.toIso8601String(),
        'isStale': isStale,
        'statusLabel': statusLabel,
      };

  factory LocationSnapshot.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const LocationSnapshot();
    return LocationSnapshot(
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
      isStale: map['isStale'] != false,
      statusLabel: map['statusLabel']?.toString() ?? 'unavailable',
    );
  }
}
