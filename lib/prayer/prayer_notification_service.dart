import 'dart:async';

import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_times_service.dart';
import 'package:equran/prayer/prayer_timezone_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as timezone;

enum PrayerNotificationPermissionStatus { granted, denied, unsupported }

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

  Future<void> openSettings();

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

  static const Duration _operationTimeout = Duration(seconds: 8);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final _AndroidPrayerNotificationPermissionBridge _androidPermissions =
      const _AndroidPrayerNotificationPermissionBridge();

  bool _initialized = false;
  bool _timezoneConfigured = false;

  @override
  Future<void> initialize() async {
    if (_initialized || !_isSupported) return;
    await _plugin
        .initialize(
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
        )
        .timeout(_operationTimeout);
    _initialized = true;
  }

  @override
  Future<PrayerNotificationPermissionStatus> checkPermission() async {
    if (!_isSupported) return PrayerNotificationPermissionStatus.unsupported;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final PrayerNotificationPermissionStatus? nativeStatus =
          await _androidPermissions
              .checkPermission()
              .timeout(_operationTimeout, onTimeout: () => null);
      if (nativeStatus != null) return nativeStatus;

      await initialize();
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) {
        return PrayerNotificationPermissionStatus.unsupported;
      }
      final bool? enabled = await android.areNotificationsEnabled().timeout(
        _operationTimeout,
      );
      return enabled == true
          ? PrayerNotificationPermissionStatus.granted
          : PrayerNotificationPermissionStatus.denied;
    }

    await initialize();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios == null) return PrayerNotificationPermissionStatus.unsupported;
      final NotificationsEnabledOptions? permissions = await ios
          .checkPermissions()
          .timeout(_operationTimeout);
      return permissions?.isEnabled == true
          ? PrayerNotificationPermissionStatus.granted
          : PrayerNotificationPermissionStatus.denied;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final MacOSFlutterLocalNotificationsPlugin? macOS = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macOS == null) return PrayerNotificationPermissionStatus.unsupported;
      final NotificationsEnabledOptions? permissions = await macOS
          .checkPermissions()
          .timeout(_operationTimeout);
      return permissions?.isEnabled == true
          ? PrayerNotificationPermissionStatus.granted
          : PrayerNotificationPermissionStatus.denied;
    }

    return PrayerNotificationPermissionStatus.unsupported;
  }

  @override
  Future<PrayerNotificationPermissionStatus> requestPermission() async {
    if (!_isSupported) return PrayerNotificationPermissionStatus.unsupported;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final PrayerNotificationPermissionStatus? nativeStatus =
          await _androidPermissions
              .requestPermission()
              .timeout(_operationTimeout, onTimeout: () => null);
      if (nativeStatus != null) return nativeStatus;

      await initialize();
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) {
        return PrayerNotificationPermissionStatus.unsupported;
      }
      final bool? granted = await android
          .requestNotificationsPermission()
          .timeout(_operationTimeout);
      return granted == true
          ? PrayerNotificationPermissionStatus.granted
          : PrayerNotificationPermissionStatus.denied;
    }

    await initialize();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios == null) return PrayerNotificationPermissionStatus.unsupported;
      final bool? granted = await ios
          .requestPermissions(alert: true, sound: true)
          .timeout(_operationTimeout);
      return granted == true
          ? PrayerNotificationPermissionStatus.granted
          : PrayerNotificationPermissionStatus.denied;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final MacOSFlutterLocalNotificationsPlugin? macOS = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macOS == null) return PrayerNotificationPermissionStatus.unsupported;
      final bool? granted = await macOS
          .requestPermissions(alert: true, sound: true)
          .timeout(_operationTimeout);
      return granted == true
          ? PrayerNotificationPermissionStatus.granted
          : PrayerNotificationPermissionStatus.denied;
    }

    return PrayerNotificationPermissionStatus.unsupported;
  }

  @override
  Future<void> openSettings() async {
    if (!_isSupported) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final bool opened = await _androidPermissions
          .openSettings()
          .timeout(_operationTimeout, onTimeout: () => false);
      if (opened) return;
    }
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
    await _configureTimezone();
    await _plugin
        .zonedSchedule(
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
        )
        .timeout(_operationTimeout);
  }

  @override
  Future<void> cancel(int id) async {
    if (!_isSupported) return;
    await initialize();
    await _plugin.cancel(id: id).timeout(_operationTimeout);
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

  Future<void> _configureTimezone() async {
    if (_timezoneConfigured) return;
    await PrayerTimezoneService.configureDeviceTimezone().timeout(
      _operationTimeout,
    );
    _timezoneConfigured = true;
  }
}

