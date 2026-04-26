import 'package:equran/backend/library.dart' show BookmarkDB, ReadingEntry;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() async {
    await initTestHarness();
  });

  group('BookmarkDB', () {
    test('stores reading progress and removes verse-one progress', () async {
      await BookmarkDB().addReadingEntry(2, 12);

      expect(BookmarkDB().contains(2), isTrue);
      expect((BookmarkDB().get(2) as ReadingEntry).verse, 12);

      await BookmarkDB().addReadingEntry(2, 1);

      expect(BookmarkDB().contains(2), isFalse);
    });

    test('keeps the seven most recent reading entries', () async {
      for (int surah = 1; surah <= 9; surah++) {
        await BookmarkDB().addReadingEntry(surah, 2);
      }

      expect(BookmarkDB().length, 7);
      expect(BookmarkDB().contains(1), isFalse);
      expect(BookmarkDB().contains(2), isFalse);
      expect(BookmarkDB().contains(9), isTrue);
    });
  });
}
