import 'package:equran/utils/saved_ayah.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('saved ayah parsing', () {
    test('parses valid favourite keys and ignores malformed keys', () {
      final List<SavedAyah> ayahs = savedAyahsFromKeys(
        keys: <String>['2-255', 'bad', '1-x', '1-001'],
        noteForKey: (key) => key == '2-255' ? 'Ayat al-Kursi' : '',
      );

      expect(ayahs.map((ayah) => ayah.key), <String>['1-001', '2-255']);
      expect(ayahs.last.note, 'Ayat al-Kursi');
    });

    test('filters by surah, ayah label, and note', () {
      final List<String> keys = <String>['1-001', '2-255'];

      expect(
        savedAyahsFromKeys(
          keys: keys,
          noteForKey: (_) => '',
          searchQuery: 'fatiha',
        ).single.key,
        '1-001',
      );
      expect(
        savedAyahsFromKeys(
          keys: keys,
          noteForKey: (key) => key == '2-255' ? 'memorize' : '',
          searchQuery: 'memorize',
        ).single.key,
        '2-255',
      );
      expect(
        savedAyahsFromKeys(
          keys: keys,
          noteForKey: (_) => '',
          searchQuery: 'ayah 255',
        ).single.key,
        '2-255',
      );
    });
  });
}
