import 'package:equran/backend/settings_db.dart';
import 'package:equran/prayer/prayer_models.dart';

class PrayerSettingsStore {
  PrayerSettingsStore({SettingsDB? settingsDB})
    : _settingsDB = settingsDB ?? SettingsDB();

  static const String settingsKey = 'prayerTimeSettings';
  static const String locationKey = 'prayerLocation';

  final SettingsDB _settingsDB;

  PrayerTimeSettings getSettings() {
    final dynamic value = _settingsDB.get(settingsKey);
    return PrayerTimeSettings.fromJson(value is Map ? value : null);
  }

  PrayerLocation? getLocation() {
    final dynamic value = _settingsDB.get(locationKey);
    return PrayerLocation.fromJson(value is Map ? value : null);
  }

  Future<void> clearLocation() {
    return _settingsDB.delete(locationKey);
  }

  Future<void> saveSettings(PrayerTimeSettings settings) {
    return _settingsDB.put(settingsKey, settings.toJson());
  }

  Future<void> saveLocation(PrayerLocation location) {
    return _settingsDB.put(locationKey, location.toJson());
  }
}
