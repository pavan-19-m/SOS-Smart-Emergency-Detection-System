import 'package:geolocator/geolocator.dart';
import '../models/sensor_reading.dart';

class LocationService {
  LocationSnapshot? _lastKnown;

  LocationSnapshot? get lastKnown => _lastKnown;

  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  Future<bool> isGpsServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Retrieves live GPS coordinates with explicit staleness & accuracy tracking.
  /// Never marks stale cached coordinates as live.
  Future<LocationSnapshot> getCurrentLocation({bool simulateGpsUnavailable = false}) async {
    if (simulateGpsUnavailable) {
      return LocationSnapshot(
        latitude: _lastKnown?.latitude,
        longitude: _lastKnown?.longitude,
        accuracyMeters: _lastKnown?.accuracyMeters,
        updatedAt: _lastKnown?.updatedAt,
        isStale: true,
        statusLabel: 'gps_unavailable_simulated',
      );
    }

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return LocationSnapshot(
          latitude: _lastKnown?.latitude,
          longitude: _lastKnown?.longitude,
          accuracyMeters: _lastKnown?.accuracyMeters,
          updatedAt: _lastKnown?.updatedAt,
          isStale: true,
          statusLabel: 'gps_disabled',
        );
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return const LocationSnapshot(
          isStale: true,
          statusLabel: 'permission_denied',
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final isPoorAccuracy = pos.accuracy > 80.0;
      final snap = LocationSnapshot(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyMeters: pos.accuracy,
        updatedAt: DateTime.now(),
        isStale: false,
        statusLabel: isPoorAccuracy ? 'live_low_accuracy' : 'live',
      );
      _lastKnown = snap;
      return snap;
    } catch (_) {
      // Fallback to last known if available, explicitly marked stale
      if (_lastKnown != null) {
        return LocationSnapshot(
          latitude: _lastKnown!.latitude,
          longitude: _lastKnown!.longitude,
          accuracyMeters: _lastKnown!.accuracyMeters,
          updatedAt: _lastKnown!.updatedAt,
          isStale: true,
          statusLabel: 'last_known_stale',
        );
      }
      return const LocationSnapshot(
        isStale: true,
        statusLabel: 'unavailable',
      );
    }
  }
}
