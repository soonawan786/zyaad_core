import 'dart:math' as math;

/// The direction of the Kaaba from anywhere on earth.
///
/// Pure maths, no plugins, so the bearing can be asserted against published
/// values for known cities instead of being trusted because it "looks about
/// right" on one phone.
class Qibla {
  const Qibla._();

  /// The Kaaba.
  static const double kaabaLatitude = 21.4225;
  static const double kaabaLongitude = 39.8262;

  /// Mean earth radius, in kilometres.
  static const double earthRadiusKm = 6371.0088;

  /// The great-circle initial bearing to the Kaaba, in degrees clockwise from
  /// true north (0..360).
  ///
  /// This is the *initial* bearing — the direction to start walking — which is the
  /// correct answer for a compass: the bearing changes along a great circle, so a
  /// final bearing would point the user a degree or two off.
  static double bearingToKaaba(double latitude, double longitude) {
    final lat1 = _rad(latitude);
    final lat2 = _rad(kaabaLatitude);
    final deltaLng = _rad(kaabaLongitude - longitude);

    final y = math.sin(deltaLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);

    return normalize(_deg(math.atan2(y, x)));
  }

  /// Great-circle distance to the Kaaba, in kilometres.
  static double distanceToKaaba(double latitude, double longitude) {
    final lat1 = _rad(latitude);
    final lat2 = _rad(kaabaLatitude);
    final deltaLat = lat2 - lat1;
    final deltaLng = _rad(kaabaLongitude - longitude);

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(deltaLng / 2) * math.sin(deltaLng / 2);

    return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
  }

  /// Where the Kaaba is relative to where the phone is pointing.
  ///
  /// Positive means "turn clockwise by this much", which is what an arrow drawn on
  /// a compass dial needs.
  static double relativeBearing({
    required double deviceHeading,
    required double qiblaBearing,
  }) =>
      shortestRotation(from: deviceHeading, to: qiblaBearing);

  /// The shortest signed rotation from [from] to [to], in (-180, 180].
  static double shortestRotation({required double from, required double to}) {
    final delta = normalize(to) - normalize(from);

    return ((delta + 540) % 360) - 180;
  }

  /// Normalises any angle into 0..360.
  static double normalize(double degrees) {
    final value = degrees % 360;

    return value < 0 ? value + 360 : value;
  }

  /// The plain-text fallback shown when there is no usable compass:
  /// "Qibla is 260 degrees from North".
  static String describe(double bearing) =>
      '${normalize(bearing).round() % 360}';

  static double _rad(double degrees) => degrees * math.pi / 180;

  static double _deg(double radians) => radians * 180 / math.pi;
}
