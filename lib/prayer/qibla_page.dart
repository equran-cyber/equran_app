import 'dart:math' as math;

import 'package:equran/backend/settings_db.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_settings_store.dart';
import 'package:equran/prayer/prayer_times_settings_page.dart';
import 'package:equran/prayer/qibla_service.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

class QiblaPage extends StatelessWidget {
  const QiblaPage({super.key});

  static const QiblaService _qiblaService = QiblaService();

  @override
  Widget build(BuildContext context) {
    final PrayerSettingsStore store = PrayerSettingsStore();
    return Scaffold(
      appBar: AppBar(title: const Text('Qibla Direction')),
      body: ValueListenableBuilder(
        valueListenable: SettingsDB().listener,
        builder: (BuildContext context, Object? value, Widget? child) {
          final PrayerLocation? location = store.getLocation();
          if (location == null) {
            return _QiblaEmptyState(onChooseLocation: () => _openSettings(context));
          }

          final double? bearing = _qiblaService.calculateBearing(location);
          if (bearing == null) {
            return _InvalidLocationState(
              location: location,
              onUpdateLocation: () => _openSettings(context),
            );
          }

          final Stream<CompassEvent>? compassStream = FlutterCompass.events;
          return StreamBuilder<CompassEvent>(
            stream: compassStream,
            builder: (BuildContext context, AsyncSnapshot<CompassEvent> snapshot) {
              final double? heading = _usableHeading(snapshot.data?.heading);
              final String? statusMessage = _compassStatus(snapshot, heading);
              return _QiblaContent(
                bearing: bearing,
                heading: heading,
                location: location,
                statusMessage: statusMessage,
                onUpdateLocation: () => _openSettings(context),
              );
            },
          );
        },
      ),
    );
  }

  static double? _usableHeading(double? heading) {
    if (heading == null || !heading.isFinite) return null;
    return _qiblaService.normalizeDegrees(heading);
  }

  static String? _compassStatus(
    AsyncSnapshot<CompassEvent> snapshot,
    double? heading,
  ) {
    if (heading != null) return null;
    if (snapshot.hasError) {
      return 'Compass unavailable. Rotate your device manually using the bearing.';
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return 'Waiting for compass heading. Bearing is shown for manual use.';
    }
    return 'Compass unavailable. Rotate your device manually using the bearing.';
  }

  static void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const PrayerTimesSettingsPage(),
      ),
    );
  }
}

class _QiblaContent extends StatelessWidget {
  const _QiblaContent({
    required this.bearing,
    required this.heading,
    required this.location,
    required this.onUpdateLocation,
    this.statusMessage,
  });

