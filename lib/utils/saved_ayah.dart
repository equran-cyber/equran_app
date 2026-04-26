import 'package:quran/quran.dart' as quran;

class SavedAyah {
  const SavedAyah({
    required this.key,
    required this.surah,
    required this.verse,
    required this.note,
  });

  final String key;
  final int surah;
  final int verse;
  final String note;

  bool matches(String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return quran.getSurahName(surah).toLowerCase().contains(normalized) ||
        quran.getSurahNameArabic(surah).toLowerCase().contains(normalized) ||
        note.toLowerCase().contains(normalized) ||
        surah.toString() == normalized ||
        verse.toString() == normalized ||
        'ayah $verse'.contains(normalized);
  }
}

List<SavedAyah> savedAyahsFromKeys({
  required Iterable<dynamic> keys,
  required Object? Function(String key) noteForKey,
  String searchQuery = '',
}) {
  final List<SavedAyah> parsed = <SavedAyah>[];
  final String query = searchQuery.trim().toLowerCase();

  for (final dynamic raw in keys) {
    final String key = raw.toString();
    final List<String> parts = key.split('-');
    if (parts.length != 2) continue;

    final int? surah = int.tryParse(parts[0]);
    final int? verse = int.tryParse(parts[1]);
    if (surah == null || verse == null) continue;

    final SavedAyah ayah = SavedAyah(
      key: key,
      surah: surah,
      verse: verse,
      note: noteForKey(key)?.toString() ?? '',
    );
    if (query.isEmpty || ayah.matches(query)) {
      parsed.add(ayah);
    }
  }

  parsed.sort((a, b) {
    if (a.surah != b.surah) return a.surah.compareTo(b.surah);
    return a.verse.compareTo(b.verse);
  });
  return parsed;
}
