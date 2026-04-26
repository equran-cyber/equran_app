import 'package:quran/quran.dart' as quran;

const String quranBasmalaText = 'بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ';

String favouriteAyahKey(int chapter, int verse) {
  return '$chapter-${verse.toString().padLeft(3, '0')}';
}

String arabicVerseNumber(int verse) {
  const Map<String, String> arabicDigits = <String, String>{
    '0': '٠',
    '1': '١',
    '2': '٢',
    '3': '٣',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '٧',
    '8': '٨',
    '9': '٩',
  };

  return verse
      .toString()
      .split('')
      .map((digit) => arabicDigits[digit] ?? digit)
      .join();
}

String quranVerseText(
  int chapter,
  int verse, {
  bool includeVerseNumber = false,
}) {
  String verseText = quran.getVerse(chapter, verse);
  if (verse == 1 && chapter != 1) {
    verseText = verseText.replaceAll(quranBasmalaText, '');
  }

  if (!includeVerseNumber) return verseText;
  return '$verseText ${arabicVerseNumber(verse)}';
}

String inlineQuranVerseSegment(int chapter, int verse) {
  return '\u2067${quranVerseText(chapter, verse, includeVerseNumber: true)}\u2069  ';
}

double shareArabicFontSizeForText(String verseText) {
  final int ayahLength = verseText.runes.length;
  return switch (ayahLength) {
    <= 80 => 86,
    <= 140 => 76,
    <= 220 => 66,
    <= 360 => 60,
    <= 520 => 52,
    <= 760 => 46,
    <= 980 => 42,
    _ => 36,
  };
}

double shareTranslationFontSizeForText(String verseText) {
  final int ayahLength = verseText.runes.length;
  return switch (ayahLength) {
    <= 360 => 22,
    <= 760 => 20,
    <= 980 => 18,
    _ => 17,
  };
}
