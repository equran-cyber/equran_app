import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_location_service.dart';
import 'package:equran/prayer/prayer_settings_store.dart';
import 'package:equran/prayer/prayer_times_page.dart';
import 'package:equran/prayer/prayer_times_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() async {
    await initSettingsTestHarness();
  });

  testWidgets('shows setup state when no location is selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      materialTestApp(
        PrayerTimesPage(
          enableLiveCountdown: false,
          initialNow: DateTime(2026, 5, 4, 10),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Prayer times need a location'), findsOneWidget);
    expect(
      find.textContaining('Your location is used only for local'),
      findsOneWidget,
    );
    expect(find.text('Use current location'), findsOneWidget);
    expect(find.text('Choose on map'), findsOneWidget);
    expect(find.text('Enter coordinates manually'), findsOneWidget);
    expect(find.text('Fajr'), findsNothing);
    expect(
      find.textContaining('Prayer times are currently experimental'),
      findsOneWidget,
    );
  });

  testWidgets('renders calculated prayer times after location is selected', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() {
      return PrayerSettingsStore().saveLocation(
        const PrayerLocation(
          latitude: 35.78056,
          longitude: -78.6389,
          label: 'Test location',
          mode: PrayerLocationMode.manual,
        ),
      );
    });

    await tester.pumpWidget(
      materialTestApp(
        PrayerTimesPage(
          enableLiveCountdown: false,
          initialNow: DateTime(2026, 5, 4, 10),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Test location'), findsOneWidget);
    expect(find.text('Next prayer'), findsOneWidget);
    expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
    expect(find.textContaining('Calculated locally'), findsWidgets);
    expect(find.text('Fajr'), findsWidgets);
    expect(find.text('Sunrise'), findsWidgets);
    expect(find.text('Dhuhr'), findsWidgets);
    expect(find.text('Asr'), findsWidgets);
    expect(find.text('Maghrib'), findsWidgets);
    expect(find.text('Isha'), findsWidgets);
    expect(PrayerTimeKind.displayOrder.length, 6);
  });

  testWidgets('advances next prayer at the prayer-time boundary', (
    WidgetTester tester,
  ) async {
    const PrayerLocation location = PrayerLocation(
      latitude: 35.78056,
      longitude: -78.6389,
      label: 'Test location',
      mode: PrayerLocationMode.manual,
    );
    final PrayerDay day = const PrayerTimesService().calculateDay(
      date: DateTime(2026, 5, 4),
      location: location,
      settings: PrayerTimeSettings.defaults(),
    );
    final DateTime dhuhrTime = day.entryFor(PrayerTimeKind.dhuhr).time;
    final DateTime displayedDhuhrMinute = DateTime(
      dhuhrTime.year,
      dhuhrTime.month,
      dhuhrTime.day,
      dhuhrTime.hour,
      dhuhrTime.minute,
    );

    await tester.runAsync(() {
      return PrayerSettingsStore().saveLocation(location);
    });

    await tester.pumpWidget(
      materialTestApp(
        PrayerTimesPage(
          enableLiveCountdown: false,
          initialNow: displayedDhuhrMinute,
        ),
      ),
    );
    await tester.pump();

    final Text heroTitle = tester.widget<Text>(
      find.byKey(const Key('next_prayer_title')),
    );
    expect(heroTitle.textSpan?.toPlainText(), startsWith('Asr  '));
    expect(find.text('Now'), findsNothing);
  });

  testWidgets('saves a map-selected location through injected picker', (
    WidgetTester tester,
  ) async {
    bool pickerCalled = false;

    await tester.pumpWidget(
      materialTestApp(
        PrayerTimesPage(
          enableLiveCountdown: false,
          initialNow: DateTime(2026, 5, 4, 10),
          locationService: PrayerLocationService(
            reverseGeocoder:
                _FakeReverseGeocoder(const <PrayerAddressPlacemark>[
                  PrayerAddressPlacemark(
                    locality: 'Makkah',
                    country: 'Saudi Arabia',
                    isoCountryCode: 'SA',
                  ),
                ]),
          ),
          mapLocationPicker:
              (BuildContext context, PrayerLocation? initialLocation) async {
                pickerCalled = true;
                return const PrayerLocation(
                  latitude: 12.34567,
                  longitude: 76.54321,
                  label: 'Selected location',
                  mode: PrayerLocationMode.manual,
                );
              },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Choose on map'));
    await tester.pump(const Duration(milliseconds: 250));

    final PrayerLocation? saved = PrayerSettingsStore().getLocation();
    expect(pickerCalled, true);
    expect(saved?.latitude, 12.34567);
    expect(saved?.longitude, 76.54321);
    expect(saved?.label, 'Makkah, Saudi Arabia');
    expect(saved?.countryCode, 'SA');
    expect(find.text('Makkah, Saudi Arabia'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('uses friendly location label and keeps coordinates in details', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() {
      return PrayerSettingsStore().saveLocation(
        const PrayerLocation(
          latitude: 35.78056,
          longitude: -78.6389,
          label: '35.7806, -78.6389',
          mode: PrayerLocationMode.manual,
        ),
      );
    });

    await tester.pumpWidget(
      materialTestApp(
        PrayerTimesPage(
          enableLiveCountdown: false,
          initialNow: DateTime(2026, 5, 4, 10),
          locationService: PrayerLocationService(
            reverseGeocoder:
                _FakeReverseGeocoder(const <PrayerAddressPlacemark>[
                  PrayerAddressPlacemark(
                    locality: 'Makkah',
                    country: 'Saudi Arabia',
                    isoCountryCode: 'SA',
                  ),
                ]),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Saved location'), findsOneWidget);
    expect(find.text('35.7806, -78.6389'), findsNothing);

    await tester.tap(find.byKey(const Key('prayer_location_summary')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Location details'), findsOneWidget);
    expect(find.text('Advanced coordinates'), findsOneWidget);
    expect(find.text('Latitude'), findsNothing);
    expect(find.text('Longitude'), findsNothing);
    expect(find.text('Choose on map'), findsOneWidget);
    expect(find.text('Enter coordinates manually'), findsNothing);
    expect(find.text('Clear location'), findsNothing);

    Navigator.of(tester.element(find.text('Location details'))).pop();
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('edits saved location fields inline', (
    WidgetTester tester,
  ) async {
    final PrayerLocationService locationService = PrayerLocationService(
      reverseGeocoder: _FakeReverseGeocoder(const <PrayerAddressPlacemark>[
        PrayerAddressPlacemark(
          locality: 'Makkah',
          country: 'Saudi Arabia',
          isoCountryCode: 'SA',
        ),
      ]),
    );

    await tester.runAsync(() {
      return PrayerSettingsStore().saveLocation(
        const PrayerLocation(
          latitude: 35.78056,
          longitude: -78.6389,
          label: 'Test location',
          mode: PrayerLocationMode.manual,
        ),
      );
    });

    await tester.pumpWidget(
      materialTestApp(
        PrayerTimesPage(
          enableLiveCountdown: false,
          initialNow: DateTime(2026, 5, 4, 10),
          locationService: locationService,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('prayer_location_summary')));
    await tester.pump(const Duration(milliseconds: 250));

    await _expandAdvancedCoordinates(tester);
    await tester.enterText(find.byType(TextFormField).at(1), '12.34567');
    await tester.enterText(find.byType(TextFormField).at(2), '76.54321');
    await tester.tap(find.text('Save changes'));
    await tester.pump(const Duration(milliseconds: 250));

    final PrayerLocation? saved = PrayerSettingsStore().getLocation();
    expect(saved?.label, 'Makkah, Saudi Arabia');
    expect(saved?.latitude, 12.34567);
    expect(saved?.longitude, 76.54321);
    expect(saved?.mode, PrayerLocationMode.manual);
    expect(saved?.countryCode, 'SA');
    expect(find.text('Makkah, Saudi Arabia'), findsOneWidget);
  });

  testWidgets('coordinate edit with custom label preserves explicit override', (
    WidgetTester tester,
  ) async {
    final _FakeReverseGeocoder reverseGeocoder = _FakeReverseGeocoder(
      const <PrayerAddressPlacemark>[
        PrayerAddressPlacemark(locality: 'Makkah', country: 'Saudi Arabia'),
      ],
    );
    await tester.runAsync(() {
      return PrayerSettingsStore().saveLocation(
        const PrayerLocation(
          latitude: 35.78056,
          longitude: -78.6389,
          label: 'Test location',
          mode: PrayerLocationMode.manual,
        ),
      );
    });

    await tester.pumpWidget(
      materialTestApp(
        PrayerTimesPage(
          enableLiveCountdown: false,
          initialNow: DateTime(2026, 5, 4, 10),
          locationService: PrayerLocationService(
            reverseGeocoder: reverseGeocoder,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('prayer_location_summary')));
    await tester.pump(const Duration(milliseconds: 250));

    await _expandAdvancedCoordinates(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Edited place');
    await tester.enterText(find.byType(TextFormField).at(1), '12.34567');
    await tester.enterText(find.byType(TextFormField).at(2), '76.54321');
    await tester.tap(find.text('Save changes'));
    await tester.pump(const Duration(milliseconds: 250));

    final PrayerLocation? saved = PrayerSettingsStore().getLocation();
    expect(saved?.label, 'Edited place');
    expect(saved?.latitude, 12.34567);
    expect(saved?.longitude, 76.54321);
    expect(reverseGeocoder.calls, 1);
    expect(find.text('Edited place'), findsOneWidget);
  });

  testWidgets('preserves manual label edits when coordinates do not change', (
    WidgetTester tester,
  ) async {
    final _FakeReverseGeocoder reverseGeocoder = _FakeReverseGeocoder(
      const <PrayerAddressPlacemark>[
        PrayerAddressPlacemark(locality: 'Resolved City', country: 'Oman'),
      ],
    );
    await tester.runAsync(() {
      return PrayerSettingsStore().saveLocation(
        const PrayerLocation(
          latitude: 35.78056,
          longitude: -78.6389,
          label: 'Test location',
          mode: PrayerLocationMode.manual,
          countryCode: 'US',
        ),
      );
    });

    await tester.pumpWidget(
      materialTestApp(
        PrayerTimesPage(
          enableLiveCountdown: false,
          initialNow: DateTime(2026, 5, 4, 10),
          locationService: PrayerLocationService(
            reverseGeocoder: reverseGeocoder,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('prayer_location_summary')));
    await tester.pump(const Duration(milliseconds: 250));

    await _expandAdvancedCoordinates(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Edited place');
    await tester.tap(find.text('Save changes'));
    await tester.pump(const Duration(milliseconds: 250));

    final PrayerLocation? saved = PrayerSettingsStore().getLocation();
    expect(saved?.label, 'Edited place');
    expect(saved?.latitude, 35.78056);
    expect(saved?.longitude, -78.6389);
    expect(saved?.countryCode, 'US');
    expect(reverseGeocoder.calls, 0);
    expect(find.text('Edited place'), findsOneWidget);
  });
}

Future<void> _expandAdvancedCoordinates(WidgetTester tester) async {
  await tester.tap(find.text('Advanced coordinates'));
  await tester.pump(const Duration(milliseconds: 250));
}

class _FakeReverseGeocoder implements PrayerReverseGeocoder {
  _FakeReverseGeocoder(this.placemarks);

  final List<PrayerAddressPlacemark> placemarks;
  int calls = 0;

  @override
  Future<List<PrayerAddressPlacemark>> placemarksFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    calls += 1;
    return placemarks;
  }
}
