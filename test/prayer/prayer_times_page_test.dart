import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_settings_store.dart';
import 'package:equran/prayer/prayer_times_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(() async {
    await initSettingsTestHarness();
  });

  testWidgets('shows setup state when no location is selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      materialTestApp(
        PrayerTimesPage(
          enableLiveCountdown: false,
          initialNow: DateTime(2026, 5, 4, 10),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Choose your location to calculate prayer times'),
      findsOneWidget,
    );
    expect(find.text('Use current location'), findsOneWidget);
    expect(find.text('Choose manually'), findsOneWidget);
    expect(find.text('Fajr'), findsNothing);
    expect(
      find.textContaining('Prayer times are currently experimental'),
      findsOneWidget,
    );
  });

  testWidgets('renders calculated prayer times after location is selected', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() {
      return PrayerSettingsStore().saveLocation(
        const PrayerLocation(
          latitude: 35.78056,
          longitude: -78.6389,
          label: 'Test location',
          mode: PrayerLocationMode.manual,
        ),
      );
    });

    await tester.pumpWidget(
      materialTestApp(
        PrayerTimesPage(
          enableLiveCountdown: false,
          initialNow: DateTime(2026, 5, 4, 10),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Test location'), findsOneWidget);
    expect(find.text('Next prayer'), findsOneWidget);
    expect(find.textContaining('Muslim World League'), findsOneWidget);
    expect(find.text('Fajr'), findsWidgets);
    expect(find.text('Sunrise'), findsWidgets);
    expect(find.text('Dhuhr'), findsWidgets);
    expect(find.text('Asr'), findsWidgets);
    expect(find.text('Maghrib'), findsWidgets);
    expect(find.text('Isha'), findsWidgets);
    expect(PrayerTimeKind.displayOrder.length, 6);
  });
}
