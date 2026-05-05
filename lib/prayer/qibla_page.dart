import 'dart:async';
import 'dart:math' as math;

import 'package:equran/backend/settings_db.dart';
import 'package:equran/prayer/manual_prayer_location_page.dart';
import 'package:equran/prayer/prayer_location_service.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/prayer_settings_store.dart';
import 'package:equran/prayer/prayer_times_settings_page.dart';
import 'package:equran/prayer/qibla_service.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

enum _QiblaLocationSource { currentDevice, manual, savedPrayerLocation }

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  static const QiblaService _qiblaService = QiblaService();
  static const Duration _locationTimeout = Duration(seconds: 15);
  static const Duration _hapticCooldown = Duration(seconds: 4);

  final PrayerSettingsStore _store = PrayerSettingsStore();
  final PrayerLocationService _locationService = const PrayerLocationService();

  StreamSubscription<CompassEvent>? _compassSubscription;
  PrayerLocation? _currentLocation;
  _QiblaLocationSource? _locationSource;
  double? _heading;
  String? _locationMessage;
  String? _compassMessage;
  bool _isLocating = true;
  bool _wasFacingQibla = false;
  DateTime? _lastHapticAt;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _startCompass();
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qibla Direction')),
      body: ValueListenableBuilder(
        valueListenable: SettingsDB().listener,
        builder: (BuildContext context, Object? value, Widget? child) {
          final PrayerLocation? savedLocation = _store.getLocation();
          final PrayerLocation? location = _currentLocation;
          if (location == null) {
            return _QiblaEmptyState(
              isLocating: _isLocating,
              message: _locationMessage,
              savedLocation: savedLocation,
              onUseCurrentLocation: _loadCurrentLocation,
              onChooseManualLocation: _chooseManualLocation,
              onUseSavedLocation: savedLocation == null
                  ? null
                  : () => _useSavedLocation(savedLocation),
            );
          }

          final double? bearing = _qiblaService.calculateBearing(location);
          if (bearing == null) {
            return _InvalidLocationState(
              location: location,
              onUpdateLocation: () => _openSettings(context),
            );
          }

          return _QiblaContent(
            bearing: bearing,
            heading: _heading,
            location: location,
            locationSource: _sourceLabel(_locationSource),
            statusMessage: _heading == null
                ? _compassMessage ??
                      'Compass unavailable. Rotate your device manually using the bearing.'
                : null,
            onUseCurrentLocation: _loadCurrentLocation,
            onChooseManualLocation: _chooseManualLocation,
            onUseSavedLocation: savedLocation == null
                ? null
                : () => _useSavedLocation(savedLocation),
          );
        },
      ),
    );
  }

  Future<void> _loadCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isLocating = true;
      _locationMessage = null;
    });
    try {
      final PrayerLocationResult result = await _locationService
          .currentDeviceLocation()
          .timeout(_locationTimeout);
      if (!mounted) return;
      final PrayerLocation? location = result.location;
      setState(() {
        _isLocating = false;
        if (location == null) {
          _locationMessage =
              result.message ??
              'Current location is unavailable. Enter coordinates manually or use your saved prayer location.';
        } else {
          _currentLocation = location;
          _locationSource = _QiblaLocationSource.currentDevice;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _locationMessage =
            'Current location timed out. Enter coordinates manually or use your saved prayer location.';
      });
    }
  }

  Future<void> _chooseManualLocation() async {
    final PrayerLocation? location = await Navigator.of(context).push(
      MaterialPageRoute<PrayerLocation>(
        builder: (BuildContext context) => ManualPrayerLocationPage(
          initialLocation: _currentLocation ?? _store.getLocation(),
        ),
      ),
    );
    if (location == null || !mounted) return;
    setState(() {
      _currentLocation = location;
      _locationSource = _QiblaLocationSource.manual;
      _locationMessage = null;
    });
  }

  void _useSavedLocation(PrayerLocation savedLocation) {
    setState(() {
      _currentLocation = savedLocation;
      _locationSource = _QiblaLocationSource.savedPrayerLocation;
      _locationMessage = null;
    });
  }

  void _startCompass() {
    try {
      final Stream<CompassEvent>? stream = FlutterCompass.events;
      if (stream == null) {
        _compassMessage =
            'Compass unavailable. Rotate your device manually using the bearing.';
        return;
      }
      _compassSubscription = stream.listen(
        (CompassEvent event) {
          final double? heading = _usableHeading(event.heading);
          if (!mounted) return;
          setState(() {
            _heading = heading;
            _compassMessage = heading == null
                ? 'Compass unavailable. Rotate your device manually using the bearing.'
                : null;
          });
          _handleQiblaHaptic(heading);
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _heading = null;
            _compassMessage =
                'Compass unavailable. Rotate your device manually using the bearing.';
          });
        },
      );
    } on MissingPluginException {
      _compassMessage =
          'Compass unavailable. Rotate your device manually using the bearing.';
    } catch (_) {
      _compassMessage =
          'Compass unavailable. Rotate your device manually using the bearing.';
    }
  }

  void _handleQiblaHaptic(double? heading) {
    final PrayerLocation? location = _currentLocation;
    if (heading == null || location == null) {
      _wasFacingQibla = false;
      return;
    }
    final double? bearing = _qiblaService.calculateBearing(location);
    if (bearing == null) return;
    final double relative = _qiblaService.relativeDirection(
      qiblaBearing: bearing,
      heading: heading,
    );
    final bool isFacing = relative.abs() <= 5;
    final DateTime now = DateTime.now();
    final bool cooledDown =
        _lastHapticAt == null || now.difference(_lastHapticAt!) >= _hapticCooldown;
    if (isFacing && !_wasFacingQibla && cooledDown) {
      _lastHapticAt = now;
      HapticFeedback.lightImpact().ignore();
    }
    _wasFacingQibla = isFacing;
  }

  static double? _usableHeading(double? heading) {
    if (heading == null || !heading.isFinite) return null;
    return _qiblaService.normalizeDegrees(heading);
  }

  static void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const PrayerTimesSettingsPage(),
      ),
    );
  }

  String _sourceLabel(_QiblaLocationSource? source) {
    return switch (source) {
      _QiblaLocationSource.currentDevice => 'Current device location',
      _QiblaLocationSource.manual => 'Manual coordinates',
      _QiblaLocationSource.savedPrayerLocation => 'Saved prayer location',
      null => 'Location',
    };
  }
}

