import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:equran/backend/library.dart'
    show
        BookmarkDB,
        FavouritesDB,
        ReadingEntryAdapter,
        SettingsDB,
        SurahAdapter,
        SurahDB;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Directory? _hiveDirectory;
Directory? _documentsDirectory;
bool _hiveInitialized = false;

Future<void> initSettingsTestHarness() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();

  _mockPathProvider();

  if (!_hiveInitialized) {
    _hiveDirectory = Directory.systemTemp.createTempSync('equran_hive_test_');
    Hive.init(_hiveDirectory!.path);
    _hiveInitialized = true;
  }

  await SettingsDB().initBox();

  // Clear only settings for this test.
  // Use your actual settings box name if different.
  if (Hive.isBoxOpen('settings')) {
    await Hive.box('settings').clear();
  }
}

Future<void> initTestHarness() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  GoogleFonts.config.allowRuntimeFetching = false;

  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();

  _mockPathProvider();

  if (!_hiveInitialized) {
    _hiveDirectory = Directory.systemTemp.createTempSync('equran_hive_test_');

    Hive.init(_hiveDirectory!.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ReadingEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SurahAdapter());
    }

    await BookmarkDB().initBox().timeout(const Duration(seconds: 3));

    await SettingsDB().initBox().timeout(const Duration(seconds: 3));

    await SurahDB().initBox().timeout(const Duration(seconds: 3));

    await FavouritesDB().initBox().timeout(const Duration(seconds: 3));

    _hiveInitialized = true;
  }

  await clearTestData().timeout(const Duration(seconds: 3));
}

Future<void> clearTestData() async {
  if (Hive.isBoxOpen('bookmarks')) {
    await Hive.box('bookmarks').clear().timeout(const Duration(seconds: 3));
  }

  if (Hive.isBoxOpen('settings')) {
    await Hive.box('settings').clear().timeout(const Duration(seconds: 3));
  }

  if (Hive.isBoxOpen('surahs')) {
    await Hive.box('surahs').clear().timeout(const Duration(seconds: 3));
  }

  if (Hive.isBoxOpen('favourites')) {
    await Hive.box('favourites').clear().timeout(const Duration(seconds: 3));
  }
}

Widget materialTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(colorSchemeSeed: Colors.cyan),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.cyan,
      brightness: Brightness.dark,
    ),
    home: Scaffold(body: child),
  );
}

Widget adaptiveTestApp(Widget child) {
  return AdaptiveTheme(
    light: ThemeData(colorSchemeSeed: Colors.cyan),
    dark: ThemeData(colorSchemeSeed: Colors.cyan, brightness: Brightness.dark),
    initial: AdaptiveThemeMode.light,
    builder: (theme, darkTheme) {
      return MaterialApp(theme: theme, darkTheme: darkTheme, home: child);
    },
  );
}

Directory testDocumentsDirectory() {
  _documentsDirectory ??= Directory.systemTemp.createTempSync(
    'equran_documents_test_',
  );
  return _documentsDirectory!;
}

void _mockPathProvider() {
  const MethodChannel channel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        final String path = testDocumentsDirectory().path;
        return switch (methodCall.method) {
          'getApplicationDocumentsDirectory' => path,
          'getApplicationSupportDirectory' => path,
          'getTemporaryDirectory' => path,
          _ => path,
        };
      });
}
