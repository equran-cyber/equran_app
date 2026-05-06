class HisnCategory {
  const HisnCategory({
    required this.title,
    required this.duas,
  });

  final String title;
  final List<HisnDua> duas;

  bool matches(String query) {
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    if (title.toLowerCase().contains(normalizedQuery)) return true;
    return duas.any((HisnDua dua) => dua.matches(normalizedQuery));
  }

  HisnCategory filtered(String query) {
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty || title.toLowerCase().contains(normalizedQuery)) {
      return this;
    }

    return HisnCategory(
      title: title,
      duas: duas
          .where((HisnDua dua) => dua.matches(normalizedQuery))
          .toList(growable: false),
    );
  }
}

class HisnDua {
  const HisnDua({
    required this.text,
    this.reference,
    this.count,
    this.translation,
    this.transliteration,
    this.notes,
    this.source,
  });

  final String text;
  final String? reference;
  final int? count;
  final String? translation;
  final String? transliteration;
  final String? notes;
  final String? source;

  bool matches(String normalizedQuery) {
    return text.toLowerCase().contains(normalizedQuery) ||
        (reference?.toLowerCase().contains(normalizedQuery) ?? false) ||
        (translation?.toLowerCase().contains(normalizedQuery) ?? false) ||
        (transliteration?.toLowerCase().contains(normalizedQuery) ?? false) ||
        (notes?.toLowerCase().contains(normalizedQuery) ?? false) ||
        (source?.toLowerCase().contains(normalizedQuery) ?? false);
  }
}
