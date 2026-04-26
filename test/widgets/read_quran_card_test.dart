import 'package:equran/backend/library.dart' show FavouritesDB;
import 'package:equran/utils/quran_text.dart';
import 'package:equran/widgets/read_quran_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;

import '../helpers/test_harness.dart';

Future<void> pumpBounded(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    timeout: const Duration(seconds: 2),
  );
}

void main() {
  setUp(() async {
    await initTestHarness();
  });

  Widget card({
    bool showTranslation = true,
    bool showTransliteration = true,
    VoidCallback? onShare,
    VoidCallback? onDownload,
  }) {
    return materialTestApp(
      ReadQuranCard(
        currentChapter: 1,
        currentVerse: 1,
        totalVerses: 7,
        juzNumber: 1,
        translation: 'In the name of Allah, the Entirely Merciful.',
        transliteration: 'Bismi Allahi alrrahmani alrraheemi',
        verse: quran.getVerse(1, 1),
        fontSize: 31,
        fontSizeTranslation: 12,
        showTranslation: showTranslation,
        showTransliteration: showTransliteration,
        onShare: onShare,
        onDownload: onDownload,
        onPlay: () {},
        onTafsir: () {},
        onSwitchTranslation: () {},
      ),
    );
  }

  testWidgets('renders card view text, translation, and transliteration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(card());

    expect(find.text("Juz' 1"), findsOneWidget);
    expect(find.text('Ayah 1 of 7'), findsOneWidget);
    expect(find.text(quran.getVerse(1, 1)), findsOneWidget);
    expect(find.text('Bismi Allahi alrrahmani alrraheemi'), findsOneWidget);
    expect(
      find.text('In the name of Allah, the Entirely Merciful.'),
      findsOneWidget,
    );
  });

  testWidgets('hides translation and transliteration when disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      card(showTranslation: false, showTransliteration: false),
    );

    expect(find.text('Bismi Allahi alrrahmani alrraheemi'), findsNothing);
    expect(
      find.text('In the name of Allah, the Entirely Merciful.'),
      findsNothing,
    );
  });

  testWidgets('supports favourite and share actions from overflow menu', (
    WidgetTester tester,
  ) async {
    int shareCount = 0;
    await tester.pumpWidget(card(onShare: () => shareCount++));

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await pumpBounded(tester);
    await tester.tap(find.text('Favourite'));
    await pumpBounded(tester);
    await tester.enterText(find.byType(TextField), 'Daily recitation');
    await tester.tap(find.text('Save'));
    await pumpBounded(tester);

    expect(FavouritesDB().contains(favouriteAyahKey(1, 1)), isTrue);
    expect(FavouritesDB().get(favouriteAyahKey(1, 1)), 'Daily recitation');

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await pumpBounded(tester);
    await tester.tap(find.text('Share image'));
    await pumpBounded(tester);

    expect(shareCount, 1);
  });
}
