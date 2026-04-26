import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:equran/widgets/font_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;

import '../helpers/test_harness.dart';

void main() {
  setUp(() async {
    await initTestHarness();
  });

  testWidgets('updates font-size setting and preview from the slider', (
    WidgetTester tester,
  ) async {
    await SettingsDB().put('fontSize', 31.0);
    await SettingsDB().put('fontSizeTranslation', 12.0);
    await SettingsDB().put('translation', 0);

    await tester.pumpWidget(
      materialTestApp(const FontSlider(showTranslationControls: true)),
    );

    expect(find.text(quran.getVerse(1, 1)), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(quran.getVerse(1, 1))).style?.fontSize,
      31.0,
    );

    final Slider arabicFontSlider = tester.widget<Slider>(
      find.byType(Slider).first,
    );
    arabicFontSlider.onChanged?.call(45.0);
    await tester.pump(const Duration(milliseconds: 300));

    expect(SettingsDB().get('fontSize'), 45.0);
    expect(find.text('45'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(quran.getVerse(1, 1))).style?.fontSize,
      45.0,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
