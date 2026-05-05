import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_settings_store.dart';
import 'package:equran/prayer/prayer_times_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as timezone;

import '../helpers/test_harness.dart';

void main() {
  const PrayerTimesService service = PrayerTimesService();
  const PrayerLocation testLocation = PrayerLocation(
    latitude: 35.78056,
    longitude: -78.6389,
    label: 'Test location',
    mode: PrayerLocationMode.manual,
  );

  group('PrayerTimesService', () {
    test('selects sensible default methods from country codes', () {
      expect(
        service.bestMethodForLocation(
          const PrayerLocation(
            latitude: 25.2048,
            longitude: 55.2708,
            label: 'Test Gulf location',
            countryCode: 'AE',
            mode: PrayerLocationMode.manual,
          ),
        ),
        PrayerCalculationMethod.dubai,
      );
      expect(
        service.bestMethodForLocation(
          const PrayerLocation(
            latitude: 29.3759,
            longitude: 47.9774,
            label: 'Test Kuwait location',
            countryCode: 'KW',
            mode: PrayerLocationMode.manual,
          ),
        ),
        PrayerCalculationMethod.kuwait,
      );
      expect(
        service.bestMethodForLocation(
          const PrayerLocation(
            latitude: 40.7128,
            longitude: -74.0060,
            label: 'Test North America location',
            countryCode: 'US',
            mode: PrayerLocationMode.manual,
          ),
        ),
        PrayerCalculationMethod.northAmerica,
      );
      expect(
        service.bestMethodForLocation(testLocation),
        PrayerCalculationMethod.muslimWorldLeague,
      );
    });

    test('manual method overrides automatic location default', () {
      final PrayerTimeSettings settings = PrayerTimeSettings.defaults()
          .copyWith(method: PrayerCalculationMethod.ummAlQura);

      expect(
        service.effectiveMethodFor(location: testLocation, settings: settings),
        PrayerCalculationMethod.ummAlQura,
      );
    });

    test('formats compact calculation method labels', () {
      expect(
        prayerMethodDisplayLabel(
          settings: PrayerTimeSettings.defaults(),
          effectiveMethod: PrayerCalculationMethod.muslimWorldLeague,
        ),
        'MWL',
      );
      expect(
        prayerMethodDisplayLabel(
          settings: const PrayerTimeSettings(
            method: PrayerCalculationMethod.northAmerica,
          ),
          effectiveMethod: PrayerCalculationMethod.northAmerica,
        ),
        'ISNA',
      );
      expect(
        prayerMethodDisplayLabel(
          settings: const PrayerTimeSettings(
            method: PrayerCalculationMethod.custom,
          ),
          effectiveMethod: PrayerCalculationMethod.custom,
        ),
        'Custom',
      );
    });

    test('uses friendly location display labels', () {
      expect(
        const PrayerLocation(
          latitude: 12.34,
          longitude: 56.78,
          label: '12.3400, 56.7800',
          mode: PrayerLocationMode.currentDevice,
        ).displayLabel,
        'Saved location',
      );
      expect(
        const PrayerLocation(
          latitude: 12.34,
          longitude: 56.78,
          label: 'Home',
          mode: PrayerLocationMode.manual,
        ).displayLabel,
        'Home',
      );
    });

    test('calculates the six displayed timings only', () {
      final PrayerDay day = service.calculateDay(
        date: DateTime(2026, 5, 4),
        location: testLocation,
        settings: PrayerTimeSettings.defaults(),
      );

      expect(PrayerTimeKind.displayOrder.length, 6);
      expect(day.entries.length, 6);
      expect(
        day.entries.map((PrayerTimeEntry entry) => entry.kind).toList(),
        PrayerTimeKind.displayOrder,
      );
    });

    test('applies manual offsets after base prayer calculation', () {
      final DateTime date = DateTime(2026, 5, 4);
      final PrayerDay baseDay = service.calculateDay(
        date: date,
        location: testLocation,
        settings: PrayerTimeSettings.defaults(),
      );
      const PrayerOffsets offsets = PrayerOffsets(
        fajr: 7,
        sunrise: -2,
        dhuhr: 3,
        asr: 4,
        maghrib: -5,
        isha: 8,
      );
      final PrayerDay adjustedDay = service.calculateDay(
        date: date,
        location: testLocation,
        settings: const PrayerTimeSettings(offsets: offsets),
      );

      for (final PrayerTimeKind kind in PrayerTimeKind.displayOrder) {
        expect(
          adjustedDay.entryFor(kind).time,
          baseDay
              .entryFor(kind)
              .time
              .add(Duration(minutes: offsets.forPrayer(kind))),
        );
      }
    });

    test('Hanafi Asr is later than standard Asr', () {
      final PrayerDay standardDay = service.calculateDay(
        date: DateTime(2026, 5, 4),
        location: testLocation,
        settings: const PrayerTimeSettings(asrMethod: PrayerAsrMethod.standard),
      );
      final PrayerDay hanafiDay = service.calculateDay(
        date: DateTime(2026, 5, 4),
        location: testLocation,
        settings: const PrayerTimeSettings(asrMethod: PrayerAsrMethod.hanafi),
      );

      expect(
        hanafiDay
            .entryFor(PrayerTimeKind.asr)
            .time
            .isAfter(standardDay.entryFor(PrayerTimeKind.asr).time),
        true,
      );
    });

    test('round-trips custom settings serialization', () {
      const PrayerTimeSettings settings = PrayerTimeSettings(
        method: PrayerCalculationMethod.custom,
        customFajrAngle: 16.5,
        customIshaAngle: 14.2,
        customIshaInterval: 90,
        customMaghribAngle: 4.5,
        asrMethod: PrayerAsrMethod.hanafi,
        offsets: PrayerOffsets(
          fajr: 1,
          sunrise: 2,
          dhuhr: 3,
          asr: 4,
          maghrib: 5,
          isha: 6,
        ),
        use24HourFormat: true,
        useLocationTimezone: false,
        reminderSettings: const PrayerReminderSettings(remindersEnabled: true),
      );

      final PrayerTimeSettings restored = PrayerTimeSettings.fromJson(
        settings.toJson(),
      );

      expect(restored.method, PrayerCalculationMethod.custom);
      expect(restored.customFajrAngle, 16.5);
      expect(restored.customIshaAngle, 14.2);
      expect(restored.customIshaInterval, 90);
      expect(restored.customMaghribAngle, 4.5);
      expect(restored.asrMethod, PrayerAsrMethod.hanafi);
      expect(restored.offsets.asr, 4);
      expect(restored.use24HourFormat, true);
      expect(restored.useLocationTimezone, false);
      expect(restored.reminderSettings.remindersEnabled, true);
    });

    test('default notification and timezone settings are safe', () {
      final PrayerTimeSettings settings = PrayerTimeSettings.defaults();

      expect(settings.useLocationTimezone, true);
      expect(settings.reminderSettings.remindersEnabled, false);
      expect(
        settings.reminderSettings.prayerToggleFor(PrayerTimeKind.fajr),
        true,
      );
      expect(
        settings.reminderSettings.prayerToggleFor(PrayerTimeKind.sunrise),
        false,
      );
    });

    test('serializes location timezone fields', () {
      const PrayerLocation location = PrayerLocation(
        latitude: 51.5072,
        longitude: -0.1276,
        label: 'London',
        mode: PrayerLocationMode.manual,
        timezoneId: 'Europe/London',
      );

      final PrayerLocation? restored = PrayerLocation.fromJson(
        location.toJson(),
      );

      expect(restored?.timezoneId, 'Europe/London');
    });

    test('uses selected location timezone when available', () {
      const PrayerLocation london = PrayerLocation(
        latitude: 51.5072,
        longitude: -0.1276,
        label: 'London',
        mode: PrayerLocationMode.manual,
        timezoneId: 'Europe/London',
      );

      final PrayerDay day = service.calculateDay(
        date: DateTime(2026, 5, 4),
        location: london,
        settings: PrayerTimeSettings.defaults(),
      );

      expect(day.usesLocationTimezone, true);
      expect(day.timezoneId, 'Europe/London');
      expect(
        day.entryFor(PrayerTimeKind.dhuhr).time,
        isA<timezone.TZDateTime>(),
      );
    });

    test('calendar date follows selected location timezone', () {
      const PrayerLocation london = PrayerLocation(
        latitude: 51.5072,
        longitude: -0.1276,
        label: 'London',
        mode: PrayerLocationMode.manual,
        timezoneId: 'Europe/London',
      );

      final DateTime calendarDate = service.calendarDateForInstant(
        instant: DateTime.utc(2026, 5, 4, 23, 30),
        location: london,
        settings: PrayerTimeSettings.defaults(),
      );

      expect(calendarDate, DateTime(2026, 5, 5));
    });

    test('falls back to device timezone when location timezone is missing', () {
      final PrayerDay day = service.calculateDay(
        date: DateTime(2026, 5, 4),
        location: testLocation,
        settings: PrayerTimeSettings.defaults(),
      );

      expect(day.usesLocationTimezone, false);
      expect(day.timezoneId, isNull);
    });

    test('can disable location timezone', () {
      final PrayerDay day = service.calculateDay(
        date: DateTime(2026, 5, 4),
        location: testLocation.copyWith(timezoneId: 'America/New_York'),
        settings: PrayerTimeSettings.defaults().copyWith(
          useLocationTimezone: false,
        ),
      );

      expect(day.usesLocationTimezone, false);
      expect(day.timezoneId, isNull);
    });

    test('next prayer works with location timezone DateTimes', () {
      final PrayerLocation london = testLocation.copyWith(
        timezoneId: 'Europe/London',
      );
      final PrayerTimeSettings settings = PrayerTimeSettings.defaults();
      final PrayerDay day = service.calculateDay(
        date: DateTime(2026, 5, 4),
        location: london,
        settings: settings,
      );
      final PrayerDay tomorrow = service.calculateDay(
        date: DateTime(2026, 5, 5),
        location: london,
        settings: settings,
      );
      final DateTime beforeDhuhr = day
          .entryFor(PrayerTimeKind.dhuhr)
          .time
          .subtract(const Duration(minutes: 10));

      final NextPrayer next = service.nextPrayer(
        day: day,
        tomorrow: tomorrow,
        now: beforeDhuhr,
      );

      expect(next.entry.kind, PrayerTimeKind.dhuhr);
      expect(next.countdown.inMinutes, greaterThanOrEqualTo(9));
    });

    test('ignores retired extra-prayer settings without crashing', () {
      final String retiredPrayerKey = _retiredPrayerKey();
      final String retiredOffsetKey = _retiredOffsetKey();
      final PrayerTimeSettings restored = PrayerTimeSettings.fromJson(
        <String, dynamic>{
          'method': 'custom',
          retiredOffsetKey: 25,
          'offsets': <String, dynamic>{'fajr': 1, retiredPrayerKey: 7},
          'notifications': <String, dynamic>{retiredPrayerKey: true},
        },
      );

      final Map<String, dynamic> serialized = restored.toJson();
      expect(serialized.containsKey(retiredOffsetKey), false);
      expect(
        (serialized['offsets'] as Map).containsKey(retiredPrayerKey),
        false,
      );
    });

    test('selects next prayer and countdown without sunrise', () {
      final PrayerDay day = _fakeDay(DateTime(2026, 5, 4));
      final NextPrayer next = service.nextPrayer(
        day: day,
        now: DateTime(2026, 5, 4, 6, 30),
      );

      expect(next.entry.kind, PrayerTimeKind.dhuhr);
      expect(next.countdown, const Duration(hours: 5, minutes: 40));
    });

    test(
      'advances at the displayed prayer minute when times include seconds',
      () {
        final PrayerDay baseDay = _fakeDay(DateTime(2026, 5, 4));
        final PrayerDay day = PrayerDay(
          date: baseDay.date,
          location: baseDay.location,
          settings: baseDay.settings,
          effectiveMethod: baseDay.effectiveMethod,
          timezoneId: baseDay.timezoneId,
          usesLocationTimezone: baseDay.usesLocationTimezone,
          entries: baseDay.entries
              .map(
                (PrayerTimeEntry entry) => entry.kind == PrayerTimeKind.dhuhr
                    ? PrayerTimeEntry(
                        kind: entry.kind,
                        time: entry.time.add(const Duration(seconds: 42)),
                        offsetMinutes: entry.offsetMinutes,
                      )
                    : entry,
              )
              .toList(growable: false),
        );

        final NextPrayer next = service.nextPrayer(
          day: day,
          now: DateTime(2026, 5, 4, 12, 10),
        );

        expect(next.entry.kind, PrayerTimeKind.asr);
        expect(next.countdown, const Duration(hours: 3, minutes: 20));
      },
    );

    test('rolls next prayer to tomorrow Fajr after Isha', () {
      final PrayerDay today = _fakeDay(DateTime(2026, 5, 4));
      final PrayerDay tomorrow = _fakeDay(DateTime(2026, 5, 5));
      final NextPrayer next = service.nextPrayer(
        day: today,
        tomorrow: tomorrow,
        now: DateTime(2026, 5, 4, 22),
      );

      expect(next.entry.kind, PrayerTimeKind.fajr);
      expect(next.entry.time, DateTime(2026, 5, 5, 4, 40));
      expect(next.countdown, const Duration(hours: 6, minutes: 40));
    });
  });

  group('PrayerSettingsStore', () {
    setUp(() async {
      await initSettingsTestHarness();
    });

    test('saves and loads location settings', () async {
      final PrayerSettingsStore store = PrayerSettingsStore();
      const PrayerLocation location = PrayerLocation(
        latitude: 12.34,
        longitude: 56.78,
        label: 'Saved test location',
        mode: PrayerLocationMode.manual,
      );

      await store.saveLocation(location);
      final PrayerLocation? restored = store.getLocation();

      expect(restored?.latitude, 12.34);
      expect(restored?.longitude, 56.78);
      expect(restored?.label, 'Saved test location');
      expect(restored?.mode, PrayerLocationMode.manual);
    });
  });
}

