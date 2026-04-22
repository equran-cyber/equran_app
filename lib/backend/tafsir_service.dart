import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

enum TafsirSource {
  mukhtasar('en_al_mukhtasar', 'Abridged Explanation of the Quran');

  const TafsirSource(this.key, this.displayName);

  final String key;
  final String displayName;
}

class TafsirService {
  TafsirService._();

  static final TafsirService instance = TafsirService._();

  static const String _assetPath =
      'assets/tafsir/en_al_mukhtasar/abridged-explanation-of-the-quran.json';

  Map<String, String>? _cache;

  Future<Map<String, String>> _loadAll() async {
    final Map<String, String>? cached = _cache;
    if (cached != null) return cached;

    final String raw = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> decoded =
        jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, String> mapped = <String, String>{};

    String resolveText(String key, [Set<String>? seen]) {
      final Set<String> visited = seen ?? <String>{};
      if (!visited.add(key)) return '';

      final dynamic rawValue = decoded[key];
      if (rawValue is String) {
        return resolveText(rawValue, visited);
      }
      if (rawValue is Map<String, dynamic>) {
        return (rawValue['text'] as String? ?? '').trim();
      }
      return '';
    }

    for (final String key in decoded.keys) {
      final String text = resolveText(key);
      if (text.isNotEmpty) mapped[key] = text;
    }

    _cache = mapped;
    return mapped;
  }

  Future<String> verseTafsir({
    required TafsirSource source,
    required int surah,
    required int ayah,
  }) async {
    final Map<String, String> tafsir = await _loadAll();
    return tafsir['$surah:$ayah'] ?? '';
  }
}
