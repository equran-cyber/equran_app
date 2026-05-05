import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:equran/prayer/prayer_models.dart';

class QiblaService {
  const QiblaService();

  double? calculateBearing(PrayerLocation location) {
    if (!_hasValidCoordinates(location)) return null;
    final double bearing = adhan.Qibla.qibla(
      adhan.Coordinates(location.latitude, location.longitude),
    );
    if (!bearing.isFinite) return null;
    return normalizeDegrees(bearing);
  }

  double relativeDirection({
    required double qiblaBearing,
    required double heading,
  }) {
    final double relative = normalizeDegrees(qiblaBearing - heading);
    return relative > 180 ? relative - 360 : relative;
  }

  String guidanceForRelativeDirection(double relativeDirection) {
    final int degrees = relativeDirection.abs().round();
    if (degrees <= 5) return 'Facing Qibla';
    if (relativeDirection > 0) return 'Turn right $degrees°';
    return 'Turn left $degrees°';
  }

  double normalizeDegrees(double degrees) {
    final double normalized = degrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  bool _hasValidCoordinates(PrayerLocation location) {
    return location.latitude.isFinite &&
        location.longitude.isFinite &&
        location.latitude >= -90 &&
        location.latitude <= 90 &&
        location.longitude >= -180 &&
        location.longitude <= 180;
  }
}
