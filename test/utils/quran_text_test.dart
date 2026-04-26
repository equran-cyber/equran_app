import 'package:equran/utils/quran_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;

void main() {
  group('quran text helpers', () {
    test('formats favourite keys with padded ayah numbers', () {
      expect(favouriteAyahKey(2, 5), '2-005');
      expect(favouriteAyahKey(114, 6), '114-006');
    });

    test('formats Arabic verse numbers', () {
      expect(arabicVerseNumber(1), '١');
      expect(arabicVerseNumber(286), '٢٨٦');
    });

    test('removes basmala from first ayah text outside Al-Fatihah', () {
      final String baqarah = quranVerseText(2, 1);

      expect(baqarah, isNot(contains(quranBasmalaText)));
      expect(quranVerseText(1, 1), contains(quranBasmalaText));
    });

    test('can append verse number for inline Mushaf text', () {
      expect(quranVerseText(1, 1, includeVerseNumber: true), endsWith(' ١'));
      expect(inlineQuranVerseSegment(1, 1), startsWith('\u2067'));
      expect(inlineQuranVerseSegment(1, 1), endsWith('\u2069  '));
    });

    test('scales share-image fonts by ayah length', () {
      expect(shareArabicFontSizeForText('a' * 40), 86);
      expect(shareArabicFontSizeForText('a' * 400), 52);
      expect(shareArabicFontSizeForText('a' * 1000), 36);
      expect(shareTranslationFontSizeForText('a' * 40), 22);
      expect(shareTranslationFontSizeForText('a' * 900), 18);
    });

    test('matches package Quran text for ordinary ayahs', () {
      expect(quranVerseText(3, 2), quran.getVerse(3, 2));
    });
  });
}
