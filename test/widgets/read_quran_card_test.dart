import 'package:equran/backend/library.dart' show FavouritesDB;
import 'package:equran/utils/quran_text.dart';
import 'package:equran/widgets/read_quran_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;

import '../helpers/test_harness.dart';

Future<void> pumpBounded(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

void main() {
  setUp(() async {
    await initTestHarness().timeout(const Duration(seconds: 10));

    // Ensure this test always starts from a clean favourite state.
    if (FavouritesDB().contains(favouriteAyahKey(1, 1))) {
      FavouritesDB().delete(favouriteAyahKey(1, 1));
    }
  });

  Future<void> tapMenuAction(WidgetTester tester, String label) async {
    final Finder labelFinder = find.text(label);
    expect(labelFinder, findsOneWidget);

    final Finder inkWellFinder = find.ancestor(
      of: labelFinder,
      matching: find.byType(InkWell),
    );

    if (inkWellFinder.evaluate().isNotEmpty) {
      final InkWell inkWell = tester.widget<InkWell>(inkWellFinder.first);
      expect(inkWell.onTap, isNotNull);
      inkWell.onTap!();
      await pumpBounded(tester);
      return;
    }

    final Finder listTileFinder = find.ancestor(
      of: labelFinder,
      matching: find.byType(ListTile),
    );

    if (listTileFinder.evaluate().isNotEmpty) {
      final ListTile tile = tester.widget<ListTile>(listTileFinder.first);
      expect(tile.onTap, isNotNull);
      tile.onTap!();
      await pumpBounded(tester);
      return;
    }

    fail('No tappable ancestor found for "$label".');
  }

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

  testWidgets(
    'renders card view text, translation, and transliteration',
    (WidgetTester tester) async {
      await tester.pumpWidget(card());
      await pumpBounded(tester);

      expect(find.text("Juz' 1"), findsOneWidget);
      expect(find.text('Ayah 1 of 7'), findsOneWidget);
      expect(find.text(quran.getVerse(1, 1)), findsOneWidget);
      expect(find.text('Bismi Allahi alrrahmani alrraheemi'), findsOneWidget);
      expect(
        find.text('In the name of Allah, the Entirely Merciful.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'hides translation and transliteration when disabled',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        card(showTranslation: false, showTransliteration: false),
      );
      await pumpBounded(tester);

      expect(find.text('Bismi Allahi alrrahmani alrraheemi'), findsNothing);
      expect(
        find.text('In the name of Allah, the Entirely Merciful.'),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'supports favourite and share actions from overflow menu',
    (WidgetTester tester) async {
      int shareCount = 0;

      await tester.pumpWidget(card(onShare: () => shareCount++));
      await pumpBounded(tester);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await pumpBounded(tester);

      await tapMenuAction(tester, 'Favourite');

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Daily recitation');
      await pumpBounded(tester);

      final Finder saveButton = find.textContaining(
        RegExp(r'^save$', caseSensitive: false),
      );
      expect(saveButton, findsOneWidget);

      await tester.tap(saveButton);
      await pumpBounded(tester);

      expect(FavouritesDB().contains(favouriteAyahKey(1, 1)), isTrue);
      expect(FavouritesDB().get(favouriteAyahKey(1, 1)), 'Daily recitation');

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await pumpBounded(tester);

      await tapMenuAction(tester, 'Share image');

      expect(shareCount, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
