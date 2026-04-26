import 'package:equran/utils/juz_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('juz search', () {
    test('builds all 30 juz groups with no query', () {
      final List<JuzGroup> groups = buildJuzGroups('');

      expect(groups, hasLength(30));
      expect(groups.first.juzNumber, 1);
      expect(groups.first.entries.first.transliteration, 'Al Fatiha');
    });

    test('matches by juz number prefix and surah name', () {
      expect(buildJuzGroups('2').map((group) => group.juzNumber), contains(2));
      expect(
        buildJuzGroups('baqarah')
            .expand((group) => group.entries)
            .map((entry) => entry.transliteration),
        contains('Al Baqarah'),
      );
    });

    test('flattens groups into header and entry list items', () {
      final List<JuzListItem> items = buildJuzListItems(buildJuzGroups('1'));

      expect(items.first.group?.juzNumber, 1);
      expect(items.any((item) => item.entry != null), isTrue);
    });
  });
}
