import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

import 'support/prayer_fixtures.dart';

/*
|--------------------------------------------------------------------------
| Prayer day parsing and the "next prayer" the home card shows
|--------------------------------------------------------------------------
*/

void main() {
  group('parsing the API payload', () {
    test('reads every prayer with its wall clock and absolute instant', () {
      final day = dayFixture(date: '2025-03-15');

      expect(day.date, '2025-03-15');
      expect(day.timezone, 'Asia/Karachi');
      expect(day.times, hasLength(6));

      final fajr = day.time(Prayer.fajr)!;

      expect(fajr.wallClock, '04:52');
      expect(fajr.instantUtc.isUtc, isTrue);
      expect(fajr.instantUtc, karachiInstant('2025-03-15', '04:52'));

      // 04:52 in Karachi is 23:52 the previous day in UTC.
      expect(fajr.instantUtc, DateTime.utc(2025, 3, 14, 23, 52));
    });

    test('ordered runs Fajr to Isha', () {
      final day = dayFixture(date: '2025-03-15');

      expect(day.ordered.map((t) => t.prayer).toList(), Prayer.all);
    });

    test('a broken entry is skipped without losing the day', () {
      final day = PrayerDay.fromApi({
        'date': '2025-03-15',
        'timezone': 'Asia/Karachi',
        'times': {
          'fajr': {'time': '04:52', 'at': '2025-03-15T04:52:00+05:00'},
          'dhuhr': {'time': '12:12'}, // no `at`
          'asr': {'time': '16:28', 'at': 'not-a-date'},
        },
      });

      expect(day.time(Prayer.fajr), isNotNull);
      expect(day.time(Prayer.dhuhr), isNull);
      expect(day.time(Prayer.asr), isNull);
      expect(day.isEmpty, isFalse);
    });

    test('an empty payload yields an empty day rather than throwing', () {
      final day = PrayerDay.fromApi(const {});

      expect(day.isEmpty, isTrue);
      expect(day.timezone, 'UTC');
    });

    test('the per-prayer offset is carried through', () {
      final day = PrayerDay.fromApi({
        'date': '2025-03-15',
        'timezone': 'Asia/Karachi',
        'times': {
          'fajr': {
            'time': '04:55',
            'at': '2025-03-15T04:55:00+05:00',
            'offset_minutes': 3,
          },
        },
      });

      expect(day.time(Prayer.fajr)!.offsetMinutes, 3);
    });
  });

  group('ramadan', () {
    test('is parsed when a period is confirmed', () {
      final day = dayFixture(
        date: '2025-03-15',
        ramadan: {
          'name': 'Ramadan',
          'hijri_year': 1446,
          'starts_on': '2025-03-01',
          'ends_on': '2025-03-30',
          'sehri_ends_at': '2025-03-15T04:52:00+05:00',
          'sehri_ends_time': '04:52',
          'iftar_at': '2025-03-15T18:11:00+05:00',
          'iftar_time': '18:11',
        },
      );

      final ramadan = day.ramadan!;

      expect(ramadan.name, 'Ramadan');
      expect(ramadan.hijriYear, 1446);
      expect(ramadan.sehriEndsWallClock, '04:52');
      expect(ramadan.iftarWallClock, '18:11');
      expect(ramadan.sehriEndsAtUtc, karachiInstant('2025-03-15', '04:52'));
      expect(ramadan.iftarAtUtc, karachiInstant('2025-03-15', '18:11'));
    });

    test('is null outside a confirmed period', () {
      expect(dayFixture(date: '2025-03-15').ramadan, isNull);
      expect(dayFixture(date: '2025-03-15', ramadan: null).ramadan, isNull);
    });

    test('an incomplete block is ignored rather than half-populated', () {
      final day = dayFixture(date: '2025-03-15', ramadan: {'name': 'Ramadan'});

      expect(day.ramadan, isNull);
    });
  });

  group('next prayer', () {
    test('mid-morning is Dhuhr, and sunrise is never the answer', () {
      final day = dayFixture(date: '2025-03-15');
      final now = DateTime.parse('2025-03-15T08:00:00+05:00').toUtc();

      final next = day.nextAfter(now)!;

      expect(next.prayer, Prayer.dhuhr);
      expect(next.wallClock, '12:12');
      expect(next.tomorrow, isFalse);
      expect(next.remaining, const Duration(hours: 4, minutes: 12));
      expect(next.remainingMinutes, 252);
    });

    test('between sunrise and dhuhr the answer is still dhuhr, not sunrise', () {
      final day = dayFixture(date: '2025-03-15');
      final now = DateTime.parse('2025-03-15T06:30:00+05:00').toUtc();

      expect(day.nextAfter(now)!.prayer, Prayer.dhuhr);
    });

    test('after Isha it rolls into tomorrow Fajr', () {
      final today = dayFixture(date: '2025-03-15');
      final tomorrow = dayFixture(date: '2025-03-16');
      final now = DateTime.parse('2025-03-15T22:00:00+05:00').toUtc();

      final next = today.nextAfter(now, tomorrow: tomorrow)!;

      expect(next.prayer, Prayer.fajr);
      expect(next.tomorrow, isTrue);
      expect(next.date, '2025-03-16');
      expect(next.wallClock, '04:52');
    });

    test('without tomorrow the rollover returns null instead of guessing', () {
      final today = dayFixture(date: '2025-03-15');
      final now = DateTime.parse('2025-03-15T22:00:00+05:00').toUtc();

      expect(today.nextAfter(now), isNull);
    });

    test('nextAcross walks forward through a window of days', () {
      final days = daysFixture(from: '2025-03-15', count: 3);
      final now = DateTime.parse('2025-03-15T22:00:00+05:00').toUtc();

      final next = PrayerDay.nextAcross(days, now)!;

      expect(next.prayer, Prayer.fajr);
      expect(next.date, '2025-03-16');
    });

    test('the countdown is formatted and never negative', () {
      final day = dayFixture(date: '2025-03-15');
      final now = DateTime.parse('2025-03-15T08:00:00+05:00').toUtc();

      expect(day.nextAfter(now)!.countdown, '4:12:00');
    });
  });

  group('prayer labels', () {
    test('have English and Urdu forms', () {
      expect(Prayer.fajr.label('en'), 'Fajr');
      expect(Prayer.fajr.label('ur'), 'فجر');
      expect(Prayer.maghrib.label('ur'), 'مغرب');
    });

    test('an unknown locale falls back to English', () {
      expect(Prayer.asr.label('fr'), 'Asr');
    });

    test('tryParse rejects an unknown key', () {
      expect(Prayer.tryParse('tahajjud'), isNull);
      expect(Prayer.tryParse(null), isNull);
      expect(Prayer.tryParse('isha'), Prayer.isha);
    });
  });
}

