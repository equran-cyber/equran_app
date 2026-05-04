import 'package:equran/prayer/prayer_models.dart';
import 'package:geolocator/geolocator.dart';

enum PrayerLocationFailureReason {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

enum PrayerLocationPermissionStatus {
  denied,
  deniedForever,
  whileInUse,
  always,
}

class PrayerRawPosition {
  const PrayerRawPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class PrayerLocationResult {
  const PrayerLocationResult._({
    this.location,
    this.failureReason,
    this.message,
  });

  factory PrayerLocationResult.success(PrayerLocation location) {
    return PrayerLocationResult._(location: location);
  }

  factory PrayerLocationResult.failure({
    required PrayerLocationFailureReason reason,
    required String message,
  }) {
    return PrayerLocationResult._(failureReason: reason, message: message);
  }

  final PrayerLocation? location;
  final PrayerLocationFailureReason? failureReason;
  final String? message;

  bool get isSuccess => location != null;
}

abstract class PrayerPositionProvider {
  Future<bool> isLocationServiceEnabled();

  Future<PrayerLocationPermissionStatus> checkPermission();

  Future<PrayerLocationPermissionStatus> requestPermission();

  Future<PrayerRawPosition> getCurrentPosition();
}

class GeolocatorPrayerPositionProvider implements PrayerPositionProvider {
  const GeolocatorPrayerPositionProvider();

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<PrayerLocationPermissionStatus> checkPermission() async {
    return _mapPermission(await Geolocator.checkPermission());
  }

  @override
  Future<PrayerLocationPermissionStatus> requestPermission() async {
    return _mapPermission(await Geolocator.requestPermission());
  }

  @override
  Future<PrayerRawPosition> getCurrentPosition() async {
    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return PrayerRawPosition(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  PrayerLocationPermissionStatus _mapPermission(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.denied => PrayerLocationPermissionStatus.denied,
      LocationPermission.deniedForever =>
        PrayerLocationPermissionStatus.deniedForever,
      LocationPermission.whileInUse =>
        PrayerLocationPermissionStatus.whileInUse,
      LocationPermission.always => PrayerLocationPermissionStatus.always,
      LocationPermission.unableToDetermine =>
        PrayerLocationPermissionStatus.denied,
    };
  }
}

class PrayerLocationService {
  const PrayerLocationService({
    PrayerPositionProvider provider = const GeolocatorPrayerPositionProvider(),
  }) : _provider = provider;

  final PrayerPositionProvider _provider;

  Future<PrayerLocationResult> currentDeviceLocation() async {
    try {
      final bool serviceEnabled = await _provider.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return PrayerLocationResult.failure(
          reason: PrayerLocationFailureReason.servicesDisabled,
          message: 'Location services are disabled.',
        );
      }

      PrayerLocationPermissionStatus permission = await _provider
          .checkPermission();
      if (permission == PrayerLocationPermissionStatus.denied) {
        permission = await _provider.requestPermission();
      }

      if (permission == PrayerLocationPermissionStatus.denied) {
        return PrayerLocationResult.failure(
          reason: PrayerLocationFailureReason.permissionDenied,
          message: 'Location permission was denied.',
        );
      }

      if (permission == PrayerLocationPermissionStatus.deniedForever) {
        return PrayerLocationResult.failure(
          reason: PrayerLocationFailureReason.permissionDeniedForever,
          message:
              'Location permission is permanently denied. Enable it from app settings.',
        );
      }

      final PrayerRawPosition position = await _provider.getCurrentPosition();
      return PrayerLocationResult.success(
        PrayerLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          label: 'Current location',
          mode: PrayerLocationMode.currentDevice,
        ),
      );
    } catch (_) {
      return PrayerLocationResult.failure(
        reason: PrayerLocationFailureReason.unavailable,
        message: 'Unable to get your current location.',
      );
    }
  }

  String coordinateLabel(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}
