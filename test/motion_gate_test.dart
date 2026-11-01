import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

/*
|--------------------------------------------------------------------------
| Motion gate: "stop to use the compass"
|--------------------------------------------------------------------------
*/

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 9);

  MotionGate gate({double enter = 2.0, double exit = 1.0, Duration hold = const Duration(seconds: 3)}) =>
      MotionGate(enterThresholdMps: enter, exitThresholdMps: exit, holdDuration: hold);

  group('while stopped', () {
    test('a standing user may use the compass', () {
      final g = gate();

      expect(g.update(speedMps: 0, at: t0), isFalse);
      expect(g.compassAllowed, isTrue);
      expect(g.isMoving, isFalse);
    });

    test('walking slowly still allows the compass', () {
      final g = gate();

      expect(g.update(speedMps: 0.8, at: t0), isFalse);
      expect(g.compassAllowed, isTrue);
    });
  });

  group('above the threshold', () {
    test('the compass is disabled immediately once the vehicle is moving', () {
      final g = gate();

      expect(g.update(speedMps: 0, at: t0), isFalse);

      // 2.0 m/s is the default threshold: ~7.2 km/h.
      expect(g.update(speedMps: 2.0, at: t0.add(const Duration(seconds: 1))), isTrue);
      expect(g.compassAllowed, isFalse);
      expect(g.isMoving, isTrue);
    });

    test('a driving speed keeps it disabled', () {
      final g = gate();

      expect(g.update(speedMps: 14, at: t0), isTrue); // ~50 km/h
      expect(g.compassAllowed, isFalse);
    });

    test('stays disabled through a brief stop at a junction', () {
      final g = gate();

      g.update(speedMps: 12, at: t0);

      // Stopped for two seconds: less than the three second hold.
      expect(g.update(speedMps: 0, at: t0.add(const Duration(seconds: 10))), isTrue);
      expect(g.update(speedMps: 0, at: t0.add(const Duration(seconds: 12))), isTrue);
      expect(g.compassAllowed, isFalse);
    });

    test('re-enables after the speed stays low for the hold duration', () {
      final g = gate();

      g.update(speedMps: 12, at: t0);

      expect(g.update(speedMps: 0, at: t0.add(const Duration(seconds: 10))), isTrue);
      expect(g.update(speedMps: 0, at: t0.add(const Duration(seconds: 14))), isFalse);
      expect(g.compassAllowed, isTrue);
    });

    test('a slow patch in traffic does not count towards leaving moving', () {
      final g = gate();

      g.update(speedMps: 12, at: t0);

      // Between the exit (1.0) and enter (2.0) thresholds: state is held.
      expect(g.update(speedMps: 1.5, at: t0.add(const Duration(seconds: 5))), isTrue);
      expect(g.update(speedMps: 1.5, at: t0.add(const Duration(seconds: 20))), isTrue);
      expect(g.compassAllowed, isFalse);
    });

    test('the hysteresis band holds "stopped" too', () {
      final g = gate();

      expect(g.update(speedMps: 0, at: t0), isFalse);

      // 1.5 m/s is above the exit threshold but below the enter threshold.
      expect(g.update(speedMps: 1.5, at: t0.add(const Duration(seconds: 5))), isFalse);
      expect(g.compassAllowed, isTrue);
    });
  });

  group('bad samples', () {
    test('a GPS dropout does not turn the compass back on mid-drive', () {
      final g = gate();

      g.update(speedMps: 15, at: t0);

      expect(g.update(speedMps: -1, at: t0.add(const Duration(seconds: 10))), isTrue);
      expect(g.update(speedMps: double.nan, at: t0.add(const Duration(seconds: 20))), isTrue);
      expect(g.compassAllowed, isFalse);
    });
  });

  group('reset', () {
    test('clears the state', () {
      final g = gate();

      g.update(speedMps: 15, at: t0);
      g.reset();

      expect(g.isMoving, isFalse);
      expect(g.compassAllowed, isTrue);
    });
  });

  group('configuration', () {
    test('a custom threshold is honoured', () {
      final g = gate(enter: 5.0, exit: 3.0);

      expect(g.update(speedMps: 3, at: t0), isFalse);
      expect(g.update(speedMps: 5, at: t0.add(const Duration(seconds: 1))), isTrue);
    });

    test('an exit threshold above the enter threshold is rejected', () {
      expect(
        () => MotionGate(enterThresholdMps: 1, exitThresholdMps: 5),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
