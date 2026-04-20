import 'package:flutter/material.dart';

class ResponsiveNav {
  const ResponsiveNav._();

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= 600;
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

  static double appTextScale(BuildContext context) {
    return isTablet(context) ? 1.08 : 1.0;
  }

  static TextStyle? drawerLabelStyle(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return isTablet(context) ? theme.textTheme.titleMedium : null;
  }

  static ButtonStyle iconButtonStyle(BuildContext context) {
    final double size = isTablet(context) ? 52 : 48;
    return IconButton.styleFrom(
      minimumSize: Size.square(size),
      fixedSize: Size.square(size),
    );
  }
}
