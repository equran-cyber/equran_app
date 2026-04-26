import 'package:quran/quran.dart' as quran;

class JuzGroup {
  const JuzGroup({required this.juzNumber, required this.entries});

  final int juzNumber;
  final List<JuzEntry> entries;
}

class JuzListItem {
  const JuzListItem.group(this.group) : entry = null;

  const JuzListItem.entry(this.entry) : group = null;

  final JuzGroup? group;
  final JuzEntry? entry;
}

class JuzEntry {
  const JuzEntry({
    required this.surahId,
    required this.transliteration,
    required this.name,
    required this.startVerse,
    required this.endVerse,
  });

  final int surahId;
  final String transliteration;
  final String name;
  final int startVerse;
  final int endVerse;

  bool matches(String query, int juzNumber) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return juzNumber.toString() == normalized ||
        juzNumber.toString().startsWith(normalized) ||
        transliteration.toLowerCase().contains(normalized) ||
        name.contains(query);
  }
}

List<JuzGroup> buildJuzGroups(String searchQuery) {
  final String query = searchQuery.trim().toLowerCase();
  final List<JuzGroup> groups = <JuzGroup>[];

  for (int juzNumber = 1; juzNumber <= 30; juzNumber++) {
    final Map<int, List<int>> juz = quran.getSurahAndVersesFromJuz(juzNumber);
    final List<JuzEntry> entries = <JuzEntry>[];

    juz.forEach((surahId, verses) {
      final JuzEntry entry = JuzEntry(
        surahId: surahId,
        transliteration: quran.getSurahName(surahId),
        name: quran.getSurahNameArabic(surahId),
        startVerse: verses[0],
        endVerse: verses[1],
      );

      if (query.isEmpty || entry.matches(query, juzNumber)) {
        entries.add(entry);
      }
    });

    if (entries.isNotEmpty) {
      groups.add(JuzGroup(juzNumber: juzNumber, entries: entries));
    }
  }

  return groups;
}

List<JuzListItem> buildJuzListItems(List<JuzGroup> groups) {
  final List<JuzListItem> items = <JuzListItem>[];
  for (final JuzGroup group in groups) {
    items.add(JuzListItem.group(group));
    for (final JuzEntry entry in group.entries) {
      items.add(JuzListItem.entry(entry));
    }
  }
  return items;
}
