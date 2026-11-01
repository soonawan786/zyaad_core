import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../qibla/qibla_controller.dart';
import '../sensors/heading.dart';

/// The Qibla screen, shared by both apps.
///
/// Three states, in priority order:
///
///  1. **No compass** (no sensor, or nothing usable yet) — the plain-text fallback,
///     "Qibla is 260 degrees from North", plus the distance. The screen is still
///     useful without a magnetometer.
///  2. **Moving** — the live needle is switched off and the user is told to stop.
///     A compass that spins in a moving car is worse than no compass.
///  3. **Live** — the needle, rotated by the angle between where the phone points
///     and where the Kaaba is, with a calibration prompt when the field looks
///     distorted.
///
/// It is parameterised rather than reaching into a host-app controller: the caller
/// passes the position, whether the user has hidden the feature, and (optionally) a
/// speed source.
class QiblaScreen extends StatelessWidget {
  const QiblaScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.featuresHidden = false,
    this.speedProvider,
    this.qiblaController,
  });

  final double latitude;
  final double longitude;

  /// True when the user has switched Islamic features off; the screen then says so
  /// instead of showing a bearing they did not ask for.
  final bool featuresHidden;

  /// The current speed in m/s, when the caller knows it. Null means "assume
  /// stopped", which is what a user who opened the screen on foot wants.
  final double? Function()? speedProvider;

  /// Injected in tests so no sensor stream is opened.
  final QiblaController? qiblaController;

  @override
  Widget build(BuildContext context) {
    if (featuresHidden) {
      return Scaffold(
        appBar: AppBar(title: const Text('Qibla')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Islamic features are hidden. Turn them back on in settings.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Qibla')),
      body: _Body(
        controller: qiblaController ??
            QiblaController(
              latitude: latitude,
              longitude: longitude,
              speedProvider: speedProvider,
            ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.controller});

  final QiblaController controller;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final qibla = widget.controller;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (qibla.isMoving)
                const _Notice(
                  icon: Icons.directions_car_outlined,
                  title: 'Stop to use the compass',
                  body: 'The compass is switched off while the vehicle is moving.',
                )
              else if (qibla.sensorUnavailable)
                _Notice(
                  icon: Icons.explore_off_outlined,
                  title: 'No compass on this device',
                  body: 'Qibla is ${qibla.bearingText} degrees from North',
                )
              else if (!qibla.hasCompass)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (qibla.quality == HeadingQuality.calibrate)
                  const _Notice(
                    icon: Icons.threesixty_outlined,
                    title: 'Move your phone in a figure 8 to calibrate',
                    body: null,
                  ),
                const SizedBox(height: 8),
                _CompassDial(qibla: qibla),
              ],
              const SizedBox(height: 24),
              // The text answer is always shown, so the screen is usable even when
              // the needle is hidden or uncalibrated.
              _FactRow(label: 'From North', value: '${qibla.bearingText}°'),
              _FactRow(
                label: 'Distance to Makkah',
                value: '${qibla.distanceKm.round()} km',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompassDial extends StatelessWidget {
  const _CompassDial({required this.qibla});

  final QiblaController qibla;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
            ),
            // The dial's north marker stays fixed to the phone; the arrow rotates
            // by the angle the user must turn.
            Positioned(
              top: 8,
              child: Text('N', style: Theme.of(context).textTheme.labelMedium),
            ),
            Transform.rotate(
              angle: qibla.relativeBearing * math.pi / 180,
              child: Icon(
                Icons.navigation,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 4),
                    Text(body!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

