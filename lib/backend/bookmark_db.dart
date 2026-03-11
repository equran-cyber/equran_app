import 'package:collection/collection.dart' show minBy;
import 'package:equran/backend/reading_model.dart';

import 'base_db.dart';

class BookmarkDB extends BaseDB {
  BookmarkDB._privateConstructor() : super("bookmarks");

  static final BookmarkDB _instance = BookmarkDB._privateConstructor();

  factory BookmarkDB() {
    return _instance;
  }

  Future<void> addReadingEntry(int surah, int verse) async {
    final DateTime now = DateTime.now();
    final List<ReadingEntry> entries = box
        .toMap()
        .values
        .whereType<ReadingEntry>()
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Prevent inserting duplicate consecutive records.
    if (entries.isNotEmpty &&
        entries.first.surah == surah &&
        entries.first.verse == verse) {
      return;
    }

    await put(
      now.microsecondsSinceEpoch.toString(),
      ReadingEntry(surah: surah, verse: verse, timestamp: now),
    );

    while (length > 7) {
      removeOldestEntry();
    }
  }

  void removeOldestEntry() {
    final oldestEntry = minBy(
      box.toMap().entries.where((entry) => entry.value is ReadingEntry),
      (entry) => (entry.value as ReadingEntry).timestamp,
    );
    if (oldestEntry != null) {
      delete(oldestEntry.key);
    }
  }
}
