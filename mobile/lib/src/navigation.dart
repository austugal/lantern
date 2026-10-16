import 'dart:math';
import 'services.dart';

bool validFix(Fix fix) =>
    fix.latitude.isFinite &&
    fix.longitude.isFinite &&
    fix.accuracy.isFinite &&
    fix.latitude.abs() <= 90 &&
    fix.longitude.abs() <= 180 &&
    fix.accuracy >= 0 &&
    fix.accuracy <= 100000;

class NavigationVector {
  const NavigationVector(this.distanceMeters, this.bearingDegrees);
  final double distanceMeters, bearingDegrees;
}

/// Great-circle distance and initial true-north bearing, not a road route.
NavigationVector vectorBetween(Fix start, Fix end) {
  if (!validFix(start) || !validFix(end)) {
    throw ArgumentError('Invalid GPS fix');
  }
  const radians = pi / 180;
  final a = start.latitude * radians, b = end.latitude * radians;
  final delta = (end.longitude - start.longitude) * radians;
  final h = pow(sin((b - a) / 2), 2) + cos(a) * cos(b) * pow(sin(delta / 2), 2);
  final distance = 6371000 * 2 * asin(sqrt(h.clamp(0, 1)));
  final bearing =
      (atan2(
                sin(delta) * cos(b),
                cos(a) * sin(b) - sin(a) * cos(b) * cos(delta),
              ) /
              radians +
          360) %
      360;
  return NavigationVector(distance, bearing);
}
