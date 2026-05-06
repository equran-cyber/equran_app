import 'dart:convert';

import 'package:equran/duas/hisn_al_muslim_models.dart';
import 'package:flutter/services.dart';

class HisnAlMuslimRepository {
  const HisnAlMuslimRepository({
    this.assetPath = 'assets/content/hisn_al_muslim.json',
  });

  final String assetPath;

  Future<List<HisnCategory>> loadCategories() async {
    final String rawJson = await rootBundle.loadString(assetPath);
    final Object? decoded = jsonDecode(rawJson);
    final List<HisnCategory> categories = _parseCategories(decoded);
    if (categories.isEmpty) {
      throw const FormatException('No duas were found in Hisn al Muslim.');
    }
    return categories;
  }

  List<HisnCategory> _parseCategories(Object? decoded) {
    if (decoded is Map) {
      return decoded.entries
          .map((MapEntry<dynamic, dynamic> entry) {
            return _parseCategory(
              _stringOrNull(entry.key) ?? '',
              entry.value,
            );
          })
          .whereType<HisnCategory>()
          .toList(growable: false);
    }

    if (decoded is List) {
      return decoded
          .map((Object? item) => _parseCategory(null, item))
          .whereType<HisnCategory>()
          .toList(growable: false);
    }

    return const <HisnCategory>[];
  }

  HisnCategory? _parseCategory(String? fallbackTitle, Object? value) {
    if (value is! Map) return null;

    final String title =
        _firstString(value, const <String>['category', 'title', 'name']) ??
            fallbackTitle ??
            '';
    if (title.trim().isEmpty) return null;

    final List<String> references = _stringListFrom(
      value['footnote'] ?? value['reference'] ?? value['references'],
    );
    final Object? textValue =
        value['text'] ?? value['duas'] ?? value['items'] ?? value['data'];
    final List<HisnDua> duas = _parseDuas(textValue, references);
    if (duas.isEmpty) return null;

    return HisnCategory(title: title.trim(), duas: duas);
  }

  List<HisnDua> _parseDuas(Object? value, List<String> references) {
    if (value is List) {
      return value
          .asMap()
          .entries
          .map((MapEntry<int, dynamic> entry) {
            return _parseDua(
              entry.value,
              fallbackReference:
                  entry.key < references.length ? references[entry.key] : null,
            );
          })
          .whereType<HisnDua>()
          .toList(growable: false);
    }

    final HisnDua? dua = _parseDua(
      value,
      fallbackReference: references.isEmpty ? null : references.join('\n'),
    );
    return dua == null ? const <HisnDua>[] : <HisnDua>[dua];
  }

  HisnDua? _parseDua(Object? value, {String? fallbackReference}) {
    if (value is String) {
      final String text = value.trim();
      if (text.isEmpty) return null;
      return HisnDua(text: text, reference: _cleanString(fallbackReference));
    }

    if (value is! Map) return null;

    final String? text = _firstString(
      value,
      const <String>['text', 'arabic', 'dua', 'content'],
    );
    if (text == null || text.trim().isEmpty) return null;

    return HisnDua(
      text: text.trim(),
      reference: _firstString(
            value,
            const <String>['reference', 'footnote', 'source_reference'],
          ) ??
          _cleanString(fallbackReference),
      count: _intOrNull(value['count'] ?? value['repeat']),
      translation: _firstString(value, const <String>['translation', 'meaning']),
      transliteration: _firstString(
        value,
        const <String>['transliteration', 'latin'],
      ),
      notes: _firstString(value, const <String>['notes', 'note']),
      source: _firstString(value, const <String>['source']),
    );
  }

  String? _firstString(Map<dynamic, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final String? value = _stringOrNull(map[key]);
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  List<String> _stringListFrom(Object? value) {
    if (value is List) {
      return value
          .map(_stringOrNull)
          .whereType<String>()
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toList(growable: false);
    }
    final String? single = _stringOrNull(value);
    return single == null || single.trim().isEmpty
        ? const <String>[]
        : <String>[single.trim()];
  }

  String? _cleanString(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _stringOrNull(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      final List<String> values = value
          .map(_stringOrNull)
          .whereType<String>()
          .where((String item) => item.trim().isNotEmpty)
          .toList(growable: false);
      return values.isEmpty ? null : values.join('\n');
    }
    return null;
  }

  int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
