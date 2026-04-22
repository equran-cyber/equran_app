import 'package:flutter/material.dart';

class AppSliderTheme {
  const AppSliderTheme._();

  static SliderThemeData standard(BuildContext context) {
    final SliderThemeData base = SliderTheme.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return base.copyWith(
      trackHeight: 8,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.14),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    );
  }
}
