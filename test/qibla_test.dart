import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

/*
|--------------------------------------------------------------------------
| Qibla bearing
|--------------------------------------------------------------------------
|
| The expected values are the published Qibla directions for each city, fetched
| from an independent implementation (the Aladhan API's /qibla endpoint) rather
| than recomputed here — a test that derived its own expectation from the same
| formula would prove nothing.
|
| The tolerance is one degree, as specified. Two of the fixtures (London ~119,
| New York ~58.5) are values that are widely published, which is what confirms the
| formula and the Kaaba coordinates are right and not merely self-consistent.
|
*/

const _fixtures = <String, ({double lat, double lng, double bearing})>{
  'Lahore': (lat: 31.5497, lng: 74.3436, bearing: 260.3089614040194),
  'Karachi': (lat: 24.8607, lng: 67.0011, bearing: 267.7410512940412),
  'Faisalabad': (lat: 31.418715, lng: 73.079109, bearing: 259.5525029539919),
  'Multan': (lat: 30.1575, lng: 71.5249, bearing: 260.4723387111496),
  'Peshawar': (lat: 34.0151, lng: 71.5249, bearing: 253.99250591587418),
  'Sialkot': (lat: 32.4972, lng: 74.5362, bearing: 258.9950268167507),
  'London': (lat: 51.5074, lng: -0.1278, bearing: 118.98724251452296),
  'New York': (lat: 40.7128, lng: -74.0060, bearing: 58.481712034206865),
  'Istanbul': (lat: 41.0082, lng: 28.9784, bearing: 151.6206517614259),
  'Jakarta': (lat: -6.2088, lng: 106.8456, bearing: 295.15174505875416),
  'Sydney': (lat: -33.8688, lng: 151.2093, bearing: 277.499589412883),
  'Cairo': (lat: 30.0444, lng: 31.2357, bearing: 136.13734265497988),
  'Dhaka': (lat: 23.8103, lng: 90.4125, bearing: 277.5671640446657),
};

void main() {
  group('bearingToKaaba', () {
    _fixtures.forEach((city, fixture) {
      test('matches the published Qibla direction for $city within one degree', () {
        final actual = Qibla.bearingToKaaba(fixture.lat, fixture.lng);

        expect(
          actual,
          closeTo(fixture.bearing, 1.0),
          reason: '$city: expected ${fixture.bearing}, got $actual',
        );
      });
    });

    test('is always in 0..360', () {
      for (final fixture in _fixtures.values) {
        final bearing = Qibla.bearingToKaaba(fixture.lat, fixture.lng);

        expect(bearing, greaterThanOrEqualTo(0));
        expect(bearing, lessThan(360));
      }
    });

    test('at the Kaaba itself is degenerate but still normalised', () {
      final bearing = Qibla.bearingToKaaba(Qibla.kaabaLatitude, Qibla.kaabaLongitude);

      expect(bearing.isFinite, isTrue);
      expect(bearing, inInclusiveRange(0, 360));
    });

    test('a point due south of the Kaaba points north', () {
      // 1 degree south of Makkah, same longitude: the great circle starts north.
      final bearing = Qibla.bearingToKaaba(Qibla.kaabaLatitude - 1, Qibla.kaabaLongitude);

      expect(bearing, closeTo(0, 0.5));
    });

    test('a point due north of the Kaaba points south', () {
      final bearing = Qibla.bearingToKaaba(Qibla.kaabaLatitude + 1, Qibla.kaabaLongitude);

      expect(bearing, closeTo(180, 0.5));
    });
  });

  group('distanceToKaaba', () {
    test('Lahore is about 3,700 km from Makkah', () {
      expect(Qibla.distanceToKaaba(31.5497, 74.3436), closeTo(3700, 200));
    });

    test('is zero at the Kaaba', () {
      expect(Qibla.distanceToKaaba(Qibla.kaabaLatitude, Qibla.kaabaLongitude), closeTo(0, 0.01));
    });

    test('London is about 4,800 km away', () {
      expect(Qibla.distanceToKaaba(51.5074, -0.1278), closeTo(4800, 250));
    });
  });

  group('relativeBearing', () {
    test('a phone pointing at the Qibla needs no rotation', () {
      expect(
        Qibla.relativeBearing(deviceHeading: 260, qiblaBearing: 260),
        closeTo(0, 0.001),
      );
    });

    test('is positive clockwise and negative anticlockwise', () {
      expect(Qibla.relativeBearing(deviceHeading: 200, qiblaBearing: 260), closeTo(60, 0.001));
      expect(Qibla.relativeBearing(deviceHeading: 320, qiblaBearing: 260), closeTo(-60, 0.001));
    });

    test('takes the short way round the wrap point', () {
      // 350 -> 10 is 20 degrees clockwise, not 340 anticlockwise.
      expect(Qibla.relativeBearing(deviceHeading: 350, qiblaBearing: 10), closeTo(20, 0.001));
      // 10 -> 350 is 20 degrees anticlockwise.
      expect(Qibla.relativeBearing(deviceHeading: 10, qiblaBearing: 350), closeTo(-20, 0.001));
    });

    test('never returns more than half a turn', () {
      for (var from = 0; from < 360; from += 7) {
        for (var to = 0; to < 360; to += 11) {
          final relative = Qibla.relativeBearing(
            deviceHeading: from.toDouble(),
            qiblaBearing: to.toDouble(),
          );

          expect(relative, inInclusiveRange(-180, 180));
        }
      }
    });
  });

  group('describe (the no-sensor fallback)', () {
    test('rounds to a whole degree', () {
      expect(Qibla.describe(260.3089614040194), '260');
      expect(Qibla.describe(58.4817), '58');
    });

    test('wraps 360 to 0', () {
      expect(Qibla.describe(359.7), '0');
    });
  });
}
