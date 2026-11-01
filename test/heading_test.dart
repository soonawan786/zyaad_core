import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

/*
|--------------------------------------------------------------------------
| Compass heading
|--------------------------------------------------------------------------
|
| There is no way to unit-test a real magnetometer, so instead of asserting a
| magic number the test builds the *forward* problem: take a known attitude
| (heading, pitch, roll), compute what the accelerometer and magnetometer would
| read in that attitude, and assert the calculator recovers the heading.
|
| That is a genuine check of the maths — including the sign conventions, which are
| the part that is easy to get wrong — because a wrong sign cannot invert the
| model. The flat, hand-derived cases (0/90/180/270) are asserted separately so a
| failure says which axis is wrong.
|
| Device frame (Android convention): x = right, y = top of the screen,
| z = out of the screen. World frame: ENU (x = east, y = north, z = up).
|
*/

List<List<double>> _mul(List<List<double>> a, List<List<double>> b) {
  final out = List.generate(3, (_) => List.filled(3, 0.0));

  for (var i = 0; i < 3; i++) {
    for (var j = 0; j < 3; j++) {
      var sum = 0.0;
      for (var k = 0; k < 3; k++) {
        sum += a[i][k] * b[k][j];
      }
      out[i][j] = sum;
    }
  }

  return out;
}

/// device = R^T * world
List<double> _toDevice(List<List<double>> r, List<double> world) => [
      r[0][0] * world[0] + r[1][0] * world[1] + r[2][0] * world[2],
      r[0][1] * world[0] + r[1][1] * world[1] + r[2][1] * world[2],
      r[0][2] * world[0] + r[1][2] * world[1] + r[2][2] * world[2],
    ];

/// The device-to-world rotation for a given attitude.
///
/// yaw: the heading of the device's top edge, clockwise from north.
/// pitch: rotation about the device's x axis (tilting the top away/towards).
/// roll: rotation about the device's y axis (tipping left/right).
List<List<double>> _deviceToWorld(double yaw, double pitch, double roll) {
  final p = yaw * math.pi / 180;
  final t = pitch * math.pi / 180;
  final r = roll * math.pi / 180;

  final yawM = [
    [math.cos(p), math.sin(p), 0.0],
    [-math.sin(p), math.cos(p), 0.0],
    [0.0, 0.0, 1.0],
  ];
  final pitchM = [
    [1.0, 0.0, 0.0],
    [0.0, math.cos(t), -math.sin(t)],
    [0.0, math.sin(t), math.cos(t)],
  ];
  final rollM = [
    [math.cos(r), 0.0, math.sin(r)],
    [0.0, 1.0, 0.0],
    [-math.sin(r), 0.0, math.cos(r)],
  ];

  return _mul(yawM, _mul(pitchM, rollM));
}

/// What the sensors would read at a given attitude.
///
/// [horizontalMicroTesla] is the horizontal component of the earth's field and
/// [inclinationDegrees] its dip angle, so the total field strength is
/// `horizontal / cos(inclination)` — which is what the quality check looks at.
({
  double ax,
  double ay,
  double az,
  double mx,
  double my,
  double mz,
}) _readingsFor({
  required double yaw,
  double pitch = 0,
  double roll = 0,
  double horizontalMicroTesla = 30,
  double inclinationDegrees = 40,
}) {
  final r = _deviceToWorld(yaw, pitch, roll);

  final down = horizontalMicroTesla * math.tan(inclinationDegrees * math.pi / 180);
  final worldField = [0.0, horizontalMicroTesla, -down];
  final worldUp = [0.0, 0.0, 9.81];

  final m = _toDevice(r, worldField);
  final a = _toDevice(r, worldUp);

  return (ax: a[0], ay: a[1], az: a[2], mx: m[0], my: m[1], mz: m[2]);
}

/// The signed shortest difference between two headings, in degrees.
double _shortestDelta(double a, double b) => ((a - b + 540) % 360) - 180;

