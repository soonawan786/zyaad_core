import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../motion/motion_gate.dart';
import '../qibla/qibla.dart';
import '../sensors/heading.dart';

/// Drives the Qibla screen: the bearing to the Kaaba, the live compass, and the
/// two cases where the compass must not be shown.
///
/// Parameterised rather than coupled to a host-app controller, so the rider app
/// and the driver app share the screen and each supplies its own position and
/// speed. The maths lives in `qibla.dart` / `heading.dart` and is unit-tested
/// there; this class only wires it to the sensors.
class QiblaController extends ChangeNotifier {
  QiblaController({
    required this.latitude,
    required this.longitude,
    this.speedProvider,
    MotionGate? motionGate,
    this.startSensors = true,
  }) : _gate = motionGate ?? MotionGate() {
    if (startSensors) _listen();
  }

  final double latitude;
  final double longitude;

  /// The current speed in m/s, or null when unknown. Supplied by the caller (the
  /// ride/location layer) so this class does not depend on it.
  final double? Function()? speedProvider;

  /// False in a widget test, so the sensor streams are never opened.
  final bool startSensors;

  final MotionGate _gate;

  /// The direction to face, in degrees clockwise from true north.
  late final double qiblaBearing = Qibla.bearingToKaaba(latitude, longitude);

  /// Great-circle distance to the Kaaba, in km.
  late final double distanceKm = Qibla.distanceToKaaba(latitude, longitude);

  /// 0..360 from the magnetometer, or null when nothing usable has arrived.
  double? deviceHeading;

  HeadingQuality quality = HeadingQuality.good;

  /// False until a sensor sample arrives, so the UI can fall back to text.
  bool hasCompass = false;

  /// Set when the platform reports no magnetometer at all.
  bool sensorUnavailable = false;

  int _samples = 0;

  bool get isMoving => _gate.isMoving;

  /// The compass is only live when the vehicle is stopped.
  bool get compassAllowed => _gate.compassAllowed && hasCompass;

  /// Where the Kaaba is relative to where the phone is pointing.
  double get relativeBearing => Qibla.relativeBearing(
        deviceHeading: deviceHeading ?? 0,
        qiblaBearing: qiblaBearing,
      );

  /// The plain-text fallback, e.g. "Qibla is 260 degrees from North".
  String get bearingText => Qibla.describe(qiblaBearing);

  /// Number of magnetometer samples folded into the reading, for a debug row.
  int get sampleCount => _samples;

  StreamSubscription<MagnetometerEvent>? _magnetometer;
  StreamSubscription<AccelerometerEvent>? _accelerometer;

  AccelerometerEvent? _lastAccelerometer;

  void _listen() {
    try {
      _accelerometer = accelerometerEventStream().listen(
        (event) => _lastAccelerometer = event,
        onError: (_) => _markUnavailable(),
      );

      _magnetometer = magnetometerEventStream().listen(
        _onMagnetometer,
        onError: (_) => _markUnavailable(),
      );
    } catch (_) {
      // A device without the sensors at all: the screen falls back to the text.
      _markUnavailable();
    }
  }

  void _markUnavailable() {
    sensorUnavailable = true;
    notifyListeners();
  }

  void _onMagnetometer(MagnetometerEvent event) {
    final accel = _lastAccelerometer;

    if (accel == null) return;

    final reading = HeadingCalculator.read(
      ax: accel.x, ay: accel.y, az: accel.z,
      mx: event.x, my: event.y, mz: event.z,
    );

    if (reading == null) return;

    // Smooth so the needle does not jitter, along the shortest angular path.
    deviceHeading = deviceHeading == null
        ? reading.degrees
        : HeadingCalculator.smooth(previous: deviceHeading!, next: reading.degrees);

    quality = reading.quality;
    hasCompass = true;
    _samples++;

    // Feed the speed in on the same cadence as the sensor, which is what the gate
    // wants: a decision per sample, not per screen frame.
    _gate.update(speedMps: speedProvider?.call() ?? 0, at: DateTime.now());

    notifyListeners();
  }

  @override
  void dispose() {
    _magnetometer?.cancel();
    _accelerometer?.cancel();
    super.dispose();
  }
}
