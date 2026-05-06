import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_notification_service.dart';
import 'package:equran/prayer/prayer_times_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrayerNotificationService', () {
    const PrayerLocation location = PrayerLocation(
      latitude: 51.5072,
      longitude: -0.1276,
      label: 'London',
      mode: PrayerLocationMode.manual,
      timezoneId: 'Europe/London',
    );
    final PrayerTimeSettings enabledSettings = PrayerTimeSettings.defaults()
        .copyWith(
          reminderSettings: const PrayerReminderSettings(
            remindersEnabled: true,
          ),
        );

    test('skips scheduling when no location is configured', () async {
      final _FakeNotificationPlatform platform = _FakeNotificationPlatform();
      final PrayerNotificationService service = PrayerNotificationService(
        platform: platform,
        nowProvider: () => DateTime(2026, 5, 4, 8),
      );

      final PrayerNotificationScheduleResult result = await service.reschedule(
        settings: enabledSettings,
        location: null,
      );

      expect(result.status, PrayerNotificationScheduleStatus.missingLocation);
      expect(platform.scheduled, isEmpty);
    });

    test('global toggle off cancels and does not schedule', () async {
      final _FakeNotificationPlatform platform = _FakeNotificationPlatform();
      final PrayerNotificationService service = PrayerNotificationService(
        platform: platform,
        nowProvider: () => DateTime(2026, 5, 4, 8),
      );

      final PrayerNotificationScheduleResult result = await service.reschedule(
        settings: PrayerTimeSettings.defaults(),
        location: location,
      );

      expect(result.status, PrayerNotificationScheduleStatus.disabled);
      expect(platform.scheduled, isEmpty);
      expect(platform.cancelledIds, isNotEmpty);
    });

    test(
      'schedules only reminder prayers and never Dhuha or Sunrise',
      () async {
        final _FakeNotificationPlatform platform = _FakeNotificationPlatform();
        final PrayerNotificationService service = PrayerNotificationService(
          platform: platform,
          scheduleDays: 1,
          nowProvider: () => DateTime.utc(2026, 5, 3, 23, 1),
        );

        final PrayerNotificationScheduleResult result = await service
            .reschedule(settings: enabledSettings, location: location);

        expect(result.status, PrayerNotificationScheduleStatus.scheduled);
        expect(
          result.scheduledNotifications
              .map((PrayerScheduledNotification item) => item.prayer)
              .toSet(),
          PrayerTimeKind.reminderOrder.toSet(),
        );
        expect(
          result.scheduledNotifications.map(
            (PrayerScheduledNotification item) => item.prayer,
          ),
          isNot(contains(PrayerTimeKind.sunrise)),
        );
      },
    );

    test('per-prayer toggles are respected', () async {
      final _FakeNotificationPlatform platform = _FakeNotificationPlatform();
      final PrayerNotificationService service = PrayerNotificationService(
        platform: platform,
        scheduleDays: 1,
        nowProvider: () => DateTime.utc(2026, 5, 3, 23, 1),
      );

      final PrayerNotificationScheduleResult result = await service.reschedule(
        settings: enabledSettings.copyWith(
          reminderSettings: enabledSettings.reminderSettings.copyWith(
            fajrEnabled: false,
            ishaEnabled: false,
          ),
        ),
        location: location,
      );

      expect(
        result.scheduledNotifications.map(
          (PrayerScheduledNotification item) => item.prayer,
        ),
        isNot(contains(PrayerTimeKind.fajr)),
      );
      expect(
        result.scheduledNotifications.map(
          (PrayerScheduledNotification item) => item.prayer,
        ),
        isNot(contains(PrayerTimeKind.isha)),
      );
    });

    test('passed prayer times schedule for tomorrow', () async {
      const PrayerTimesService prayerTimesService = PrayerTimesService();
      final PrayerDay day = prayerTimesService.calculateDay(
        date: DateTime(2026, 5, 4),
        location: location,
        settings: enabledSettings,
      );
      final DateTime afterIsha = day
          .entryFor(PrayerTimeKind.isha)
          .time
          .add(const Duration(hours: 1));
      final _FakeNotificationPlatform platform = _FakeNotificationPlatform();
      final PrayerNotificationService service = PrayerNotificationService(
        platform: platform,
        scheduleDays: 2,
        nowProvider: () => afterIsha,
      );

      final PrayerNotificationScheduleResult result = await service.reschedule(
        settings: enabledSettings,
        location: location,
      );

      expect(result.scheduledNotifications.first.dayOffset, 1);
      expect(result.scheduledNotifications.first.prayer, PrayerTimeKind.fajr);
    });

    test('scheduling uses manual offsets and reminder offset', () async {
      final PrayerTimeSettings settings = enabledSettings.copyWith(
        offsets: const PrayerOffsets(dhuhr: 12),
        reminderSettings: enabledSettings.reminderSettings.copyWith(
          fajrEnabled: false,
          asrEnabled: false,
          maghribEnabled: false,
          ishaEnabled: false,
          reminderOffsetMinutes: 10,
        ),
      );
      const PrayerTimesService prayerTimesService = PrayerTimesService();
      final DateTime date = DateTime(2026, 5, 4);
      final PrayerDay day = prayerTimesService.calculateDay(
        date: date,
        location: location,
        settings: settings,
      );
      final _FakeNotificationPlatform platform = _FakeNotificationPlatform();
      final PrayerNotificationService service = PrayerNotificationService(
        platform: platform,
        scheduleDays: 1,
        nowProvider: () => DateTime.utc(2026, 5, 3, 23, 1),
      );

      await service.reschedule(settings: settings, location: location);

      expect(
        platform.scheduled.values.single.scheduledAt,
        day
            .entryFor(PrayerTimeKind.dhuhr)
            .time
            .subtract(const Duration(minutes: 10)),
      );
    });

    test('cancel-and-reschedule does not duplicate IDs', () async {
      final _FakeNotificationPlatform platform = _FakeNotificationPlatform();
      final PrayerNotificationService service = PrayerNotificationService(
        platform: platform,
        scheduleDays: 1,
        nowProvider: () => DateTime.utc(2026, 5, 3, 23, 1),
      );

      await service.reschedule(settings: enabledSettings, location: location);
      await service.reschedule(settings: enabledSettings, location: location);

      expect(platform.scheduled.keys.toSet().length, platform.scheduled.length);
      expect(platform.scheduleCalls, platform.scheduled.length * 2);
    });

    test(
      'permission denied does not pretend notifications were scheduled',
      () async {
        final _FakeNotificationPlatform platform = _FakeNotificationPlatform(
          permissionStatus: PrayerNotificationPermissionStatus.denied,
        );
        final PrayerNotificationService service = PrayerNotificationService(
          platform: platform,
          nowProvider: () => DateTime(2026, 5, 4, 0),
        );

        final PrayerNotificationScheduleResult result = await service
            .reschedule(settings: enabledSettings, location: location);

        expect(
          result.status,
          PrayerNotificationScheduleStatus.permissionDenied,
        );
        expect(platform.scheduled, isEmpty);
      },
    );
  });
}

class _FakeNotificationPlatform implements PrayerLocalNotificationPlatform {
  _FakeNotificationPlatform({
    this.permissionStatus = PrayerNotificationPermissionStatus.granted,
  });

  PrayerNotificationPermissionStatus permissionStatus;
  final Map<int, _ScheduledCall> scheduled = <int, _ScheduledCall>{};
  final List<int> cancelledIds = <int>[];
  int scheduleCalls = 0;

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
    scheduled.remove(id);
  }

  @override
  Future<PrayerNotificationPermissionStatus> checkPermission() async {
    return permissionStatus;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> openSettings() async {}

  @override
  Future<PrayerNotificationPermissionStatus> requestPermission() async {
    return permissionStatus;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
  }) async {
    scheduleCalls += 1;
    scheduled[id] = _ScheduledCall(
      id: id,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      payload: payload,
    );
  }
}

class _ScheduledCall {
  const _ScheduledCall({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String payload;
}
