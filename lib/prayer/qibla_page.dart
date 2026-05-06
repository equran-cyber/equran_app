import 'dart:async';
import 'dart:math' as math;

import 'package:equran/prayer/prayer_location_service.dart';
import 'package:equran/prayer/prayer_models.dart';
import 'package:equran/prayer/qibla_service.dart';
import 'package:equran/utils/app_radii.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key, this.locationService});

  final PrayerLocationService? locationService;

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  static const QiblaService _qiblaService = QiblaService();
  static const Duration _locationTimeout = Duration(seconds: 15);
  static const Duration _hapticCooldown = Duration(seconds: 4);
  static const double _alignmentThresholdDegrees = 5;
  static const double _poorHeadingAccuracyDegrees = 25;

  late final PrayerLocationService _locationService;

  StreamSubscription<CompassEvent>? _compassSubscription;
  PrayerLocation? _currentLocation;
  double? _heading;
  double? _headingAccuracy;
  bool _headingIsReliable = false;
  String? _locationMessage;
  String? _compassMessage;
  bool _isLocating = true;
  bool _wasFacingQibla = false;
  DateTime? _lastHapticAt;

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? const PrayerLocationService();
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
      appBar: AppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final PrayerLocation? location = _currentLocation;
    if (location == null) {
      if (!_isLocating && _locationMessage != null) {
        return _QiblaErrorState(
          message: _locationMessage!,
          onRetry: _loadCurrentLocation,
        );
      }
      return _QiblaEmptyState(
        isLocating: _isLocating,
        message: _locationMessage,
        onRetry: _loadCurrentLocation,
      );
    }

    final double? bearing = _qiblaService.calculateBearing(location);
    if (bearing == null) {
      return _QiblaErrorState(
        message: 'Current location coordinates are unavailable.',
        onRetry: _loadCurrentLocation,
      );
    }

    final double? reliableHeading = _headingIsReliable ? _heading : null;
    final double? relative = reliableHeading == null
        ? null
        : _qiblaService.relativeDirection(
            qiblaBearing: bearing,
            heading: reliableHeading,
          );
    return _QiblaContent(
      bearing: bearing,
      heading: reliableHeading,
      relative: relative,
      location: location,
      statusMessage: _compassStatusMessage,
      onRefreshLocation: _loadCurrentLocation,
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
          _currentLocation = null;
          _locationMessage = _messageForLocationResult(result);
        } else {
          _currentLocation = location;
          _locationMessage = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _currentLocation = null;
        _locationMessage =
            'Current location timed out. Check location services and try again.';
      });
    }
  }

  void _startCompass() {
    if (!_isCompassPlatformSupported) {
      _compassMessage = 'Compass unavailable. Use the bearing shown.';
      return;
    }
    try {
      final Stream<CompassEvent>? stream = FlutterCompass.events;
      if (stream == null) {
        _compassMessage = 'Compass unavailable. Use the bearing shown.';
        return;
      }
      _compassSubscription = stream.listen(
        (CompassEvent event) {
          final _CompassReading reading = _usableCompassReading(event);
          if (!mounted) return;
          setState(() {
            _heading = reading.heading;
            _headingAccuracy = reading.accuracy;
            _headingIsReliable = reading.isReliable;
            _compassMessage = reading.heading == null
                ? 'Compass unavailable. Use the bearing shown.'
                : null;
          });
          _handleQiblaHaptic(reading.heading, isReliable: reading.isReliable);
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _heading = null;
            _headingAccuracy = null;
            _headingIsReliable = false;
            _compassMessage = 'Compass unavailable. Use the bearing shown.';
          });
        },
      );
    } on MissingPluginException {
      _compassMessage = 'Compass unavailable. Use the bearing shown.';
    } catch (_) {
      _compassMessage = 'Compass unavailable. Use the bearing shown.';
    }
  }

  void _handleQiblaHaptic(double? heading, {required bool isReliable}) {
    final PrayerLocation? location = _currentLocation;
    if (!isReliable || heading == null || location == null) {
      _wasFacingQibla = false;
      return;
    }
    final double? bearing = _qiblaService.calculateBearing(location);
    if (bearing == null) return;
    final double relative = _qiblaService.relativeDirection(
      qiblaBearing: bearing,
      heading: heading,
    );
    final bool isFacing = relative.abs() <= _alignmentThresholdDegrees;
    final DateTime now = DateTime.now();
    final bool cooledDown =
        _lastHapticAt == null ||
        now.difference(_lastHapticAt!) >= _hapticCooldown;
    if (isFacing && !_wasFacingQibla && cooledDown) {
      _lastHapticAt = now;
      HapticFeedback.lightImpact().ignore();
    }
    _wasFacingQibla = isFacing;
  }

  static _CompassReading _usableCompassReading(CompassEvent event) {
    final double? heading = _normalizedHeading(event.heading);
    final double? accuracy = _usableAccuracy(event.accuracy);
    return _CompassReading(
      heading: heading,
      accuracy: accuracy,
      isReliable: heading != null && _isReasonableAccuracy(accuracy),
    );
  }

  static double? _normalizedHeading(double? heading) {
    if (heading == null || !heading.isFinite) return null;
    return _qiblaService.normalizeDegrees(heading);
  }

  static double? _usableAccuracy(double? accuracy) {
    if (accuracy == null || !accuracy.isFinite || accuracy < 0) return null;
    return accuracy;
  }

  static bool _isReasonableAccuracy(double? accuracy) {
    if (accuracy == null) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return accuracy >= 2;
    }
    return accuracy <= _poorHeadingAccuracyDegrees;
  }

  String get _compassStatusMessage {
    final String hint =
        'For best accuracy, hold your phone flat and move it in a figure-8 to calibrate.';
    final String? message = _compassMessage;
    if (message != null) return '$message $hint';
    if (_heading == null || !_headingIsReliable) {
      final double? accuracy = _headingAccuracy;
      final String accuracyText =
          accuracy == null || defaultTargetPlatform == TargetPlatform.android
          ? 'Compass accuracy may be low.'
          : 'Compass accuracy may be low (${accuracy.round()}°).';
      return '$accuracyText $hint';
    }
    return hint;
  }

  bool get _isCompassPlatformSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  String _messageForLocationResult(PrayerLocationResult result) {
    return switch (result.failureReason) {
      PrayerLocationFailureReason.servicesDisabled =>
        'Turn on location services to use Qibla.',
      PrayerLocationFailureReason.permissionDenied =>
        'Location permission is needed to calculate Qibla from your current device location.',
      PrayerLocationFailureReason.permissionDeniedForever =>
        'Location permission is blocked. Enable it from app settings to use Qibla.',
      PrayerLocationFailureReason.unavailable || null =>
        'We could not read your current location. Check location services and try again.',
    };
  }
}

