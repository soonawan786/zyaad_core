import 'dart:math' as math;

/// How much the magnetometer can be trusted right now.
enum HeadingQuality {
  /// The field strength is in the normal range for the earth's surface.
  good,

  /// The field is distorted (a magnet, a car dashboard, a phone case, a metal
  /// table). The reading is still usable but the user should recalibrate.
  calibrate,

  /// No usable reading at all.
  unusable,
}

/// A compass reading.
class HeadingReading {
  const HeadingReading({required this.degrees, required this.quality});

  /// 0..360, clockwise from magnetic north.
  final double degrees;

  final HeadingQuality quality;

  bool get needsCalibration => quality == HeadingQuality.calibrate;
}

/// Turns raw magnetometer and accelerometer samples into a compass heading.
///
/// We deliberately use `sensors_plus` and do the fusion here rather than depend on
/// a compass plugin:
///
///  * `sensors_plus` is the actively maintained community plugin (published
///    October 2026, `sdk >=3.3.0`, `flutter >=3.19.0`) and matches this app's
///    Flutter 3.44 / Dart 3.12 toolchain;
///  * the only mature "compass" plugin, `flutter_compass`, was last released in
///    November 2024 and still ships a legacy `buildscript { classpath
///    'com.android.tools.build:gradle:4.1.1' }` block with `compileSdkVersion 34`,
///    which is a build risk against the AGP 8.x these apps use;
///  * the fusion is a dozen lines of trigonometry, and doing it here makes it
///    unit-testable with synthetic sensor vectors instead of needing a phone in a
///    car park.
///
/// The trade-off, stated plainly: we do not get the OS-fused rotation-vector
/// heading, so we own the calibration warning — which is why [qualityForField]
/// exists.
class HeadingCalculator {
  const HeadingCalculator._();

  /// Below this the phone is probably not measuring the earth's field at all.
  static const double minFieldMicroTesla = 20;

  /// Above this something local is dominating: a magnet, a speaker, a metal
  /// dashboard. The earth's field is 25-65 uT almost everywhere.
  static const double maxFieldMicroTesla = 100;

  /// The magnetic field strength, in microteslas.
  static double fieldStrength({
    required double mx,
    required double my,
    required double mz,
  }) =>
      math.sqrt(mx * mx + my * my + mz * mz);

  /// The tilt-compensated heading, or null when the samples cannot produce one.
  ///
  /// How it works, in one paragraph: the accelerometer gives the "up" direction in
  /// device coordinates; the component of the magnetic field along "up" is removed,
  /// leaving the horizontal field, which points at magnetic north; the cross
  /// product of north and up is east; and the heading is the angle from north to
  /// the device's own top axis. No small-angle approximation is involved, so it is
  /// correct at any tilt as long as the device is not accelerating hard.
  static double? heading({
    required double ax,
    required double ay,
    required double az,
    required double mx,
    required double my,
    required double mz,
  }) {
    final upLength = math.sqrt(ax * ax + ay * ay + az * az);

    if (upLength == 0 || !upLength.isFinite) return null;

    final ux = ax / upLength;
    final uy = ay / upLength;
    final uz = az / upLength;

    // Remove the vertical component of the magnetic field.
    final alongUp = mx * ux + my * uy + mz * uz;
    final hx = mx - alongUp * ux;
    final hy = my - alongUp * uy;
    final hz = mz - alongUp * uz;

    final horizontalLength = math.sqrt(hx * hx + hy * hy + hz * hz);

    // The phone is pointing at the sky or at the floor, or the field is unusable.
    if (horizontalLength < 1e-6 || !horizontalLength.isFinite) return null;

    final nx = hx / horizontalLength;
    final ny = hy / horizontalLength;
    final nz = hz / horizontalLength;

    // east = north x up. Only its Y component is needed, because the device's top
    // axis is (0, 1, 0) in device coordinates, so dot(east, top) == eastY.
    //
    // (Taking eastX here — the obvious-looking mistake — makes a phone lying flat
    // and pointing north read 45 degrees. The attitude round-trip test in
    // test/heading_test.dart is what pins this down.)
    final eastAlongTop = nz * ux - nx * uz;
    final northAlongTop = ny;

    if (eastAlongTop.abs() < 1e-12 && northAlongTop.abs() < 1e-12) return null;

    final degrees = math.atan2(eastAlongTop, northAlongTop) * 180 / math.pi;
    final normalized = degrees % 360;

    return normalized < 0 ? normalized + 360 : normalized;
  }

  /// A full reading, including the calibration verdict.
  static HeadingReading? read({
    required double ax,
    required double ay,
    required double az,
    required double mx,
    required double my,
    required double mz,
  }) {
    final degrees = heading(ax: ax, ay: ay, az: az, mx: mx, my: my, mz: mz);

    if (degrees == null) return null;

    return HeadingReading(
      degrees: degrees,
      quality: qualityForField(fieldStrength(mx: mx, my: my, mz: mz)),
    );
  }

  /// Whether the field strength suggests the reading can be trusted.
  ///
  /// The app does not calibrate the magnetometer — the OS does. What we can detect
  /// is a field that is far too strong (a magnet nearby) or far too weak (no earth
  /// field at all), which is exactly when the arrow would point somewhere silly.
  static HeadingQuality qualityForField(double microTesla) {
    if (!microTesla.isFinite || microTesla < minFieldMicroTesla) {
      return HeadingQuality.unusable;
    }

    if (microTesla > maxFieldMicroTesla) return HeadingQuality.calibrate;

    return HeadingQuality.good;
  }

  /// A smoothing pass so the arrow does not jitter.
  ///
  /// It blends along the shortest angular path, so crossing north does not flip
  /// the needle the long way round.
  static double smooth({
    required double previous,
    required double next,
    double factor = 0.2,
  }) {
    final delta = ((next - previous + 540) % 360) - 180;
    final blended = previous + delta * factor.clamp(0.0, 1.0);
    final normalized = blended % 360;

    return normalized < 0 ? normalized + 360 : normalized;
  }
}

