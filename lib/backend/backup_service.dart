import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:equran/backend/bookmark_db.dart';
import 'package:equran/backend/favourites_db.dart';
import 'package:equran/backend/reading_model.dart';
import 'package:equran/backend/settings_db.dart';
import 'package:equran/utils/reciter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:quran/quran.dart' show Translation;
import 'package:share_plus/share_plus.dart';

class AppBackupException implements Exception {
  AppBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.settingsCount,
    required this.favouritesCount,
    required this.readingHistoryCount,
  });

  final int settingsCount;
  final int favouritesCount;
  final int readingHistoryCount;
}

class BackupService {
  const BackupService._();

  static const int _schemaVersion = 1;
  static const int _themeColorCount = 18;
  static const Set<String> _boolSettings = <String>{
    'vibration',
    'showLastRead',
    'viewMode',
    'enableTranslation',
  };
  static const Set<String> _allowedSettings = <String>{
    ..._boolSettings,
    'translation',
    'reciter',
    'color',
    'themeMode',
    'fontSize',
    'fontSizeTranslation',
    'playbackRate',
  };

  static Future<String?> exportBackupFile() async {
    final String fileName = _buildFileName();
    final String encoded = const JsonEncoder.withIndent('  ').convert(
      _buildBackupPayload(),
    );

    if (!Platform.isAndroid && !Platform.isIOS) {
      final String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save eQuran backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['equranbackup'],
        bytes: Uint8List.fromList(utf8.encode(encoded)),
      );

      if (outputPath == null) {
        throw AppBackupException('Backup cancelled.');
      }

      final File outputFile = File(outputPath);
      await outputFile.writeAsString(encoded);
      return outputFile.path;
    }

    await SharePlus.instance.share(
      ShareParams(
        title: 'eQuran backup',
        subject: 'eQuran backup',
        text: 'Your eQuran backup file is attached.',
        files: <XFile>[
          XFile.fromData(
            Uint8List.fromList(utf8.encode(encoded)),
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: <String>[fileName],
      ),
    );

    return null;
  }

  static Future<BackupRestoreResult> restoreFromPickedFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json', 'equranbackup'],
      withData: true,
    );

    if (result == null) {
      throw AppBackupException('Restore cancelled.');
    }