class _CompassReading {
  const _CompassReading({
    required this.heading,
    required this.accuracy,
    required this.isReliable,
  });

  final double? heading;
  final double? accuracy;
  final bool isReliable;
}

class _QiblaContent extends StatelessWidget {
  const _QiblaContent({
    required this.bearing,
    required this.heading,
    required this.relative,
    required this.location,
    required this.onRefreshLocation,
    this.statusMessage,
  });

  final double bearing;
  final double? heading;
  final double? relative;
  final PrayerLocation location;
  final VoidCallback onRefreshLocation;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isAligned = relative != null && relative!.abs() <= 5;
    final String guidance = relative == null
        ? 'Bearing ${bearing.round()}°'
        : _QiblaPageState._qiblaService.guidanceForRelativeDirection(relative!);
    final MediaQueryData media = MediaQuery.of(context);
    final double contentWidth = math.min(media.size.width - 24, 760);
    final bool compactHeight = media.size.height < 640;
    final double minimumCompassSize = compactHeight ? 168 : 198;
    final double maximumCompassSize = compactHeight ? 350 : 410;
    final double widthBudget = contentWidth - 24;
    final double heightBudget =
        media.size.height -
        media.padding.vertical -
        kToolbarHeight -
        (compactHeight ? 206 : 232);
    final double compassLowerBound = math.min(
      minimumCompassSize,
      math.min(widthBudget, heightBudget),
    );
    final double compassSize = math
        .min(widthBudget, heightBudget)
        .clamp(compassLowerBound, maximumCompassSize)
        .toDouble();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Column(
                      children: <Widget>[
                        _QiblaCompass(
                          bearing: bearing,
                          heading: heading,
                          relative: relative,
                          size: compassSize,
                          isAligned: isAligned,
                        ),
                        const SizedBox(height: 10),
                        _AlignmentIndicator(
                          guidance: guidance,
                          isAligned: isAligned,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _QiblaDetailsCard(
                  bearing: bearing,
                  heading: heading,
                  location: location,
                  compassStatus: statusMessage,
                  onRefreshLocation: onRefreshLocation,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QiblaCompass extends StatelessWidget {
  const _QiblaCompass({
    required this.bearing,
    required this.heading,
    required this.relative,
    required this.size,
    required this.isAligned,
  });

  final double bearing;
  final double? heading;
  final double? relative;
  final double size;
  final bool isAligned;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double arrowDegrees = relative ?? bearing;
    final double centerSize = (size * 0.32).clamp(78, 112).toDouble();
    final Color ringColor = isAligned ? Colors.green : colors.outlineVariant;
    return SizedBox.square(
      dimension: size,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // The dial is rotated by the device heading, while the Qibla marker
            // is independently rotated by qiblaBearing - heading. Keeping those
            // rotations separate avoids applying the heading twice.
            AnimatedRotation(
              turns: heading == null ? 0 : -heading! / 360,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: CustomPaint(
                painter: _CompassDialPainter(colors: colors),
                child: const SizedBox.expand(),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ringColor.withValues(alpha: isAligned ? 0.9 : 0.38),
                  width: isAligned ? 5 : 1.4,
                ),
                boxShadow: isAligned
                    ? <BoxShadow>[
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.22),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
            ),
            AnimatedRotation(
              turns: arrowDegrees / 360,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _QiblaMarker(size: size),
            ),
            Container(
              width: centerSize,
              height: centerSize,
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
                    heading == null
                        ? '${bearing.round()}°'
                        : '${heading!.round()}°',
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
  const _QiblaMarker({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double markerHeight = (size * 0.24).clamp(46, 88).toDouble();
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
              height: markerHeight,
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

class _AlignmentIndicator extends StatelessWidget {
  const _AlignmentIndicator({required this.guidance, required this.isAligned});

  final String guidance;
  final bool isAligned;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color foreground = isAligned
        ? Colors.green.shade700
        : colors.onSecondaryContainer;
    final IconData icon = isAligned
        ? Icons.check_circle_rounded
        : guidance.startsWith('Turn left')
        ? Icons.turn_left_rounded
        : guidance.startsWith('Turn right')
        ? Icons.turn_right_rounded
        : Icons.explore_outlined;
    return Align(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isAligned
              ? Colors.green.withValues(alpha: 0.14)
              : colors.secondaryContainer.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(AppRadii.small),
          border: Border.all(
            color: isAligned
                ? Colors.green.withValues(alpha: 0.45)
                : colors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                isAligned ? 'Facing Qibla' : guidance,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QiblaDetailsCard extends StatelessWidget {
  const _QiblaDetailsCard({
    required this.bearing,
    required this.heading,
    required this.location,
    required this.onRefreshLocation,
    this.compassStatus,
  });

  final double bearing;
  final double? heading;
  final PrayerLocation location;
  final VoidCallback onRefreshLocation;
  final String? compassStatus;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.location_on_outlined,
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentLocationLabel(location),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh current location',
                  onPressed: onRefreshLocation,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _DetailPill(text: 'Lat ${location.latitude.toStringAsFixed(4)}'),
                _DetailPill(
                  text: 'Lng ${location.longitude.toStringAsFixed(4)}',
                ),
                _DetailPill(text: 'Qibla ${bearing.round()}°'),
                if (heading != null)
                  _DetailPill(text: 'Heading ${heading!.round()}°'),
              ],
            ),
            if (compassStatus != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                compassStatus!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _QiblaEmptyState extends StatelessWidget {
  const _QiblaEmptyState({
    required this.isLocating,
    required this.onRetry,
    this.message,
  });

  final bool isLocating;
  final String? message;
  final VoidCallback onRetry;

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
                      isLocating
                          ? 'Finding your location'
                          : 'Current location required',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message ??
                          'Qibla requires live current location from this device. Enable location services and permission to continue.',
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
                          onPressed: isLocating ? null : onRetry,
                          icon: isLocating
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded),
                          label: Text(
                            isLocating
                                ? 'Finding location'
                                : 'Try again',
                          ),
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

class _QiblaErrorState extends StatelessWidget {
  const _QiblaErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
                    'Current location unavailable',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Retry'),
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

String _currentLocationLabel(PrayerLocation location) {
  final String label = location.label.trim();
  if (label.isEmpty ||
      label == location.coordinateLabel ||
      _isGenericLocationLabel(label)) {
    return 'Current location';
  }
  return label;
}

bool _isGenericLocationLabel(String label) {
  final List<String> parts = label.toLowerCase().split(RegExp(r'\s+'));
  return parts.isNotEmpty && parts.last == 'location' && parts.length <= 3;
}
