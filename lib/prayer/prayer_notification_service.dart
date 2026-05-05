import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_times_service.dart';
import 'package:equran/prayer/prayer_timezone_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as timezone;

enum PrayerNotificationPermissionStatus {
  granted,
  denied,
  unsupported,
}

enum PrayerNotificationScheduleStatus {
  disabled,
  missingLocation,
  permissionDenied,
  unsupported,
  scheduled,
  failed,
}

class PrayerScheduledNotification {
  const PrayerScheduledNotification({
    required this.id,
    required this.prayer,
    required this.scheduledAt,
    required this.dayOffset,
  });

  final int id;
  final PrayerTimeKind prayer;
  final DateTime scheduledAt;
  final int dayOffset;
}

class PrayerNotificationScheduleResult {
  const PrayerNotificationScheduleResult({
    required this.status,
    this.scheduledNotifications = const <PrayerScheduledNotification>[],
    this.message,
  });

  final PrayerNotificationScheduleStatus status;
  final List<PrayerScheduledNotification> scheduledNotifications;
  final String? message;

  int get scheduledCount => scheduledNotifications.length;
}

abstract class PrayerLocalNotificationPlatform {
  Future<void> initialize();

  Future<PrayerNotificationPermissionStatus> checkPermission();

  Future<PrayerNotificationPermissionStatus> requestPermission();

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
  });

  Future<void> cancel(int id);
}

class FlutterPrayerLocalNotificationPlatform
    implements PrayerLocalNotificationPlatform {
  FlutterPrayerLocalNotificationPlatform._();

  static final FlutterPrayerLocalNotificationPlatform instance =
      FlutterPrayerLocalNotificationPlatform._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized || !_isSupported) return;
    await PrayerTimezoneService.configureDeviceTimezone();
    await _plugin.initialize(
  settings: const InitializationSettings(
    android: AndroidInitializationSettings('ic_prayer_notification'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
    macOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  ),
);
    _initialized = true;
  }

  @override
  Future<PrayerNotificationPermissionStatus> checkPermission() async {
    if (!_isSupported) return PrayerNotificationPermissionStatus.unsupported;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final bool? enabled = await android?.areNotificationsEnabled();
      return enabled == false
          ? PrayerNotificationPermissionStatus.denied
          : PrayerNotificationPermissionStatus.granted;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final NotificationsEnabledOptions? permissions = await ios
          ?.checkPermissions();
      return permissions?.isEnabled == true
          ? PrayerNotificationPermissionStatus.granted
          : PrayerNotificationPermissionStatus.denied;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final MacOSFlutterLocalNotificationsPlugin? macOS = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      final NotificationsEnabledOptions? permissions = await macOS
          ?.checkPermissions();
      return permissions?.isEnabled == true
          ? PrayerNotificationPermissionStatus.granted
          : PrayerNotificationPermissionStatus.denied;
    }

    return PrayerNotificationPermissionStatus.unsupported;
  }

  @override
  Future<PrayerNotificationPermissionStatus> requestPermission() async {
    if (!_isSupported) return PrayerNotificationPermissionStatus.unsupported;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await android?.requestNotificationsPermission();
      return granted == false
          ? PrayerNotificationPermissionStatus.denied
          : PrayerNotificationPermissionStatus.granted;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await ios?.requestPermissions(
        alert: true,
        sound: true,
      );
      return granted == true
          ? PrayerNotificationPermissionStatus.granted
          : PrayerNotificationPermissionStatus.denied;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final MacOSFlutterLocalNotificationsPlugin? macOS = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      final bool? granted = await macOS?.requestPermissions(
        alert: true,
        sound: true,
      );
      return granted == true
          ? PrayerNotificationPermissionStatus.granted
          : PrayerNotificationPermissionStatus.denied;
    }

    return PrayerNotificationPermissionStatus.unsupported;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
  }) async {
    if (!_isSupported) return;
    await initialize();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: timezone.TZDateTime.from(scheduledAt, timezone.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_reminders',
          'Prayer reminders',
          channelDescription: 'Local reminders for enabled prayer times.',
          icon: 'ic_prayer_notification',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!_isSupported) return;
    await initialize();
    await _plugin.cancel(id: id);
  }

  bool get _isSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }
}

class PrayerNotificationService {
  PrayerNotificationService({
    PrayerLocalNotificationPlatform? platform,
    PrayerTimesService prayerTimesService = const PrayerTimesService(),
    DateTime Function()? nowProvider,
    this.scheduleDays = defaultScheduleDays,
  }) : _platform =
           platform ?? FlutterPrayerLocalNotificationPlatform.instance,
       _prayerTimesService = prayerTimesService,
       _nowProvider = nowProvider ?? DateTime.now;

  static const int defaultScheduleDays = 7;
  static const int _notificationBaseId = 42000;