  final double bearing;
  final double? heading;
  final PrayerLocation location;
  final VoidCallback onUpdateLocation;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final double? relative = heading == null
        ? null
        : QiblaPage._qiblaService.relativeDirection(
            qiblaBearing: bearing,
            heading: heading!,
          );
    final String guidance = relative == null
        ? 'Point your device using the bearing'
        : QiblaPage._qiblaService.guidanceForRelativeDirection(relative);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _QiblaSummaryCard(
                  bearing: bearing,
                  location: location,
                  guidance: guidance,
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                    child: Column(
                      children: <Widget>[
                        _QiblaCompass(
                          bearing: bearing,
                          heading: heading,
                          relative: relative,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          guidance,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (statusMessage != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            statusMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _QiblaInfoCard(
                  location: location,
                  heading: heading,
                  onUpdateLocation: onUpdateLocation,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QiblaSummaryCard extends StatelessWidget {
  const _QiblaSummaryCard({
    required this.bearing,
    required this.location,
    required this.guidance,
  });

  final double bearing;
  final PrayerLocation location;
  final String guidance;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.large),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              colors.primary.withAlpha(isLight ? 32 : 52),
              colors.surfaceContainerLow,
            ),
            colors.surfaceContainerLow,
          ],
        ),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Icon(
                    Icons.explore_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        location.displayLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Qibla bearing',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '${bearing.round()}° from north',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              guidance,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QiblaCompass extends StatelessWidget {
  const _QiblaCompass({
    required this.bearing,
    required this.heading,
    required this.relative,
  });

  final double bearing;
  final double? heading;
  final double? relative;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double arrowDegrees = relative ?? bearing;
    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            AnimatedRotation(
              turns: heading == null ? 0 : -heading! / 360,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: CustomPaint(
                painter: _CompassDialPainter(colors: colors),
                child: const SizedBox.expand(),
              ),
            ),
            AnimatedRotation(
              turns: arrowDegrees / 360,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: const _QiblaMarker(),
            ),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceContainerLow,
                border: Border.all(color: colors.outlineVariant),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    heading == null ? '${bearing.round()}°' : '${heading!.round()}°',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    heading == null ? 'Qibla' : 'Heading',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QiblaMarker extends StatelessWidget {
  const _QiblaMarker();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: const Offset(0, -10),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.navigation_rounded, color: colors.primary, size: 38),
            Container(
              width: 4,
              height: 88,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassDialPainter extends CustomPainter {
  const _CompassDialPainter({required this.colors});

  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) / 2;
    final Paint fill = Paint()..color = colors.surfaceContainer;
    final Paint ring = Paint()
      ..color = colors.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, radius - 4, fill);
    canvas.drawCircle(center, radius - 5, ring);
    canvas.drawCircle(center, radius * 0.36, ring);

    final Paint tickPaint = Paint()
      ..color = colors.onSurfaceVariant.withValues(alpha: 0.58)
      ..strokeCap = StrokeCap.round;
    for (int index = 0; index < 72; index++) {
      final bool major = index % 6 == 0;
      final double angle = (index * 5 - 90) * math.pi / 180;
      final double outer = radius - 18;
      final double inner = outer - (major ? 16 : 8);
      tickPaint.strokeWidth = major ? 2 : 1;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        tickPaint,
      );
    }

    _drawLabel(canvas, center, radius, 'N', -90, colors.primary);
    _drawLabel(canvas, center, radius, 'E', 0, colors.onSurfaceVariant);
    _drawLabel(canvas, center, radius, 'S', 90, colors.onSurfaceVariant);
    _drawLabel(canvas, center, radius, 'W', 180, colors.onSurfaceVariant);
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    double radius,
    String label,
    double degrees,
    Color color,
  ) {
    final double angle = degrees * math.pi / 180;
    final Offset position =
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 44);
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      position - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

class _QiblaInfoCard extends StatelessWidget {
  const _QiblaInfoCard({
    required this.location,
    required this.heading,
    required this.onUpdateLocation,
  });

  final PrayerLocation location;
  final double? heading;
  final VoidCallback onUpdateLocation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Selected location',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${location.latitude.toStringAsFixed(5)}, '
              '${location.longitude.toStringAsFixed(5)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              heading == null
                  ? 'Compass readings depend on device sensors. If unavailable, use the bearing from true north.'
                  : 'For best accuracy, keep the device flat and away from magnetic interference.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: onUpdateLocation,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Update location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QiblaEmptyState extends StatelessWidget {
  const _QiblaEmptyState({required this.onChooseLocation});

  final VoidCallback onChooseLocation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadii.large),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                      child: Icon(
                        Icons.explore_outlined,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Choose a location for Qibla',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Qibla direction is calculated locally from your saved prayer location.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onChooseLocation,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Choose location'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InvalidLocationState extends StatelessWidget {
  const _InvalidLocationState({
    required this.location,
    required this.onUpdateLocation,
  });

  final PrayerLocation location;
  final VoidCallback onUpdateLocation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadii.large),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.location_off_outlined, color: colors.error),
                  const SizedBox(height: 12),
                  Text(
                    'Location needs an update',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${location.displayLabel} has coordinates outside the supported latitude or longitude range.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onUpdateLocation,
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: const Text('Update location'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
