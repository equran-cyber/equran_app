import 'dart:convert';

import 'package:flutter/foundation.dart'
    show FlutterError, debugPrint, kDebugMode;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:quran/quran.dart' as quran;

class AyahTiming {
  const AyahTiming({
    required this.ayahNumber,
    required this.start,
    required this.end,
  });

  final int ayahNumber;
  final Duration start;
  final Duration end;

  bool contains(Duration position) {
    return position >= start && position < end;
  }
}

class SurahTiming {
  const SurahTiming({
    required this.reciterCode,
    required this.surahNumber,
    required this.ayahs,
  });

  final String reciterCode;
  final int surahNumber;
  final List<AyahTiming> ayahs;

  AyahTiming? timingForPosition(Duration position) {
    if (ayahs.isEmpty) return null;
    if (position < ayahs.first.start) return null;

    int low = 0;
    int high = ayahs.length - 1;
    while (low <= high) {
      final int mid = low + ((high - low) >> 1);
      final AyahTiming candidate = ayahs[mid];
      if (candidate.contains(position)) return candidate;
      if (position < candidate.start) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    return null;
  }
}

class SurahTimingRepository {
  SurahTimingRepository();

  final Map<String, SurahTiming?> _cache = <String, SurahTiming?>{};

  static Future<bool> hasTimingSupportForReciter(String code) async {
    final TimingAssetIndex index = await TimingAssetIndex.load();
    return index.hasTimingSupportForReciter(code);
  }

  Future<SurahTiming?> loadSurahTiming({
    required String reciterCode,
    required int surahNumber,
  }) async {
    final String normalizedCode = reciterCode.trim();
    final int normalizedSurah = surahNumber.clamp(1, 114).toInt();
    final String cacheKey = '$normalizedCode-$normalizedSurah';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final TimingAssetIndex index = await TimingAssetIndex.load();
    if (!index.hasTimingSupportForReciter(normalizedCode)) {
      _cache[cacheKey] = null;
      return null;
    }

    final String? assetPath = index.timingPathForSurah(
      reciterCode: normalizedCode,
      surahNumber: normalizedSurah,
    );
    if (assetPath == null) {
      _cache[cacheKey] = null;
      return null;
    }

    final String? rawTiming = await _loadTimingAsset(assetPath);
    if (rawTiming == null) {
      _cache[cacheKey] = null;
      return null;
    }

    final SurahTiming? timing = parseTimingFile(
      reciterCode: normalizedCode,
      surahNumber: normalizedSurah,
      rawTiming: rawTiming,
    );
    _cache[cacheKey] = timing;
    return timing;
  }

  Future<String?> _loadTimingAsset(String path) async {
    try {
      return await rootBundle.loadString(path);
    } on FlutterError catch (_) {
      // Missing timing files are expected for unsupported or incomplete sets.
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to load timing asset "$path": $error');
      }
    }
    return null;
  }

  static SurahTiming? parseTimingFile({
    required String reciterCode,
    required int surahNumber,
    required String rawTiming,
  }) {
    final int ayahCount = quran.getVerseCount(surahNumber);
    final List<Duration> markers = <Duration>[];
    int malformedRows = 0;
    final String trimmedTiming = rawTiming.trimLeft();

    if (trimmedTiming.startsWith('[') || trimmedTiming.startsWith('{')) {
      try {
        malformedRows = _appendJsonTimingMarkers(
          jsonDecode(rawTiming),
          markers,
        );
      } catch (_) {
        malformedRows++;
      }
    } else {
      for (final String rawLine in rawTiming.split(RegExp(r'\r?\n'))) {
        final String line = rawLine.trim();
        if (line.isEmpty) continue;
        final int? milliseconds = int.tryParse(line);
        if (milliseconds == null || milliseconds < 0) {
          malformedRows++;
          continue;
        }
        markers.add(Duration(milliseconds: milliseconds));
      }
    }

    if (markers.length < ayahCount) {
      if (kDebugMode) {
        debugPrint(
          'Timing file $reciterCode/$surahNumber has ${markers.length} '
          'valid rows for $ayahCount ayahs. Ignoring it.',
        );
      }
      return null;
    }

    markers.sort();

    final List<AyahTiming> ayahs = <AyahTiming>[];
    for (int index = 0; index < ayahCount; index++) {
      final Duration start = markers[index];
      final Duration end = index + 1 < markers.length
          ? markers[index + 1]
          : const Duration(days: 1);
      if (end <= start) continue;
      ayahs.add(AyahTiming(ayahNumber: index + 1, start: start, end: end));
    }

    if (ayahs.isEmpty) return null;

    if (kDebugMode && malformedRows > 0) {
      debugPrint(
        'Timing file $reciterCode/$surahNumber ignored $malformedRows '
        'malformed rows.',
      );
    }

    // VerseByVerseQuran timing files are millisecond start markers. Some files
    // include an extra final marker for the end of the last ayah; files without
    // that final marker keep the last ayah active until playback completes.
    return SurahTiming(
      reciterCode: reciterCode,
      surahNumber: surahNumber,
      ayahs: List<AyahTiming>.unmodifiable(ayahs),
    );
  }