  final PrayerLocalNotificationPlatform _platform;
  final PrayerTimesService _prayerTimesService;
  final DateTime Function() _nowProvider;
  final int scheduleDays;

  Future<void> initialize() {
    return _platform.initialize();
  }

  Future<PrayerNotificationPermissionStatus> checkPermission() {
    return _platform.checkPermission();
  }

  Future<PrayerNotificationPermissionStatus> requestPermission() {
    return _platform.requestPermission();
  }

  Future<void> cancelPrayerNotifications() async {
    for (int dayOffset = 0; dayOffset < scheduleDays; dayOffset++) {
      for (final PrayerTimeKind prayer in PrayerTimeKind.reminderOrder) {
        await _platform.cancel(notificationIdFor(prayer, dayOffset));
      }
    }
  }

  Future<PrayerNotificationScheduleResult> reschedule({
    required PrayerTimeSettings settings,
    required PrayerLocation? location,
    bool requestPermission = false,
  }) async {
    try {
      await _platform.initialize();
      await cancelPrayerNotifications();

      final PrayerReminderSettings reminders = settings.reminderSettings;
      if (!reminders.remindersEnabled || reminders.enabledPrayerKinds.isEmpty) {
        return const PrayerNotificationScheduleResult(
          status: PrayerNotificationScheduleStatus.disabled,
        );
      }

      if (location == null) {
        return const PrayerNotificationScheduleResult(
          status: PrayerNotificationScheduleStatus.missingLocation,
          message: 'Choose a location before scheduling reminders.',
        );
      }

      final PrayerNotificationPermissionStatus permission = requestPermission
          ? await _platform.requestPermission()
          : await _platform.checkPermission();
      if (permission == PrayerNotificationPermissionStatus.unsupported) {
        return const PrayerNotificationScheduleResult(
          status: PrayerNotificationScheduleStatus.unsupported,
          message: 'Prayer reminders are not supported on this platform.',
        );
      }
      if (permission != PrayerNotificationPermissionStatus.granted) {
        return const PrayerNotificationScheduleResult(
          status: PrayerNotificationScheduleStatus.permissionDenied,
          message: 'Notification permission is off.',
        );
      }

      final DateTime now = _nowProvider();
      final DateTime today = _prayerTimesService.calendarDateForInstant(
        instant: now,
        location: location,
        settings: settings,
      );
      final List<PrayerScheduledNotification> scheduled =
          <PrayerScheduledNotification>[];

      for (int dayOffset = 0; dayOffset < scheduleDays; dayOffset++) {
        final DateTime date = DateTime(
          today.year,
          today.month,
          today.day + dayOffset,
        );
        final PrayerDay day = _prayerTimesService.calculateDay(
          date: date,
          location: location,
          settings: settings,
        );

        for (final PrayerTimeKind prayer in PrayerTimeKind.reminderOrder) {
          if (!reminders.isReminderActiveFor(prayer)) continue;
          final DateTime scheduledAt = day
              .entryFor(prayer)
              .time
              .subtract(Duration(minutes: reminders.reminderOffsetMinutes));
          if (!scheduledAt.isAfter(now)) continue;

          final int id = notificationIdFor(prayer, dayOffset);
          await _platform.schedule(
            id: id,
            title: prayer.label,
            body: _notificationBody(
              prayer,
              reminders.reminderOffsetMinutes,
            ),
            scheduledAt: scheduledAt,
            payload: 'prayer:${prayer.id}:${scheduledAt.toIso8601String()}',
          );
          scheduled.add(
            PrayerScheduledNotification(
              id: id,
              prayer: prayer,
              scheduledAt: scheduledAt,
              dayOffset: dayOffset,
            ),
          );
        }
      }

      if (kDebugMode) {
        debugPrint(
          'Prayer notifications scheduled: ${scheduled.length} '
          'over $scheduleDays days',
        );
      }

      return PrayerNotificationScheduleResult(
        status: PrayerNotificationScheduleStatus.scheduled,
        scheduledNotifications: scheduled,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Prayer notification scheduling failed: $error');
      }
      return PrayerNotificationScheduleResult(
        status: PrayerNotificationScheduleStatus.failed,
        message: error.toString(),
      );
    }
  }

  int notificationIdFor(PrayerTimeKind prayer, int dayOffset) {
    final int prayerIndex = PrayerTimeKind.reminderOrder.indexOf(prayer);
    if (prayerIndex < 0 || dayOffset < 0) {
      throw ArgumentError('Unsupported prayer notification id: $prayer');
    }
    return _notificationBaseId + (dayOffset * 10) + prayerIndex;
  }

  String _notificationBody(PrayerTimeKind prayer, int offsetMinutes) {
    if (offsetMinutes <= 0) {
      return 'It is time for ${prayer.label} prayer.';
    }
    return '${prayer.label} prayer is in $offsetMinutes minutes.';
  }
}
