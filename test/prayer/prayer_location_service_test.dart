import 'package:equran/prayer/prayer_location_service.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_timezone_service.dart';
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
          reverseGeocoder: _FakeReverseGeocoder(const <PrayerAddressPlacemark>[
            PrayerAddressPlacemark(
              subLocality: 'Muttrah',
              locality: 'Muscat',
              administrativeArea: 'Muscat Governorate',
              country: 'Oman',
              isoCountryCode: 'om',
            ),
          ]),
          timezoneResolver: const _FakeTimezoneResolver('Asia/Muscat'),
        );

        final PrayerLocationResult result = await service
            .currentDeviceLocation();

        expect(result.isSuccess, true);
        expect(result.location?.latitude, 12.34);
        expect(result.location?.longitude, 56.78);
        expect(result.location?.label, 'Muttrah, Muscat');
        expect(result.location?.countryCode, 'OM');
        expect(result.location?.timezoneId, 'Asia/Muscat');
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
        reverseGeocoder: _FakeReverseGeocoder(const <PrayerAddressPlacemark>[
          PrayerAddressPlacemark(locality: 'Test City', country: 'Oman'),
        ]),
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

    test('resolves a short address from placemark locality data', () async {
      final PrayerLocationService service = PrayerLocationService(
        provider: _FakePositionProvider(),
        reverseGeocoder: _FakeReverseGeocoder(const <PrayerAddressPlacemark>[
          PrayerAddressPlacemark(
            locality: 'Manchester',
            administrativeArea: 'England',
            country: 'United Kingdom',
            isoCountryCode: 'GB',
          ),
        ]),
      );

      await expectLater(
        service.resolveShortAddress(53.4808, -2.2426),
        completion('Manchester, United Kingdom'),
      );
    });

    test('falls back to admin area when city data is unavailable', () {
      expect(
        shortPrayerAddressLabel(
          const PrayerAddressPlacemark(
            administrativeArea: 'Cairo Governorate',
            country: 'Egypt',
            isoCountryCode: 'EG',
          ),
        ),
        'Cairo Governorate',
      );
    });

    test('uses neighborhood with admin area when city is missing', () {
      expect(
        shortPrayerAddressLabel(
          const PrayerAddressPlacemark(
            subLocality: 'Al Rashidiya',
            administrativeArea: 'Ajman Emirate',
            country: 'United Arab Emirates',
          ),
        ),
        'Al Rashidiya, Ajman Emirate',
      );
    });

    test('coordinates save triggers short address resolution', () async {
      final _FakeReverseGeocoder reverseGeocoder =
          _FakeReverseGeocoder(const <PrayerAddressPlacemark>[
            PrayerAddressPlacemark(
              locality: 'Makkah',
              country: 'Saudi Arabia',
              isoCountryCode: 'SA',
            ),
          ]);
      final PrayerLocationService service = PrayerLocationService(
        provider: _FakePositionProvider(),
        reverseGeocoder: reverseGeocoder,
        timezoneResolver: const _FakeTimezoneResolver('Asia/Riyadh'),
      );

      final PrayerLocation location = await service.resolveLocationForSave(
        const PrayerLocation(
          latitude: 21.3891,
          longitude: 39.8579,
          label: 'Saved location',
          mode: PrayerLocationMode.manual,
        ),
      );

      expect(reverseGeocoder.calls, 1);
      expect(location.label, 'Makkah, Saudi Arabia');
      expect(location.countryCode, 'SA');
      expect(location.timezoneId, 'Asia/Riyadh');
    });

    test('timezone lookup failure falls back without crashing', () async {
      final PrayerLocationService service = PrayerLocationService(
        provider: _FakePositionProvider(),
        reverseGeocoder: _FakeReverseGeocoder(const <PrayerAddressPlacemark>[
          PrayerAddressPlacemark(locality: 'Manchester', country: 'UK'),
        ]),
        timezoneResolver: const _FakeTimezoneResolver(null),
      );

      final PrayerLocation location = await service.resolveLocationForSave(
        const PrayerLocation(
          latitude: 53.4808,
          longitude: -2.2426,
          label: 'Saved location',
          mode: PrayerLocationMode.manual,
        ),
      );

      expect(location.label, 'Manchester, UK');
      expect(location.timezoneId, isNull);
    });

    test('platform geocoder failure falls back to HTTP geocoder', () async {
      final CompositePrayerReverseGeocoder reverseGeocoder =
          CompositePrayerReverseGeocoder(
            platformGeocoder: _FakeReverseGeocoder(
              const <PrayerAddressPlacemark>[],
              throwOnLookup: true,
            ),
            httpGeocoder: _FakeReverseGeocoder(const <PrayerAddressPlacemark>[
              PrayerAddressPlacemark(
                subLocality: 'Muttrah',
                locality: 'Muscat',
                country: 'Oman',
                isoCountryCode: 'OM',
              ),
            ]),
          );
      final PrayerLocationService service = PrayerLocationService(
        provider: _FakePositionProvider(),
        reverseGeocoder: reverseGeocoder,
      );

      final PrayerLocation location = await service.resolveLocationForSave(
        const PrayerLocation(
          latitude: 23.6167,
          longitude: 58.5667,
          label: 'Saved location',
          mode: PrayerLocationMode.manual,
        ),
      );

      expect(location.label, 'Muttrah, Muscat');
      expect(location.countryCode, 'OM');
    });

    test('failed geocoding falls back gracefully', () async {
      final PrayerLocationService service = PrayerLocationService(
        provider: _FakePositionProvider(),
        reverseGeocoder: _FakeReverseGeocoder(
          const <PrayerAddressPlacemark>[],
          throwOnLookup: true,
        ),
      );

      final PrayerLocation mapLocation = await service.resolveLocationForSave(
        const PrayerLocation(
          latitude: 12.34567,
          longitude: 76.54321,
          label: 'Selected location',
          mode: PrayerLocationMode.manual,
        ),
      );
      final PrayerLocation customLocation = await service
          .resolveLocationForSave(
            const PrayerLocation(
              latitude: 12.34567,
              longitude: 76.54321,
              label: 'My masjid',
              mode: PrayerLocationMode.manual,
            ),
          );

      expect(mapLocation.label, 'Saved location');
      expect(customLocation.label, 'My masjid');
    });

    test(
      'manual label override is preserved when coordinates do not change',
      () async {
        final _FakeReverseGeocoder reverseGeocoder = _FakeReverseGeocoder(
          const <PrayerAddressPlacemark>[
            PrayerAddressPlacemark(locality: 'Resolved City', country: 'Oman'),
          ],
        );
        final PrayerLocationService service = PrayerLocationService(
          provider: _FakePositionProvider(),
          reverseGeocoder: reverseGeocoder,
        );
        const PrayerLocation previous = PrayerLocation(
          latitude: 23.6,
          longitude: 58.5,
          label: 'Old label',
          mode: PrayerLocationMode.manual,
          countryCode: 'OM',
        );

        final PrayerLocation labelOnly = await service.resolveLocationForSave(
          const PrayerLocation(
            latitude: 23.6,
            longitude: 58.5,
            label: 'Home',
            mode: PrayerLocationMode.manual,
            countryCode: 'OM',
          ),
          previousLocation: previous,
        );

        expect(labelOnly.label, 'Home');
        expect(labelOnly.countryCode, 'OM');
        expect(reverseGeocoder.calls, 0);
      },
    );

    test('coordinates changed does not reuse the old label', () async {
      final _FakeReverseGeocoder reverseGeocoder = _FakeReverseGeocoder(
        const <PrayerAddressPlacemark>[
          PrayerAddressPlacemark(locality: 'Resolved City', country: 'Oman'),
        ],
      );
      final PrayerLocationService service = PrayerLocationService(
        provider: _FakePositionProvider(),
        reverseGeocoder: reverseGeocoder,
      );
      const PrayerLocation previous = PrayerLocation(
        latitude: 23.6,
        longitude: 58.5,
        label: 'Old label',
        mode: PrayerLocationMode.manual,
        countryCode: 'OM',
      );

      final PrayerLocation moved = await service.resolveLocationForSave(
        const PrayerLocation(
          latitude: 23.61,
          longitude: 58.5,
          label: 'Old label',
          mode: PrayerLocationMode.manual,
        ),
        previousLocation: previous,
      );

      expect(moved.label, 'Resolved City, Oman');
      expect(moved.countryCode, isNull);
      expect(reverseGeocoder.calls, 1);
    });

    test('coordinates changed falls back without reusing old label', () async {
      final PrayerLocationService service = PrayerLocationService(
        provider: _FakePositionProvider(),
        reverseGeocoder: _FakeReverseGeocoder(
          const <PrayerAddressPlacemark>[],
          throwOnLookup: true,
        ),
      );
      const PrayerLocation previous = PrayerLocation(
        latitude: 23.6,
        longitude: 58.5,
        label: 'Old label',
        mode: PrayerLocationMode.manual,
        countryCode: 'OM',
      );

      final PrayerLocation moved = await service.resolveLocationForSave(
        const PrayerLocation(
          latitude: 23.61,
          longitude: 58.5,
          label: 'Old label',
          mode: PrayerLocationMode.manual,
        ),
        previousLocation: previous,
      );

      expect(moved.label, 'Saved location');
      expect(moved.countryCode, isNull);
    });

    test(
      'explicit label override is preserved after coordinates change',
      () async {
        final _FakeReverseGeocoder reverseGeocoder = _FakeReverseGeocoder(
          const <PrayerAddressPlacemark>[
            PrayerAddressPlacemark(locality: 'Resolved City', country: 'Oman'),
          ],
        );
        final PrayerLocationService service = PrayerLocationService(
          provider: _FakePositionProvider(),
          reverseGeocoder: reverseGeocoder,
        );
        const PrayerLocation previous = PrayerLocation(
          latitude: 23.6,
          longitude: 58.5,
          label: 'Old label',
          mode: PrayerLocationMode.manual,
          countryCode: 'OM',
        );

        final PrayerLocation moved = await service.resolveLocationForSave(
          const PrayerLocation(
            latitude: 23.61,
            longitude: 58.5,
            label: 'Home',
            mode: PrayerLocationMode.manual,
          ),
          previousLocation: previous,
          preserveCustomLabel: true,
        );

        expect(moved.label, 'Home');
        expect(moved.countryCode, isNull);
        expect(reverseGeocoder.calls, 1);
      },
    );

    test('generic existing label retries geocoding on save', () async {
      final _FakeReverseGeocoder reverseGeocoder =
          _FakeReverseGeocoder(const <PrayerAddressPlacemark>[
            PrayerAddressPlacemark(
              subLocality: 'Muttrah',
              locality: 'Muscat',
              country: 'Oman',
            ),
          ]);
      final PrayerLocationService service = PrayerLocationService(
        provider: _FakePositionProvider(),
        reverseGeocoder: reverseGeocoder,
      );

      final PrayerLocation location = await service.resolveLocationForSave(
        const PrayerLocation(
          latitude: 23.6167,
          longitude: 58.5667,
          label: 'Saved location',
          mode: PrayerLocationMode.manual,
        ),
        previousLocation: const PrayerLocation(
          latitude: 23.6167,
          longitude: 58.5667,
          label: 'Saved location',
          mode: PrayerLocationMode.manual,
        ),
      );

      expect(location.label, 'Muttrah, Muscat');
      expect(reverseGeocoder.calls, 1);
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

class _FakeReverseGeocoder implements PrayerReverseGeocoder {
  _FakeReverseGeocoder(this.placemarks, {this.throwOnLookup = false});

  final List<PrayerAddressPlacemark> placemarks;
  final bool throwOnLookup;
  int calls = 0;

  @override
  Future<List<PrayerAddressPlacemark>> placemarksFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    calls += 1;
    if (throwOnLookup) {
      throw Exception('reverse geocoding failed');
    }
    return placemarks;
  }
}

class _FakeTimezoneResolver implements PrayerTimezoneResolver {
  const _FakeTimezoneResolver(this.timezoneId);

  final String? timezoneId;

  @override
  String? timezoneIdForCoordinates(double latitude, double longitude) {
    return timezoneId;
  }
}
