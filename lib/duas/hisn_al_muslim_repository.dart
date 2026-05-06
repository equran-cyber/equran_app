import 'dart:convert';

import 'package:equran/duas/hisn_al_muslim_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HisnAlMuslimRepository {
  HisnAlMuslimRepository({
    this.indexAssetPath = 'assets/contents/hisn/index.json',
  });

  final String indexAssetPath;

  Future<List<DuaCategoryIndex>>? _indexFuture;
  final Map<String, Future<DuaCategory>> _categoryByIdFutures =
      <String, Future<DuaCategory>>{};
  final Map<String, Future<DuaCategory>> _categoryByAssetFutures =
      <String, Future<DuaCategory>>{};

  Future<List<DuaCategoryIndex>> loadCategoryIndex() {
    return _indexFuture ??= _loadCategoryIndex().catchError((Object error) {
      _indexFuture = null;
      throw error;
    });
  }

  Future<DuaCategory> loadCategoryById(String id) {
    final String normalizedId = id.trim();
    if (!_isValidCategoryId(normalizedId)) {
      return Future<DuaCategory>.error(
        FormatException('Invalid Hisn category id: $id'),
      );
    }

    return _categoryByIdFutures.putIfAbsent(normalizedId, () async {
      final List<DuaCategoryIndex> index = await loadCategoryIndex();
      final DuaCategoryIndex entry = index.firstWhere(
        (DuaCategoryIndex category) => category.id == normalizedId,
        orElse: () => throw FormatException(
          'Hisn category $normalizedId was not found in the index.',
        ),
      );

      return loadCategoryByAsset(entry.asset);
    });
  }

  Future<DuaCategory> loadCategoryByAsset(String assetPath) {
    return _categoryByAssetFutures.putIfAbsent(assetPath, () async {
      final List<DuaCategoryIndex> index = await loadCategoryIndex();
      final int categoryIndex = index.indexWhere(
        (DuaCategoryIndex entry) => entry.asset == assetPath,
      );
      if (categoryIndex < 0) {
        throw FormatException(
          'Hisn category asset was not found in the index: $assetPath',
        );
      }

      final String rawJson = await rootBundle.loadString(assetPath);
      return compute(_parseCategoryJsonOnWorker, <String, Object?>{
        'rawJson': rawJson,
        'assetPath': assetPath,
        'categoryIndex': categoryIndex,
      });
    });
  }

  Future<DuaEntry?> loadDuaById(String id) async {
    final _DuaIdParts? parts = _DuaIdParts.parse(id);
    if (parts == null) return null;

    final DuaCategory category = await loadCategoryById(parts.categoryId);
    if (parts.duaIndex < 0 || parts.duaIndex >= category.duas.length) {
      return null;
    }

    return category.duas[parts.duaIndex];
  }

  Future<List<DuaCategoryIndex>> _loadCategoryIndex() async {
    final String rawJson = await rootBundle.loadString(indexAssetPath);
    final List<DuaCategoryIndex> index = await compute(
      _parseIndexJsonOnWorker,
      rawJson,
    );
    if (index.isEmpty) {
      throw const FormatException('No Hisn al Muslim categories were found.');
    }
    return index;
  }
}

List<DuaCategoryIndex> _parseIndexJsonOnWorker(String rawJson) {
  final Object? decoded = jsonDecode(rawJson);
  if (decoded is! List) return const <DuaCategoryIndex>[];

  return decoded
      .asMap()
      .entries
      .map((MapEntry<int, dynamic> entry) {
        final Object? value = entry.value;
        if (value is! Map) return null;

        final String? id = _stringOrNull(value['id']);
        final String? title = _stringOrNull(value['title']);
        final String? asset = _stringOrNull(value['asset']);
        final int? duaCount = _intOrNull(value['duaCount']);
        final int? footnoteCount = _intOrNull(value['footnoteCount']);

        if (id == null ||
            !_isValidCategoryId(id) ||
            title == null ||
            title.trim().isEmpty ||
            asset == null ||
            asset.trim().isEmpty ||
            duaCount == null ||
            duaCount < 0 ||
            footnoteCount == null ||
            footnoteCount < 0) {
          return null;
        }

        return DuaCategoryIndex(
          id: id,
          index: entry.key,
          title: title,
          duaCount: duaCount,
          footnoteCount: footnoteCount,
          asset: asset,
        );
      })
      .whereType<DuaCategoryIndex>()
      .toList(growable: false);
}

