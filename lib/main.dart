import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:equran/home/library.dart' show HomePage;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:io' show Platform;

import 'backend/library.dart'
    show
        BookmarkDB,
        FavouritesDB,
        ReadingEntryAdapter,
        SettingsDB,
        SurahAdapter,
        SurahDB;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.app.equran.audio',
      androidNotificationChannelName: 'Quran Audio Playback',
      androidNotificationOngoing: true,
    );
  }

  // ----- HIVE -----
  // Use an app-specific subdirectory to avoid desktop lock collisions in shared paths.
  await Hive.initFlutter('equran');

  Hive.registerAdapter(SurahAdapter());
  Hive.registerAdapter(ReadingEntryAdapter());

  // Hive.deleteBoxFromDisk("bookmarks");

  await BookmarkDB().initBox();
  await SettingsDB().initBox();
  await SurahDB().initBox();
  await FavouritesDB().initBox();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static MaterialColor mySeed = _getPrimaryColor();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
        light: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: mySeed, brightness: Brightness.light)),
        dark: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: mySeed, brightness: Brightness.dark)),
        initial: AdaptiveThemeMode.system,
        builder: (theme, darkTheme) => MaterialApp(
              scrollBehavior:
                  ScrollConfiguration.of(context).copyWith(scrollbars: false),
              debugShowCheckedModeBanner: false,
              theme: theme,
              darkTheme: darkTheme,
              home: const HomePage(),
            ));
  }

  static MaterialColor _getPrimaryColor() {
    final colorIndex = SettingsDB().get("color");
    return colorIndex != null ? Colors.primaries[colorIndex] : Colors.cyan;
  }
}
