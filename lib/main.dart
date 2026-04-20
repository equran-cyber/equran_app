import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:equran/home/library.dart' show HomePage;
import 'package:equran/utils/app_theme.dart';
import 'package:equran/utils/responsive_nav.dart';
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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final AdaptiveThemeMode? savedThemeMode = _getSavedThemeMode();
    final MaterialColor seedColor = _getPrimaryColor();

    return AdaptiveTheme(
      light: AppTheme.buildLightTheme(seedColor),
      dark: AppTheme.buildDarkTheme(seedColor),
      initial: savedThemeMode ?? AdaptiveThemeMode.dark,
      overrideMode: savedThemeMode,
      builder: (theme, darkTheme) => MaterialApp(
        scrollBehavior: ScrollConfiguration.of(
          context,
        ).copyWith(scrollbars: false),
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        builder: (context, child) {
          final MediaQueryData mediaQuery = MediaQuery.of(context);
          final double tabletTextScale = ResponsiveNav.appTextScale(context);
          final double effectiveTextScale =
              mediaQuery.textScaler.scale(1.0) * tabletTextScale;
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(effectiveTextScale),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const HomePage(),
      ),
    );
  }

  static MaterialColor _getPrimaryColor() {
    final colorIndex = SettingsDB().get("color");
    return colorIndex != null ? Colors.primaries[colorIndex] : Colors.cyan;
  }

  static AdaptiveThemeMode? _getSavedThemeMode() {
    final themeMode = SettingsDB().get("themeMode");
    return switch (themeMode) {
      "light" => AdaptiveThemeMode.light,
      "dark" => AdaptiveThemeMode.dark,
      "auto" => AdaptiveThemeMode.system,
      _ => null,
    };
  }
}