DuaCategory _parseCategoryJsonOnWorker(Map<String, Object?> message) {
  final String rawJson = message['rawJson']! as String;
  final String assetPath = message['assetPath']! as String;
  final int categoryIndex = message['categoryIndex']! as int;
  final Object? decoded = jsonDecode(rawJson);

  if (decoded is! Map) {
    throw FormatException('Hisn category asset is malformed: $assetPath');
  }

  final String? id = _stringOrNull(decoded['id']);
  final String? title = _stringOrNull(decoded['title']);
  if (id == null || !_isValidCategoryId(id)) {
    throw FormatException('Hisn category asset has an invalid id: $assetPath');
  }
  if (title == null || title.trim().isEmpty) {
    throw FormatException('Hisn category asset has no title: $assetPath');
  }

  final List<String> references = _stringListFrom(
    decoded['footnote'] ?? decoded['reference'] ?? decoded['references'],
  );
  final Object? textValue =
      decoded['text'] ?? decoded['duas'] ?? decoded['items'] ?? decoded['data'];
  final List<DuaEntry> duas = _parseDuas(
    textValue,
    references,
    categoryId: id,
    categoryIndex: categoryIndex,
    categoryTitle: title,
  );

  if (duas.isEmpty) {
    throw FormatException('Hisn category has no duas: $assetPath');
  }

  return DuaCategory(
    id: id,
    index: categoryIndex,
    title: title,
    duas: duas,
    asset: assetPath,
    footnoteCount: references.length,
  );
}

List<DuaEntry> _parseDuas(
  Object? value,
  List<String> references, {
  required String categoryId,
  required int categoryIndex,
  required String categoryTitle,
}) {
  if (value is List) {
    return value
        .asMap()
        .entries
        .map((MapEntry<int, dynamic> entry) {
          return _parseDua(
            entry.value,
            categoryId: categoryId,
            categoryIndex: categoryIndex,
            categoryTitle: categoryTitle,
            duaIndex: entry.key,
            fallbackReference: entry.key < references.length
                ? references[entry.key]
                : null,
          );
        })
        .whereType<DuaEntry>()
        .toList(growable: false);
  }

  final DuaEntry? dua = _parseDua(
    value,
    categoryId: categoryId,
    categoryIndex: categoryIndex,
    categoryTitle: categoryTitle,
    duaIndex: 0,
    fallbackReference: references.isEmpty ? null : references.first,
  );
  return dua == null ? const <DuaEntry>[] : <DuaEntry>[dua];
}

DuaEntry? _parseDua(
  Object? value, {
  required String categoryId,
  required int categoryIndex,
  required String categoryTitle,
  required int duaIndex,
  String? fallbackReference,
}) {
  if (value is String) {
    final String text = value.trim();
    if (text.isEmpty) return null;
    return DuaEntry(
      id: _duaId(categoryId, duaIndex),
      categoryId: categoryId,
      categoryTitle: categoryTitle,
      categoryIndex: categoryIndex,
      index: duaIndex,
      text: text,
      reference: _cleanString(fallbackReference),
    );
  }

  if (value is! Map) return null;

  final String? text = _firstString(value, const <String>[
    'text',
    'arabic',
    'dua',
    'content',
  ]);
  if (text == null || text.trim().isEmpty) return null;

  return DuaEntry(
    id: _duaId(categoryId, duaIndex),
    categoryId: categoryId,
    categoryTitle: categoryTitle,
    categoryIndex: categoryIndex,
    index: duaIndex,
    text: text.trim(),
    reference:
        _firstString(value, const <String>[
          'reference',
          'footnote',
          'source_reference',
        ]) ??
        _cleanString(fallbackReference),
    count: _intOrNull(value['count'] ?? value['repeat']),
    translation: _firstString(value, const <String>['translation', 'meaning']),
    transliteration: _firstString(value, const <String>[
      'transliteration',
      'latin',
    ]),
    notes: _firstString(value, const <String>['notes', 'note']),
    source: _firstString(value, const <String>['source']),
  );
}

String _duaId(String categoryId, int duaIndex) {
  return '${categoryId}_${duaIndex.toString().padLeft(3, '0')}';
}

bool _isValidCategoryId(String value) {
  return RegExp(r'^\d{3}$').hasMatch(value);
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

class _DuaIdParts {
  const _DuaIdParts({required this.categoryId, required this.duaIndex});

  final String categoryId;
  final int duaIndex;

  static _DuaIdParts? parse(String value) {
    final RegExpMatch? newMatch = RegExp(
      r'^(\d{3})_(\d{3})$',
    ).firstMatch(value);
    if (newMatch != null) {
      return _DuaIdParts(
        categoryId: newMatch.group(1)!,
        duaIndex: int.parse(newMatch.group(2)!),
      );
    }

    final RegExpMatch? legacyMatch = RegExp(
      r'^hisn-c(\d+)-d(\d+)$',
    ).firstMatch(value);
    if (legacyMatch == null) return null;

    final int categoryNumber = int.parse(legacyMatch.group(1)!);
    final int duaNumber = int.parse(legacyMatch.group(2)!);
    if (categoryNumber < 1 || duaNumber < 1) return null;

    return _DuaIdParts(
      categoryId: categoryNumber.toString().padLeft(3, '0'),
      duaIndex: duaNumber - 1,
    );
  }
}
