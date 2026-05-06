import 'package:equran/prayer/prayer_location_service.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_settings_store.dart';
import 'package:equran/prayer/qibla_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() async {
    await initSettingsTestHarness();
  });

  testWidgets(
    'falls back to saved manual coordinates when GPS is unavailable',
    (WidgetTester tester) async {
      await tester.runAsync(() {
        return PrayerSettingsStore().saveLocation(
          const PrayerLocation(
            latitude: 23.5880,
            longitude: 58.3829,
            label: 'Manual Muscat',
            mode: PrayerLocationMode.manual,
          ),
        );
      });

      await tester.pumpWidget(
        materialTestApp(
          const QiblaPage(
            locationService: PrayerLocationService(
              provider: _DisabledPositionProvider(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Manual Muscat'), findsOneWidget);
      expect(find.text('Saved prayer location'), findsWidgets);
      expect(find.text('Enter coordinates'), findsNothing);
      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
    },
  );
}

class _DisabledPositionProvider implements PrayerPositionProvider {
  const _DisabledPositionProvider();

  @override
  Future<PrayerLocationPermissionStatus> checkPermission() async {
    return PrayerLocationPermissionStatus.denied;
  }

  @override
  Future<PrayerRawPosition> getCurrentPosition() async {
    throw StateError('Location is disabled.');
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return false;
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
  Future<PrayerLocationPermissionStatus> requestPermission() async {
    return PrayerLocationPermissionStatus.denied;
  }
}
