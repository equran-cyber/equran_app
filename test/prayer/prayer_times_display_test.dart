import 'package:equran/prayer/prayer_times_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats calm countdown labels without seconds', () {
    expect(
      formatPrayerCountdownLabel(
        const Duration(hours: 7, minutes: 12, seconds: 18),
      ),
      'In 7h 13m',
    );
    expect(
      formatPrayerCountdownLabel(const Duration(minutes: 42, seconds: 59)),
      'In 43m',
    );
    expect(formatPrayerCountdownLabel(const Duration(minutes: 42)), 'In 42m');
    expect(
      formatPrayerCountdownLabel(const Duration(minutes: 4, seconds: 59)),
      'Very soon',
    );
    expect(formatPrayerCountdownLabel(Duration.zero), 'Now');
    expect(
      formatPrayerCountdownLabel(const Duration(minutes: 3), isNow: true),
      'Now',
    );
  });
}
