import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class DailyGuidanceEntry {
  const DailyGuidanceEntry({
    required this.title,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.reference,
  });

  final String title;
  final String arabic;
  final String transliteration;
  final String translation;
  final String reference;

  factory DailyGuidanceEntry.fromJson(Map<String, dynamic> json) {
    return DailyGuidanceEntry(
      title: (json['title'] as String? ?? '').trim(),
      arabic: (json['arabic'] as String? ?? '').trim(),
      transliteration: (json['transliteration'] as String? ?? '').trim(),
      translation: (json['translation'] as String? ?? '').trim(),
      reference: (json['reference'] as String? ?? '').trim(),
    );
  }

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final String normalized = query.toLowerCase();
    return title.toLowerCase().contains(normalized) ||
        translation.toLowerCase().contains(normalized) ||
        transliteration.toLowerCase().contains(normalized) ||
        reference.toLowerCase().contains(normalized);
  }
}

class DailyGuidanceCategory {
  const DailyGuidanceCategory({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<DailyGuidanceEntry> items;

  factory DailyGuidanceCategory.fromJson(Map<String, dynamic> json) {
    final List<dynamic> itemsRaw =
        json['items'] as List<dynamic>? ?? <dynamic>[];
    return DailyGuidanceCategory(
      id: (json['id'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(DailyGuidanceEntry.fromJson)
          .toList(),
    );
  }
}

class DailyGuidanceService {
  DailyGuidanceService._();

  static final DailyGuidanceService instance = DailyGuidanceService._();
  static const String _assetPath = 'assets/content/daily_hadith_duas.json';

  List<DailyGuidanceCategory>? _cache;

  Future<List<DailyGuidanceCategory>> loadCategories() async {
    final List<DailyGuidanceCategory>? cached = _cache;
    if (cached != null) return cached;

    final String raw = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> decoded =
        jsonDecode(raw) as Map<String, dynamic>;
    final List<dynamic> categoriesRaw =
        decoded['categories'] as List<dynamic>? ?? <dynamic>[];
    final List<DailyGuidanceCategory> categories = categoriesRaw
        .whereType<Map<String, dynamic>>()
        .map(DailyGuidanceCategory.fromJson)
        .toList();

    _cache = categories;
    return categories;
  }
}
