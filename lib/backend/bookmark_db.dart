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
    final ReadingEntry? existing = get(surah) as ReadingEntry?;
    if (existing != null && existing.verse == verse) {
      return;
    }

    final entries = box.toMap().entries.where((entry) {
      final value = entry.value;
      return value is ReadingEntry &&
          value.surah == surah &&
          entry.key != surah;
    });
    for (final entry in entries) {
      await delete(entry.key);
    }

    await put(
      surah,
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