class _AndroidPrayerNotificationPermissionBridge {
  const _AndroidPrayerNotificationPermissionBridge();

  static const MethodChannel _channel = MethodChannel(
    'com.app.equran/notification_permissions',
  );

  Future<PrayerNotificationPermissionStatus?> checkPermission() {
    return _invokePermissionStatus('checkNotificationPermission');
  }

  Future<PrayerNotificationPermissionStatus?> requestPermission() {
    return _invokePermissionStatus('requestNotificationPermission');
  }

  Future<bool> openSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<PrayerNotificationPermissionStatus?> _invokePermissionStatus(
    String method,
  ) async {
    try {
      final String? status = await _channel.invokeMethod<String>(method);
      return switch (status) {
        'granted' => PrayerNotificationPermissionStatus.granted,
        'denied' => PrayerNotificationPermissionStatus.denied,
        'unsupported' => PrayerNotificationPermissionStatus.unsupported,
        _ => null,
      };
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

class PrayerNotificationService {
  PrayerNotificationService({
    PrayerLocalNotificationPlatform? platform,
    PrayerTimesService prayerTimesService = const PrayerTimesService(),
    DateTime Function()? nowProvider,
    this.scheduleDays = defaultScheduleDays,
  }) : _platform = platform ?? FlutterPrayerLocalNotificationPlatform.instance,
       _prayerTimesService = prayerTimesService,
       _nowProvider = nowProvider ?? DateTime.now;

  static const int defaultScheduleDays = 7;
  static const int _notificationBaseId = 42000;
  static const Duration _operationTimeout = Duration(seconds: 8);

  final PrayerLocalNotificationPlatform _platform;
  final PrayerTimesService _prayerTimesService;
  final DateTime Function() _nowProvider;
  final int scheduleDays;

  Future<void> initialize() {
    return _withTimeout(_platform.initialize());
  }

  Future<PrayerNotificationPermissionStatus> checkPermission() {
    return _withTimeout(_platform.checkPermission());
  }

  Future<PrayerNotificationPermissionStatus> requestPermission() {
    return _withTimeout(_platform.requestPermission());
  }

  Future<void> openSettings() {
    return _withTimeout(_platform.openSettings());
  }

  Future<void> cancelPrayerNotifications() async {
    for (int dayOffset = 0; dayOffset < scheduleDays; dayOffset++) {
      for (final PrayerTimeKind prayer in PrayerTimeKind.reminderOrder) {
        await _withTimeout(
          _platform.cancel(notificationIdFor(prayer, dayOffset)),
        );
      }
    }
  }

  Future<PrayerNotificationScheduleResult> reschedule({
    required PrayerTimeSettings settings,
    required PrayerLocation? location,
    bool requestPermission = false,
  }) async {
    try {
      await _withTimeout(_platform.initialize());
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
          ? await _withTimeout(_platform.requestPermission())
          : await _withTimeout(_platform.checkPermission());
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
          await _withTimeout(
            _platform.schedule(
              id: id,
              title: prayer.label,
              body: _notificationBody(prayer, reminders.reminderOffsetMinutes),
              scheduledAt: scheduledAt,
              payload: 'prayer:${prayer.id}:${scheduledAt.toIso8601String()}',
            ),
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
    } on TimeoutException {
      return const PrayerNotificationScheduleResult(
        status: PrayerNotificationScheduleStatus.failed,
        message:
            'Notification setup timed out. Check notification permission and try again.',
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

  Future<T> _withTimeout<T>(Future<T> future) {
    return future.timeout(_operationTimeout);
  }
}
