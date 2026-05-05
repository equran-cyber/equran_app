import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

abstract class PrayerTimezoneResolver {
  String? timezoneIdForCoordinates(double latitude, double longitude);
}

class LatLngPrayerTimezoneResolver implements PrayerTimezoneResolver {
  const LatLngPrayerTimezoneResolver();

  @override
  String? timezoneIdForCoordinates(double latitude, double longitude) {
    PrayerTimezoneService.ensureDatabaseInitialized();
    try {
      final String timezoneId = latLngToTimezoneString(latitude, longitude)
          .trim();
      if (timezoneId.isEmpty || timezoneId == 'unknown') return null;
      timezone.getLocation(timezoneId);
      return timezoneId;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Prayer timezone lookup failed: $error');
      }
      return null;
    }
  }
}

class PrayerTimezoneService {
  const PrayerTimezoneService._();

  static bool _databaseInitialized = false;

  static void ensureDatabaseInitialized() {
    if (_databaseInitialized) return;
    timezone_data.initializeTimeZones();
    _databaseInitialized = true;
  }

  static Future<String?> configureDeviceTimezone() async {
    ensureDatabaseInitialized();
    try {
      final TimezoneInfo localTimezone = await FlutterTimezone
          .getLocalTimezone();
      final String timezoneId = localTimezone.identifier.trim();
      if (timezoneId.isEmpty) return null;
      timezone.setLocalLocation(timezone.getLocation(timezoneId));
      return timezoneId;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Prayer device timezone lookup failed: $error');
      }
      return null;
    }
  }

  static timezone.Location? locationForId(String? timezoneId) {
    ensureDatabaseInitialized();
    final String? trimmed = _cleanTimezoneId(timezoneId);
    if (trimmed == null) return null;
    try {
      return timezone.getLocation(trimmed);
    } catch (_) {
      return null;
    }
  }

  static String? validTimezoneId(String? timezoneId) {
    final timezone.Location? location = locationForId(timezoneId);
    return location?.name;
  }

  static String? _cleanTimezoneId(String? timezoneId) {
    final String? trimmed = timezoneId?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == 'unknown') {
      return null;
    }
    return trimmed;
  }
}