    final PlatformFile file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw AppBackupException('The selected backup file is empty.');
    }

    final dynamic decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw AppBackupException('The selected file is not a valid backup.');
    }

    final Map<dynamic, dynamic> payload = decoded;
    final dynamic version = payload['schemaVersion'];
    if (version != _schemaVersion) {
      throw AppBackupException('Unsupported backup version.');
    }
    _verifyPayloadIntegrity(payload);

    final Map<String, dynamic> settings = _validateSettings(
      _readStringKeyMap(payload['settings']),
    );
    final Map<String, dynamic> favourites = _readStringKeyMap(
      payload['favourites'],
    );
    _validateFavourites(favourites);
    final List<ReadingEntry> readingHistory = _readHistoryEntries(payload['readingHistory']);

    await SettingsDB().clear();
    await FavouritesDB().clear();
    await BookmarkDB().clear();

    for (final MapEntry<String, dynamic> entry in settings.entries) {
      await SettingsDB().put(entry.key, entry.value);
    }
    for (final MapEntry<String, dynamic> entry in favourites.entries) {
      await FavouritesDB().put(entry.key, entry.value);
    }
    for (final ReadingEntry entry in readingHistory) {
      await BookmarkDB().put(entry.surah, entry);
    }

    return BackupRestoreResult(
      settingsCount: settings.length,
      favouritesCount: favourites.length,
      readingHistoryCount: readingHistory.length,
    );
  }

  static Map<String, dynamic> _buildBackupPayload() {
    final Map<dynamic, dynamic> rawSettings = SettingsDB().box.toMap();
    final Map<dynamic, dynamic> rawFavourites = FavouritesDB().box.toMap();
    final Map<dynamic, dynamic> rawBookmarks = BookmarkDB().box.toMap();
    final Map<String, dynamic> payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': rawSettings.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
      'favourites': rawFavourites.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
      'readingHistory': rawBookmarks.values
          .whereType<ReadingEntry>()
          .map(_readingEntryToJson)
          .toList(),
    };
    payload['integrity'] = _integrityHashFor(payload);
    return payload;
  }

  static Map<String, dynamic> _readStringKeyMap(dynamic value) {
    if (value == null) return <String, dynamic>{};
    if (value is! Map) {
      throw AppBackupException('The backup file has an invalid data format.');
    }

    return value.map(
      (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }

  static List<ReadingEntry> _readHistoryEntries(dynamic value) {
    if (value == null) return <ReadingEntry>[];
    if (value is! List) {
      throw AppBackupException('The backup file has an invalid reading history.');
    }

    return value.map<ReadingEntry>((dynamic item) {
      if (item is! Map) {
        throw AppBackupException(
          'The backup file contains an invalid history entry.',
        );
      }

      final dynamic surah = item['surah'];
      final dynamic verse = item['verse'];
      final dynamic timestamp = item['timestamp'];
      if (surah is! int || verse is! int || timestamp is! String) {
        throw AppBackupException(
          'The backup file contains an invalid history entry.',
        );
      }
      if (surah < 1 || surah > 114 || verse < 1) {
        throw AppBackupException(
          'The backup file contains an out-of-range history entry.',
        );
      }

      try {
        return ReadingEntry(
          surah: surah,
          verse: verse,
          timestamp: DateTime.parse(timestamp),
        );
      } catch (_) {
        throw AppBackupException(
          'The backup file contains an invalid history timestamp.',
        );
      }
    }).toList();
  }

  static Map<String, dynamic> _validateSettings(Map<String, dynamic> settings) {
    for (final String key in settings.keys) {
      if (!_allowedSettings.contains(key)) {
        throw AppBackupException('The backup file contains an unknown setting: $key.');
      }
    }

    final Map<String, dynamic> validated = <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in settings.entries) {
      validated[entry.key] = switch (entry.key) {
        'vibration' ||
        'showLastRead' ||
        'viewMode' ||
        'enableTranslation' => _requireBool(entry.key, entry.value),
        'translation' => _requireIntInRange(
          entry.key,
          entry.value,
          min: 0,
          max: Translation.values.length - 1,
        ),
        'color' => _requireIntInRange(
          entry.key,
          entry.value,
          min: 0,
          max: _themeColorCount - 1,
        ),
        'themeMode' => _requireThemeMode(entry.value),
        'reciter' => _requireReciterCode(entry.value),
        'fontSize' => _requireDoubleInRange(
          entry.key,
          entry.value,
          min: 25,
          max: 65,
        ),
        'fontSizeTranslation' => _requireDoubleInRange(
          entry.key,
          entry.value,
          min: 10,
          max: 30,
        ),
        'playbackRate' => _requireAllowedDouble(
          entry.key,
          entry.value,
          const <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
        ),
        _ => throw AppBackupException(
          'The backup file contains an unsupported setting: ${entry.key}.',
        ),
      };
    }

    return validated;
  }

  static void _validateFavourites(Map<String, dynamic> favourites) {
    for (final MapEntry<String, dynamic> entry in favourites.entries) {
      final RegExpMatch? match =
          RegExp(r'^(\d{1,3})-(\d{3})$').firstMatch(entry.key);
      if (match == null) {
        throw AppBackupException('The backup file contains an invalid favourite key.');
      }

      final int surah = int.parse(match.group(1)!);
      final int verse = int.parse(match.group(2)!);
      if (surah < 1 || surah > 114 || verse < 1) {
        throw AppBackupException(
          'The backup file contains an out-of-range favourite entry.',
        );
      }
      if (entry.value is! String) {
        throw AppBackupException('Favourite notes must be stored as text.');
      }
      if ((entry.value as String).length > 80) {
        throw AppBackupException('A favourite note exceeds the supported length.');
      }
    }
  }

  static bool _requireBool(String key, dynamic value) {
    if (value is! bool) {
      throw AppBackupException('Invalid value for "$key".');
    }
    return value;
  }

  static int _requireIntInRange(
    String key,
    dynamic value, {
    required int min,
    required int max,
  }) {
    if (value is! int || value < min || value > max) {
      throw AppBackupException('Invalid value for "$key".');
    }
    return value;
  }

  static double _requireDoubleInRange(
    String key,
    dynamic value, {
    required double min,
    required double max,
  }) {
    if (value is! double) {
      throw AppBackupException('Invalid value for "$key".');
    }
    if (!value.isFinite || value < min || value > max) {
      throw AppBackupException('Invalid value for "$key".');
    }
    return value;
  }

  static double _requireAllowedDouble(
    String key,
    dynamic value,
    List<double> allowed,
  ) {
    final double normalized = _requireDoubleInRange(
      key,
      value,
      min: allowed.reduce((a, b) => a < b ? a : b),
      max: allowed.reduce((a, b) => a > b ? a : b),
    );
    if (!allowed.any((double candidate) => candidate == normalized)) {
      throw AppBackupException('Invalid value for "$key".');
    }
    return normalized;
  }

  static String _requireThemeMode(dynamic value) {
    if (value is! String || (value != 'light' && value != 'dark')) {
      throw AppBackupException('Invalid value for "themeMode".');
    }
    return value;
  }

  static String _requireReciterCode(dynamic value) {
    if (value is! String) {
      throw AppBackupException('Invalid value for "reciter".');
    }
    final String normalizedCode = AppReciter.normalizeCode(value);
    final bool isValid = AppReciter.values.any(
      (AppReciter reciter) => reciter.code == normalizedCode,
    );
    if (!isValid) {
      throw AppBackupException('Invalid value for "reciter".');
    }
    return normalizedCode;
  }

  static void _verifyPayloadIntegrity(Map<dynamic, dynamic> payload) {
    final dynamic integrity = payload['integrity'];
    if (integrity is! String || integrity.isEmpty) {
      throw AppBackupException('The backup file is missing its integrity check.');
    }

    final String expected = _integrityHashFor(
      payload.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      ),
    );
    if (integrity != expected) {
      throw AppBackupException('The backup file failed integrity validation.');
    }
  }

  static String _integrityHashFor(Map<String, dynamic> payload) {
    final Map<String, dynamic> sanitized = Map<String, dynamic>.from(payload)
      ..remove('integrity');
    final String canonical = jsonEncode(_canonicalize(sanitized));
    final int crc32 = _computeCrc32(utf8.encode(canonical));
    return crc32.toRadixString(16).padLeft(8, '0');
  }

  static int _computeCrc32(List<int> bytes) {
    int crc = 0xffffffff;
    for (final int byte in bytes) {
      crc ^= byte;
      for (int bit = 0; bit < 8; bit++) {
        final bool hasLowBit = (crc & 1) != 0;
        crc = crc >> 1;
        if (hasLowBit) {
          crc ^= 0xedb88320;
        }
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final List<String> sortedKeys = value.keys
          .map((dynamic key) => key.toString())
          .toList()
        ..sort();
      return <String, Object?>{
        for (final String key in sortedKeys)
          key: _canonicalize(value[key]),
      };
    }
    if (value is List) {
      return value.map<Object?>((dynamic item) => _canonicalize(item)).toList();
    }
    return value;
  }

  static Map<String, dynamic> _readingEntryToJson(ReadingEntry entry) {
    return <String, dynamic>{
      'surah': entry.surah,
      'verse': entry.verse,
      'timestamp': entry.timestamp.toUtc().toIso8601String(),
    };
  }

  static String _buildFileName() {
    final String timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-');
    return 'equran-backup-$timestamp.equranbackup';
  }
}
