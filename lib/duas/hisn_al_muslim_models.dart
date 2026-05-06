class DuaCategoryIndex {
  const DuaCategoryIndex({
    required this.id,
    required this.index,
    required this.title,
    required this.duaCount,
    required this.footnoteCount,
    required this.asset,
  });

  final String id;
  final int index;
  final String title;
  final int duaCount;
  final int footnoteCount;
  final String asset;

  bool matches(String query) {
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    return title.toLowerCase().contains(normalizedQuery);
  }
}

class DuaCategory {
  const DuaCategory({
    required this.id,
    required this.index,
    required this.title,
    required this.duas,
    required this.asset,
    required this.footnoteCount,
  });

  final String id;
  final int index;
  final String title;
  final List<DuaEntry> duas;
  final String asset;
  final int footnoteCount;
}

class DuaEntry {
  const DuaEntry({
    required this.id,
    required this.categoryId,
    required this.categoryTitle,
    required this.categoryIndex,
    required this.index,
    required this.text,
    this.reference,
    this.count,
    this.translation,
    this.transliteration,
    this.notes,
    this.source,
  });

  final String id;
  final String categoryId;
  final String categoryTitle;
  final int categoryIndex;
  final int index;
  final String text;
  final String? reference;
  final int? count;
  final String? translation;
  final String? transliteration;
  final String? notes;
  final String? source;

  String get legacyFavouriteId {
    return 'hisn-c${categoryIndex + 1}-d${index + 1}';
  }

  bool matches(String normalizedQuery) {
    return text.toLowerCase().contains(normalizedQuery) ||
        (reference?.toLowerCase().contains(normalizedQuery) ?? false) ||
        (translation?.toLowerCase().contains(normalizedQuery) ?? false) ||
        (transliteration?.toLowerCase().contains(normalizedQuery) ?? false) ||
        (notes?.toLowerCase().contains(normalizedQuery) ?? false) ||
        (source?.toLowerCase().contains(normalizedQuery) ?? false);
  }

  Map<String, Object?> toFavouriteSnapshot() {
    return <String, Object?>{
      'id': id,
      'categoryId': categoryId,
      'categoryTitle': categoryTitle,
      'categoryIndex': categoryIndex,
      'index': index,
      'text': text,
      if (reference != null) 'reference': reference,
      if (count != null) 'count': count,
      if (translation != null) 'translation': translation,
      if (transliteration != null) 'transliteration': transliteration,
      if (notes != null) 'notes': notes,
      if (source != null) 'source': source,
    };
  }

  static DuaEntry? fromFavouriteSnapshot(Object? value) {
    if (value is! Map) return null;

    final String? id = _stringOrNull(value['id']);
    final String? categoryId = _stringOrNull(value['categoryId']);
    final String? categoryTitle = _stringOrNull(value['categoryTitle']);
    final int? categoryIndex = _intOrNull(value['categoryIndex']);
    final int? index = _intOrNull(value['index']);
    final String? text = _stringOrNull(value['text']);

    if (id == null ||
        categoryId == null ||
        categoryTitle == null ||
        categoryIndex == null ||
        index == null ||
        text == null ||
        text.trim().isEmpty) {
      return null;
    }

    return DuaEntry(
      id: id,
      categoryId: categoryId,
      categoryTitle: categoryTitle,
      categoryIndex: categoryIndex,
      index: index,
      text: text,
      reference: _stringOrNull(value['reference']),
      count: _intOrNull(value['count']),
      translation: _stringOrNull(value['translation']),
      transliteration: _stringOrNull(value['transliteration']),
      notes: _stringOrNull(value['notes']),
      source: _stringOrNull(value['source']),
    );
  }

  String get shareText {
    return <String>[
      text,
      ?translation,
      ?transliteration,
      ?reference,
      ?source,
      ?notes,
      'Hisn al Muslim - $categoryTitle',
    ].join('\n\n');
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) return value.toString();
    return null;
  }

  static int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
