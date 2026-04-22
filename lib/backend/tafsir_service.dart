import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

enum TafsirSource {
  jalalayn('en_jalalayn', 'Tafsir al-Jalalayn (EN)');

  const TafsirSource(this.key, this.displayName);

  final String key;
  final String displayName;
}

class TafsirService {
  TafsirService._();

  static final TafsirService instance = TafsirService._();

  final Map<String, Map<int, String>> _cache = <String, Map<int, String>>{};

  String _assetPath(TafsirSource source, int surah) {
    switch (source) {
      case TafsirSource.jalalayn:
        return 'assets/tafsir/en_al_jalalayn/$surah.json';
    }
  }

  Future<Map<int, String>> _loadSurah({
    required TafsirSource source,
    required int surah,
  }) async {
    final String cacheKey = '${source.key}_$surah';
    final Map<int, String>? cached = _cache[cacheKey];
    if (cached != null) return cached;

    final String raw = await rootBundle.loadString(_assetPath(source, surah));
    final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
    final List<dynamic> ayahs = decoded['ayahs'] as List<dynamic>? ?? <dynamic>[];
    final Map<int, String> mapped = <int, String>{};

    for (final dynamic ayahRaw in ayahs) {
      if (ayahRaw is! Map<String, dynamic>) continue;
      final int? ayah = ayahRaw['ayah'] as int?;
      final String text = (ayahRaw['text'] as String? ?? '').trim();
      if (ayah != null && text.isNotEmpty) {
        mapped[ayah] = text;
      }
    }

    _cache[cacheKey] = mapped;
    return mapped;
  }

  Future<String> verseTafsir({
    required TafsirSource source,
    required int surah,
    required int ayah,
  }) async {
    final Map<int, String> surahTafsir = await _loadSurah(
      source: source,
      surah: surah,
    );
    return surahTafsir[ayah] ?? '';
  }
}
