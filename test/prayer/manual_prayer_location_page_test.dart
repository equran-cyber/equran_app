import 'package:equran/prayer/manual_prayer_location_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual coordinate validation uses friendly errors', () {
    expect(
      validatePrayerCoordinate('', min: -90, max: 90, label: 'Latitude'),
      'Enter latitude.',
    );
    expect(
      validatePrayerCoordinate('abc', min: -90, max: 90, label: 'Latitude'),
      'Latitude should be a number.',
    );
    expect(
      validatePrayerCoordinate('91', min: -90, max: 90, label: 'Latitude'),
      'Latitude must be between -90 and 90.',
    );
    expect(
      validatePrayerCoordinate('-181', min: -180, max: 180, label: 'Longitude'),
      'Longitude must be between -180 and 180.',
    );
    expect(
      validatePrayerCoordinate('25.2', min: -90, max: 90, label: 'Latitude'),
      isNull,
    );
  });
}
