import 'package:equran/utils/number_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('number formatting', () {
    test('formats compact slider labels', () {
      expect(formatCompactNumber(31.0), '31');
      expect(formatCompactNumber(12.345), '12.3');
      expect(formatCompactNumber(9.99), '9.99');
    });

    test('formats durations for players', () {
      expect(formatDurationLabel(const Duration(seconds: 7)), '00:07');
      expect(
        formatDurationLabel(const Duration(minutes: 3, seconds: 4)),
        '03:04',
      );
      expect(
        formatDurationLabel(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
    });
  });
}