class _QiblaContent extends StatelessWidget {
  const _QiblaContent({
    required this.bearing,
    required this.heading,
    required this.location,
    required this.locationSource,
    required this.onUseCurrentLocation,
    required this.onChooseManualLocation,
    this.statusMessage,
    this.onUseSavedLocation,
  });

  final double bearing;
  final double? heading;
  final PrayerLocation location;
  final String locationSource;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onChooseManualLocation;
  final VoidCallback? onUseSavedLocation;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final double? relative = heading == null
        ? null
        : _QiblaPageState._qiblaService.relativeDirection(
            qiblaBearing: bearing,
            heading: heading!,
          );
    final String guidance = relative == null
        ? 'Point your device using the bearing'
        : _QiblaPageState._qiblaService.guidanceForRelativeDirection(relative);
    final MediaQueryData media = MediaQuery.of(context);
    final double contentWidth = math.min(media.size.width - 28, 760);
    final double heightBudget =
        media.size.height - media.padding.vertical - kToolbarHeight - 292;
    final double compassSize = math
        .min(contentWidth - 48, math.max(180, heightBudget))
        .clamp(180, 390)
        .toDouble();

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
                  locationSource: locationSource,
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
                          size: compassSize,
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
                  locationSource: locationSource,
                  heading: heading,
                  onUseCurrentLocation: onUseCurrentLocation,
                  onChooseManualLocation: onChooseManualLocation,
                  onUseSavedLocation: onUseSavedLocation,
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
    required this.locationSource,
    required this.guidance,
  });

  final double bearing;
  final PrayerLocation location;
  final String locationSource;
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
                        locationSource,
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
    required this.size,
  });

  final double bearing;
  final double? heading;
  final double? relative;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double arrowDegrees = relative ?? bearing;
    return SizedBox.square(
      dimension: size,
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
    required this.locationSource,
    required this.heading,
    required this.onUseCurrentLocation,
    required this.onChooseManualLocation,
    this.onUseSavedLocation,
  });

  final PrayerLocation location;
  final String locationSource;
  final double? heading;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onChooseManualLocation;
  final VoidCallback? onUseSavedLocation;

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
              locationSource,
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
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: onUseCurrentLocation,
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Use current'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onChooseManualLocation,
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: const Text('Manual'),
                  ),
                  if (onUseSavedLocation != null)
                    TextButton.icon(
                      onPressed: onUseSavedLocation,
                      icon: const Icon(Icons.bookmark_outline_rounded),
                      label: const Text('Saved prayer location'),
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

class _QiblaEmptyState extends StatelessWidget {
  const _QiblaEmptyState({
    required this.isLocating,
    required this.onUseCurrentLocation,
    required this.onChooseManualLocation,
    this.message,
    this.savedLocation,
    this.onUseSavedLocation,
  });

  final bool isLocating;
  final String? message;
  final PrayerLocation? savedLocation;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onChooseManualLocation;
  final VoidCallback? onUseSavedLocation;

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
                      isLocating ? 'Finding your location' : 'Choose a location for Qibla',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message ??
                          'Qibla prefers your current device location, because direction depends on where you physically are.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: isLocating ? null : onUseCurrentLocation,
                          icon: isLocating
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded),
                          label: Text(
                            isLocating ? 'Finding location' : 'Use current location',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: onChooseManualLocation,
                          icon: const Icon(Icons.edit_location_alt_outlined),
                          label: const Text('Enter coordinates'),
                        ),
                        if (savedLocation != null && onUseSavedLocation != null)
                          TextButton.icon(
                            onPressed: onUseSavedLocation,
                            icon: const Icon(Icons.bookmark_outline_rounded),
                            label: const Text('Use saved prayer location'),
                          ),
                      ],
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
