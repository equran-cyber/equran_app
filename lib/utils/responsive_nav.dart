import 'package:flutter/material.dart';

class ResponsiveNav {
  const ResponsiveNav._();

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= 600;
  }

  static bool isLargeTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= 800;
  }

  static double toolbarHeight(BuildContext context) {
    return isTablet(context) ? 66 : kToolbarHeight;
  }

  static double iconSize(BuildContext context) {
    return isTablet(context) ? 30 : 24;
  }

  static double drawerTileHeight(BuildContext context) {
    return isTablet(context) ? 64 : 56;
  }

  static double drawerFooterTileHeight(BuildContext context) {
    return isTablet(context) ? 54 : 44;
  }

  static double appTextScale(BuildContext context) {
    return isLargeTablet(context) ? 1.08 : 1.0;
  }

  static double appChromeTextScale(BuildContext context) {
    final double shortestSide = MediaQuery.sizeOf(context).shortestSide;
    return shortestSide >= 390 && shortestSide < 600 ? 0.94 : 1.0;
  }

  static TextStyle? drawerLabelStyle(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return isTablet(context)
        ? theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)
        : null;
  }

  static ButtonStyle iconButtonStyle(BuildContext context) {
    final double size = isTablet(context) ? 52 : 48;
    return IconButton.styleFrom(
      minimumSize: Size.square(size),
      fixedSize: Size.square(size),
    );
  }
}