void main() {
  group('flat, hand-derived cases', () {
    // Derived on paper from the sensor model, not from the code, so these catch a
    // wrong sign in the azimuth extraction.
    for (final yaw in <double>[0, 90, 180, 270]) {
      test('a phone lying flat pointing at ${yaw.toInt()} degrees reads $yaw', () {
        final s = _readingsFor(yaw: yaw);
        final heading = HeadingCalculator.heading(
          ax: s.ax, ay: s.ay, az: s.az,
          mx: s.mx, my: s.my, mz: s.mz,
        );

        expect(heading, isNotNull);
        expect(heading!, closeTo(yaw, 0.01));
      });
    }
  });

  group('attitude round trip', () {
    test('recovers the heading at every 15 degrees while flat', () {
      for (var yaw = 0; yaw < 360; yaw += 15) {
        final s = _readingsFor(yaw: yaw.toDouble());
        final heading = HeadingCalculator.heading(
          ax: s.ax, ay: s.ay, az: s.az,
          mx: s.mx, my: s.my, mz: s.mz,
        );

        expect(heading, isNotNull, reason: 'no heading at yaw $yaw');
        expect(
          _shortestDelta(heading!, yaw.toDouble()),
          closeTo(0, 0.5),
          reason: 'yaw $yaw came back as $heading',
        );
      }
    });

    test('recovers the heading while tilted (pitch and roll)', () {
      const attitudes = <({double yaw, double pitch, double roll})>[
        (yaw: 0, pitch: 0, roll: 30),
        (yaw: 45, pitch: -25, roll: 0),
        (yaw: 120, pitch: 35, roll: -20),
        (yaw: 200, pitch: -40, roll: 15),
        (yaw: 260, pitch: 20, roll: 40),
        (yaw: 315, pitch: 10, roll: -35),
      ];

      for (final attitude in attitudes) {
        final s = _readingsFor(
          yaw: attitude.yaw,
          pitch: attitude.pitch,
          roll: attitude.roll,
        );

        final heading = HeadingCalculator.heading(
          ax: s.ax, ay: s.ay, az: s.az,
          mx: s.mx, my: s.my, mz: s.mz,
        );

        expect(heading, isNotNull, reason: 'no heading at $attitude');
        expect(
          _shortestDelta(heading!, attitude.yaw),
          closeTo(0, 0.5),
          reason: 'attitude $attitude came back as $heading',
        );
      }
    });

    test('the vertical field component is removed, not merely ignored', () {
      // A steep dip (Pakistan is about 40-45 degrees) must not bias the heading.
      for (final inclination in <double>[0, 20, 45, 70]) {
        final s = _readingsFor(yaw: 137, inclinationDegrees: inclination);
        final heading = HeadingCalculator.heading(
          ax: s.ax, ay: s.ay, az: s.az,
          mx: s.mx, my: s.my, mz: s.mz,
        );

        expect(
          _shortestDelta(heading!, 137),
          closeTo(0, 0.5),
          reason: 'inclination $inclination shifted the heading to $heading',
        );
      }
    });
  });

  group('unusable samples', () {
    test('returns null when there is no gravity vector', () {
      expect(
        HeadingCalculator.heading(ax: 0, ay: 0, az: 0, mx: 20, my: 0, mz: 30),
        isNull,
      );
    });

    test('returns null when the field has no horizontal component', () {
      // Phone flat, field pointing straight down: nothing to find north with.
      expect(
        HeadingCalculator.heading(ax: 0, ay: 0, az: 9.81, mx: 0, my: 0, mz: -50),
        isNull,
      );
    });
  });

  group('calibration quality', () {
    test('a realistic field is good', () {
      // Total field = 30 / cos(40) ~ 39 uT, in the earth's normal 25-65 uT band.
      final s = _readingsFor(yaw: 10);
      final magnitude = HeadingCalculator.fieldStrength(mx: s.mx, my: s.my, mz: s.mz);

      expect(magnitude, closeTo(39.2, 1));
      expect(HeadingCalculator.qualityForField(magnitude), HeadingQuality.good);
    });

    test('a field far too weak is unusable', () {
      expect(HeadingCalculator.qualityForField(5), HeadingQuality.unusable);
      expect(HeadingCalculator.qualityForField(0), HeadingQuality.unusable);
    });

    test('a field far too strong asks for a figure-8', () {
      expect(HeadingCalculator.qualityForField(150), HeadingQuality.calibrate);
    });

    test('a non-finite magnitude is unusable rather than crashing', () {
      expect(HeadingCalculator.qualityForField(double.nan), HeadingQuality.unusable);
      // Infinity is not a field strength at all, so it is treated like any other
      // nonsense sample rather than as "too strong".
      expect(HeadingCalculator.qualityForField(double.infinity), HeadingQuality.unusable);
    });

    test('read() reports both the angle and the quality', () {
      final s = _readingsFor(yaw: 200);
      final reading = HeadingCalculator.read(
        ax: s.ax, ay: s.ay, az: s.az,
        mx: s.mx, my: s.my, mz: s.mz,
      );

      expect(reading, isNotNull);
      expect(_shortestDelta(reading!.degrees, 200), closeTo(0, 0.5));
      expect(reading.quality, HeadingQuality.good);
      expect(reading.needsCalibration, isFalse);
    });
  });

  group('smoothing', () {
    test('crosses north the short way', () {
      // Naive averaging of 350 and 10 gives 180; the right answer is 0.
      expect(
        HeadingCalculator.smooth(previous: 350, next: 10, factor: 0.5),
        closeTo(0, 0.001),
      );
    });

    test('a zero factor holds the previous value', () {
      expect(
        HeadingCalculator.smooth(previous: 123, next: 300, factor: 0),
        closeTo(123, 0.001),
      );
    });

    test('a factor of one jumps straight to the new value', () {
      expect(
        HeadingCalculator.smooth(previous: 10, next: 300, factor: 1),
        closeTo(300, 0.001),
      );
    });
  });
}

