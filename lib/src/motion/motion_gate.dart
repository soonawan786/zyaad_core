/// Decides whether the live compass may run.
///
/// A compass is useless — and a distraction — in a moving car, so above a speed
/// threshold the screen shows "stop to use" instead of a needle that spins.
///
/// The thresholds are asymmetric on purpose (hysteresis): a driver creeping in
/// traffic must not have the compass flicker on and off every time the speed
/// crosses a single line. Leaving "moving" also requires the speed to stay low for
/// [holdDuration], so a brief stop at a junction does not re-enable it.
class MotionGate {
  MotionGate({
    this.enterThresholdMps = defaultEnterThresholdMps,
    this.exitThresholdMps = defaultExitThresholdMps,
    this.holdDuration = defaultHoldDuration,
  }) : assert(
          exitThresholdMps <= enterThresholdMps,
          'The exit threshold must not exceed the enter threshold, or the gate can never settle.',
        );

  /// ~7.2 km/h. Below this the user is walking or standing.
  static const double defaultEnterThresholdMps = 2.0;

  /// ~3.6 km/h.
  static const double defaultExitThresholdMps = 1.0;

  static const Duration defaultHoldDuration = Duration(seconds: 3);

  final double enterThresholdMps;
  final double exitThresholdMps;
  final Duration holdDuration;

  bool _moving = false;
  DateTime? _belowSince;

  bool get isMoving => _moving;

  /// The compass is only allowed when the vehicle is not moving.
  bool get compassAllowed => !_moving;

  /// Feeds a speed sample. Returns [isMoving].
  ///
  /// A negative or non-finite speed is treated as unknown and leaves the state
  /// alone: a GPS dropout must not turn the compass back on mid-drive.
  bool update({required double speedMps, required DateTime at}) {
    if (!speedMps.isFinite || speedMps < 0) return _moving;

    if (speedMps >= enterThresholdMps) {
      _moving = true;
      _belowSince = null;

      return _moving;
    }

    if (speedMps <= exitThresholdMps) {
      _belowSince ??= at;

      if (at.difference(_belowSince!) >= holdDuration) {
        _moving = false;
        _belowSince = null;
      }

      return _moving;
    }

    // Between the thresholds: keep whatever we decided, and do not let a slow
    // patch count towards leaving "moving".
    _belowSince = null;

    return _moving;
  }

  /// Forgets the state, e.g. when the screen is opened or the trip ends.
  void reset() {
    _moving = false;
    _belowSince = null;
  }
}
