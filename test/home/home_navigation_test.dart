import 'package:equran/backend/library.dart' show SettingsDB;
import 'package:equran/home/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() async {
    await initTestHarness();
  });

  testWidgets('opens sidebar navigation and quick theme toggle persists', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(adaptiveTestApp(const HomePage()));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.dragFrom(const Offset(0, 300), const Offset(420, 0));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Prayer Times'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(SettingsDB().get('themeMode'), 'dark');
  });
}
