import 'package:equran/prayer/prayer_location_service.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrayerLocationService', () {
    test(
      'returns current location when permission is already granted',
      () async {
        final PrayerLocationService service = PrayerLocationService(
          provider: _FakePositionProvider(
            permission: PrayerLocationPermissionStatus.whileInUse,
            position: const PrayerRawPosition(
              latitude: 12.34,
              longitude: 56.78,
            ),
          ),
        );

        final PrayerLocationResult result = await service
            .currentDeviceLocation();

        expect(result.isSuccess, true);
        expect(result.location?.latitude, 12.34);
        expect(result.location?.longitude, 56.78);
        expect(result.location?.label, 'Current device location');
        expect(result.location?.mode, PrayerLocationMode.currentDevice);
      },
    );

    test('requests permission when initially denied', () async {
      final _FakePositionProvider provider = _FakePositionProvider(
        permission: PrayerLocationPermissionStatus.denied,
        requestedPermission: PrayerLocationPermissionStatus.whileInUse,
        position: const PrayerRawPosition(latitude: 1.2, longitude: 3.4),
      );
      final PrayerLocationService service = PrayerLocationService(
        provider: provider,
      );

      final PrayerLocationResult result = await service.currentDeviceLocation();

      expect(provider.requested, true);
      expect(result.isSuccess, true);
    });

    test('handles disabled location services gracefully', () async {
      final PrayerLocationService service = PrayerLocationService(
        provider: _FakePositionProvider(serviceEnabled: false),
      );

      final PrayerLocationResult result = await service.currentDeviceLocation();

      expect(result.isSuccess, false);
      expect(
        result.failureReason,
        PrayerLocationFailureReason.servicesDisabled,
      );
    });

    test('handles permanently denied permission gracefully', () async {
      final PrayerLocationService service = PrayerLocationService(
        provider: _FakePositionProvider(
          permission: PrayerLocationPermissionStatus.deniedForever,
        ),
      );

      final PrayerLocationResult result = await service.currentDeviceLocation();

      expect(result.isSuccess, false);
      expect(
        result.failureReason,
        PrayerLocationFailureReason.permissionDeniedForever,
      );
    });
  });
}

class _FakePositionProvider implements PrayerPositionProvider {
  _FakePositionProvider({
    this.serviceEnabled = true,
    this.permission = PrayerLocationPermissionStatus.whileInUse,
    this.requestedPermission = PrayerLocationPermissionStatus.whileInUse,
    this.position = const PrayerRawPosition(latitude: 0, longitude: 0),
  });

  final bool serviceEnabled;
  PrayerLocationPermissionStatus permission;
  final PrayerLocationPermissionStatus requestedPermission;
  final PrayerRawPosition position;
  bool requested = false;

  @override
  Future<PrayerLocationPermissionStatus> checkPermission() async {
    return permission;
  }

  @override
  Future<PrayerRawPosition> getCurrentPosition() async {
    return position;
  }

  @override
  Future<bool> openAppSettings() async {
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    return true;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return serviceEnabled;
  }

  @override
  Future<PrayerLocationPermissionStatus> requestPermission() async {
    requested = true;
    permission = requestedPermission;
    return permission;
  }
}
