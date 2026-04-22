import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData buildLightTheme(Color seedColor) {
    final ColorScheme baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final ColorScheme colorScheme = baseScheme.copyWith(
      surface: const Color(0xFFF4F1EE),
      surfaceContainerLowest: const Color(0xFFFFFBFA),
      surfaceContainerLow: const Color(0xFFFCF8F6),
      surfaceContainer: const Color(0xFFF7F2EF),
      surfaceContainerHigh: const Color(0xFFEEE7E2),
      surfaceContainerHighest: const Color(0xFFE6DDD8),
      primaryContainer: Color.alphaBlend(
        Colors.white.withAlpha((0.56 * 255).round()),
        baseScheme.primaryContainer,
      ),
      secondaryContainer: Color.alphaBlend(
        Colors.white.withAlpha((0.60 * 255).round()),
        baseScheme.secondaryContainer,
      ),
      tertiaryContainer: Color.alphaBlend(
        Colors.white.withAlpha((0.60 * 255).round()),
        baseScheme.tertiaryContainer,
      ),
    );

    final TextTheme textTheme = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFFF4F1EE),
      canvasColor: const Color(0xFFF4F1EE),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerLow,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }

  static ThemeData buildDarkTheme(Color seedColor) {
    final TextTheme textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
    );
  }
}
