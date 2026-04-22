import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class QuranTransliterationService {
  QuranTransliterationService._();

  static final QuranTransliterationService instance =
      QuranTransliterationService._();

  static const String _assetPath =
      'assets/transliteration/quran_json_en_transliteration.json';

  Map<int, List<String>>? _cache;

  Future<Map<int, List<String>>> _loadAll() async {
    final Map<int, List<String>>? cached = _cache;
    if (cached != null) return cached;

    final String raw = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> decoded = jsonDecode(raw);
    final Map<int, List<String>> parsed = <int, List<String>>{};

    for (final MapEntry<String, dynamic> entry in decoded.entries) {
      final int? surah = int.tryParse(entry.key);
      final dynamic versesRaw = entry.value;
      if (surah == null || versesRaw is! List<dynamic>) continue;
      parsed[surah] = versesRaw.map((item) => item?.toString() ?? '').toList();
    }

    _cache = parsed;
    return parsed;
  }

  Future<List<String>> versesForSurah(int surah) async {
    final Map<int, List<String>> data = await _loadAll();
    return data[surah] ?? const <String>[];
  }

  Future<String> verseTransliteration(int surah, int ayah) async {
    final List<String> surahVerses = await versesForSurah(surah);
    if (ayah < 1 || ayah > surahVerses.length) return '';
    return surahVerses[ayah - 1];
  }
}