PrayerDay _fakeDay(DateTime date) {
  final DateTime baseDate = DateTime(date.year, date.month, date.day);
  return PrayerDay(
    date: baseDate,
    location: const PrayerLocation(
      latitude: 35.78056,
      longitude: -78.6389,
      label: 'Test location',
      mode: PrayerLocationMode.manual,
    ),
    settings: PrayerTimeSettings.defaults(),
    effectiveMethod: PrayerCalculationMethod.muslimWorldLeague,
    timezoneId: null,
    usesLocationTimezone: false,
    entries: <PrayerTimeEntry>[
      PrayerTimeEntry(
        kind: PrayerTimeKind.fajr,
        time: baseDate.add(const Duration(hours: 4, minutes: 40)),
        offsetMinutes: 0,
      ),
      PrayerTimeEntry(
        kind: PrayerTimeKind.sunrise,
        time: baseDate.add(const Duration(hours: 6)),
        offsetMinutes: 0,
      ),
      PrayerTimeEntry(
        kind: PrayerTimeKind.dhuhr,
        time: baseDate.add(const Duration(hours: 12, minutes: 10)),
        offsetMinutes: 0,
      ),
      PrayerTimeEntry(
        kind: PrayerTimeKind.asr,
        time: baseDate.add(const Duration(hours: 15, minutes: 30)),
        offsetMinutes: 0,
      ),
      PrayerTimeEntry(
        kind: PrayerTimeKind.maghrib,
        time: baseDate.add(const Duration(hours: 18, minutes: 40)),
        offsetMinutes: 0,
      ),
      PrayerTimeEntry(
        kind: PrayerTimeKind.isha,
        time: baseDate.add(const Duration(hours: 20)),
        offsetMinutes: 0,
      ),
    ],
  );
}

String _retiredPrayerKey() {
  return String.fromCharCodes(const <int>[100, 104, 117, 104, 97]);
}

String _retiredOffsetKey() {
  return String.fromCharCodes(const <int>[
    100,
    104,
    117,
    104,
    97,
    77,
    105,
    110,
    117,
    116,
    101,
    115,
    65,
    102,
    116,
    101,
    114,
    83,
    117,
    110,
    114,
    105,
    115,
    101,
  ]);
}
