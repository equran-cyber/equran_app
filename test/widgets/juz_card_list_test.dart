import 'package:equran/widgets/juz_card_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../helpers/test_harness.dart';

Future<void> pumpBounded(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() async {
    await initTestHarness().timeout(const Duration(seconds: 10));
  });

  testWidgets(
    'renders page/Mushaf Juz results and supports search labels',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        materialTestApp(const JuzCardList(searchQuery: '')),
      );
      await pumpBounded(tester);

      expect(find.text("Juz' 1"), findsOneWidget);
      expect(find.text('Al Fatiha'), findsOneWidget);

      await tester.pumpWidget(
        materialTestApp(const JuzCardList(searchQuery: 'baqarah')),
      );
      await pumpBounded(tester);

      expect(find.text('Al Baqarah'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}