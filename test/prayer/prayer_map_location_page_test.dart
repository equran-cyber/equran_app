import 'dart:io';

import 'package:equran/prayer/prayer_map_location_page.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a saveable prayer location from map coordinates', () {
    final PrayerLocation location = prayerLocationFromMapSelection(
      latitude: 12.34567,
      longitude: 76.54321,
    );

    expect(location.latitude, 12.34567);
    expect(location.longitude, 76.54321);
    expect(location.label, 'Selected location');
    expect(location.mode, PrayerLocationMode.manual);
  });

  test('formats map coordinate preview', () {
    expect(
      prayerMapCoordinatePreview(12.345678, 76.543219),
      '12.34568, 76.54322',
    );
  });

  test('does not include map API key references', () {
    final List<File> files = <File>[
      File('pubspec.yaml'),
      ...Directory('lib/prayer').listSync(recursive: true).whereType<File>(),
      ...Directory(
        'android/app/src',
      ).listSync(recursive: true).whereType<File>().where(_isTextSourceFile),
      ...Directory(
        'ios/Runner',
      ).listSync(recursive: true).whereType<File>().where(_isTextSourceFile),
    ];

    final List<String> forbidden = <String>[
      <String>['goo', 'gle', '_maps'].join(),
      <String>['Goo', 'gle', ' ', 'Maps'].join(),
      <String>['GOO', 'GLE', '_MAPS'].join(),
      <String>['com.', 'goo', 'gle', '.android.geo.', 'API', '_KEY'].join(),
    ];

    for (final File file in files) {
      final String content = file.readAsStringSync();
      for (final String pattern in forbidden) {
        expect(content, isNot(contains(pattern)));
      }
    }
  });
}

bool _isTextSourceFile(File file) {
  return file.path.endsWith('.dart') ||
      file.path.endsWith('.xml') ||
      file.path.endsWith('.gradle') ||
      file.path.endsWith('.kt') ||
      file.path.endsWith('.swift') ||
      file.path.endsWith('.plist') ||
      file.path.endsWith('.yaml');
}