  static int _appendJsonTimingMarkers(Object? value, List<Duration> markers) {
    int malformedRows = 0;
    if (value is List<Object?>) {
      for (final Object? entry in value) {
        final int? milliseconds = _millisecondsFromJsonEntry(entry);
        if (milliseconds == null || milliseconds < 0) {
          malformedRows++;
          continue;
        }
        markers.add(Duration(milliseconds: milliseconds));
      }
      return malformedRows;
    }

    if (value is Map<String, Object?>) {
      for (final String key in <String>[
        'markers',
        'timings',
        'ayahs',
        'verses',
      ]) {
        final Object? nestedValue = value[key];
        if (nestedValue is List<Object?>) {
          return _appendJsonTimingMarkers(nestedValue, markers);
        }
      }
    }

    return 1;
  }

  static int? _millisecondsFromJsonEntry(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    if (value is Map<String, Object?>) {
      for (final String key in <String>[
        'start',
        'startMs',
        'start_ms',
        'timestamp',
        'time',
        'milliseconds',
        'ms',
      ]) {
        final int? milliseconds = _millisecondsFromJsonEntry(value[key]);
        if (milliseconds != null) return milliseconds;
      }
    }
    return null;
  }
}

class TimingAssetIndex {
  const TimingAssetIndex._({
    required this.availableTimingReciterCodes,
    required this.availableTimingFiles,
  });

  static const String timingAssetRoot = 'assets/timings/';
  static final RegExp _timingAssetPattern = RegExp(
    r'^assets/timings/([^/]+)/([^/]+)$',
  );
  static Future<TimingAssetIndex>? _cachedIndex;

  final Set<String> availableTimingReciterCodes;
  final Set<String> availableTimingFiles;

  static Future<TimingAssetIndex> load() {
    return _cachedIndex ??= _loadFromManifest();
  }

  static Future<TimingAssetIndex> _loadFromManifest() async {
    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        rootBundle,
      );
      return TimingAssetIndex.fromAssetPaths(manifest.listAssets());
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to load timing asset manifest: $error');
      }
      return const TimingAssetIndex._(
        availableTimingReciterCodes: <String>{},
        availableTimingFiles: <String>{},
      );
    }
  }

  static TimingAssetIndex fromAssetPaths(Iterable<String> assetPaths) {
    final Set<String> reciterCodes = <String>{};
    final Set<String> timingFiles = <String>{};

    for (final String assetPath in assetPaths) {
      final RegExpMatch? match = _timingAssetPattern.firstMatch(assetPath);
      if (match == null) continue;

      final String reciterCode = match.group(1)!.trim();
      final String fileName = match.group(2)!;
      if (reciterCode.isEmpty || !_isTimingFileName(fileName)) continue;

      reciterCodes.add(reciterCode);
      timingFiles.add(assetPath);
    }

    return TimingAssetIndex._(
      availableTimingReciterCodes: Set<String>.unmodifiable(reciterCodes),
      availableTimingFiles: Set<String>.unmodifiable(timingFiles),
    );
  }

  bool hasTimingSupportForReciter(String code) {
    return availableTimingReciterCodes.contains(_normalizeReciterCode(code));
  }

  bool hasTimingForSurah({
    required String reciterCode,
    required int surahNumber,
  }) {
    return timingPathForSurah(
          reciterCode: reciterCode,
          surahNumber: surahNumber,
        ) !=
        null;
  }

  String? timingPathForSurah({
    required String reciterCode,
    required int surahNumber,
  }) {
    final String normalizedCode = _normalizeReciterCode(reciterCode);
    if (normalizedCode.isEmpty) return null;

    for (final String path in _candidateSurahTimingPaths(
      reciterCode: normalizedCode,
      surahNumber: surahNumber,
    )) {
      if (availableTimingFiles.contains(path)) return path;
    }
    return null;
  }

  static List<String> _candidateSurahTimingPaths({
    required String reciterCode,
    required int surahNumber,
  }) {
    final int normalizedSurah = surahNumber.clamp(1, 114).toInt();
    final String paddedSurah = normalizedSurah.toString().padLeft(3, '0');
    return <String>[
      '$timingAssetRoot$reciterCode/$paddedSurah.txt',
      '$timingAssetRoot$reciterCode/$normalizedSurah.txt',
      '$timingAssetRoot$reciterCode/$paddedSurah.json',
      '$timingAssetRoot$reciterCode/$normalizedSurah.json',
    ];
  }

  static bool _isTimingFileName(String fileName) {
    final String lowerFileName = fileName.toLowerCase();
    if (!lowerFileName.endsWith('.txt') && !lowerFileName.endsWith('.json')) {
      return false;
    }
    final int extensionIndex = lowerFileName.lastIndexOf('.');
    final String stem = lowerFileName.substring(0, extensionIndex);
    final int? surahNumber = int.tryParse(stem);
    return surahNumber != null && surahNumber >= 1 && surahNumber <= 114;
  }

  static String _normalizeReciterCode(String code) => code.trim();
}
