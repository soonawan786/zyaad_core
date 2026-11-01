import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

/*
|--------------------------------------------------------------------------
| The driver's prayer break timer
|--------------------------------------------------------------------------
|
| The rules (no break with a passenger, the daily limit, going off dispatch) live on
| the server and are covered by the backend suite. What is asserted here is the part
| the client owns: the countdown, the progress ring, and the allowance the button
| reads to decide whether it can be tapped at all.
|
| This lives in zyaad_core rather than the driver app because it is pure arithmetic
| with no plugin dependency — which is what lets it be tested without a device.
|
*/

const _breakJson = {
  'id': 'brk-1',
  'status': 'active',
  'duration_minutes': 15,
  'started_at': '2026-01-01T09:00:00+05:00',
  'ends_at': '2026-01-01T09:15:00+05:00',
  'off_dispatch': true,
};

void main() {
  group('parsing the break', () {
    test('reads the start, the end and the duration', () {
      final prayerBreak = PrayerBreak.fromApi(_breakJson)!;

      expect(prayerBreak.id, 'brk-1');
      expect(prayerBreak.durationMinutes, 15);
      // 09:00 Karachi is 04:00 UTC.
      expect(prayerBreak.startedAtUtc, DateTime.utc(2026, 1, 1, 4));
      expect(prayerBreak.endsAtUtc, DateTime.utc(2026, 1, 1, 4, 15));
    });

    test('derives the start from the end when the server omits it', () {
      final prayerBreak = PrayerBreak.fromApi({
        'id': 'brk-2',
        'duration_minutes': 10,
        'ends_at': '2026-01-01T09:10:00+05:00',
      })!;

      expect(prayerBreak.startedAtUtc, DateTime.utc(2026, 1, 1, 4));
    });

    test('an inactive break is null, not a broken object', () {
      expect(PrayerBreak.fromApi(null), isNull);
      expect(PrayerBreak.fromApi(const {}), isNull);
      expect(PrayerBreak.fromApi({'id': 'x', 'ends_at': 'nonsense'}), isNull);
    });
  });

  group('the countdown', () {
    final prayerBreak = PrayerBreak.fromApi(_breakJson)!;

    test('counts down to the end', () {
      expect(prayerBreak.remaining(DateTime.utc(2026, 1, 1, 4)), const Duration(minutes: 15));
      expect(prayerBreak.remaining(DateTime.utc(2026, 1, 1, 4, 10)), const Duration(minutes: 5));
    });

    test('never goes negative, so the UI cannot show a minus sign', () {
      expect(prayerBreak.remaining(DateTime.utc(2026, 1, 1, 5)), Duration.zero);
      expect(prayerBreak.remainingMinutes(DateTime.utc(2026, 1, 1, 5)), 0);
    });

    test('reports whole minutes, rounded up', () {
      expect(prayerBreak.remainingMinutes(DateTime.utc(2026, 1, 1, 4, 14, 1)), 1);
    });

    test('formats as MM:SS', () {
      expect(prayerBreak.countdownLabel(DateTime.utc(2026, 1, 1, 4)), '15:00');
      expect(prayerBreak.countdownLabel(DateTime.utc(2026, 1, 1, 4, 14, 30)), '00:30');
      expect(prayerBreak.countdownLabel(DateTime.utc(2026, 1, 1, 5)), '00:00');
    });

    test('is finished exactly at the end time, not after it', () {
      expect(prayerBreak.isFinishedAt(DateTime.utc(2026, 1, 1, 4, 14, 59)), isFalse);
      expect(prayerBreak.isFinishedAt(DateTime.utc(2026, 1, 1, 4, 15)), isTrue);
    });

    test('the progress ring runs from zero to one', () {
      expect(prayerBreak.progressAt(DateTime.utc(2026, 1, 1, 4)), 0);
      expect(prayerBreak.progressAt(DateTime.utc(2026, 1, 1, 4, 7, 30)), closeTo(0.5, 0.01));
      expect(prayerBreak.progressAt(DateTime.utc(2026, 1, 1, 4, 15)), 1);
      expect(prayerBreak.progressAt(DateTime.utc(2026, 1, 1, 6)), 1);
    });
  });

  group('the daily allowance', () {
    test('reads the counters and the limits the server sent', () {
      final allowance = PrayerBreakAllowance.fromApi({
        'active': null,
        'used_today': 1,
        'remaining_today': 2,
        'limits': {'min_minutes': 5, 'max_minutes': 30, 'daily_limit': 3},
      });

      expect(allowance.usedToday, 1);
      expect(allowance.remainingToday, 2);
      expect(allowance.dailyLimit, 3);
      expect(allowance.minMinutes, 5);
      expect(allowance.maxMinutes, 30);
      expect(allowance.canStart, isTrue);
    });

    test('an exhausted allowance cannot be started', () {
      final allowance = PrayerBreakAllowance.fromApi({
        'used_today': 3,
        'remaining_today': 0,
        'limits': {'daily_limit': 3},
      });

      expect(allowance.canStart, isFalse);
    });

    test('a missing payload falls back to safe defaults rather than crashing', () {
      final allowance = PrayerBreakAllowance.fromApi(const {});

      expect(allowance.remainingToday, 0);
      expect(allowance.minMinutes, 5);
      expect(allowance.maxMinutes, 30);
      expect(allowance.canStart, isFalse);
    });

    test('the picker offers the configured window in five minute steps', () {
      const allowance = PrayerBreakAllowance(minMinutes: 5, maxMinutes: 30);

      expect(allowance.durationOptions, [5, 10, 15, 20, 25, 30]);
    });

    test('a window that is not a multiple of five still includes its maximum', () {
      const allowance = PrayerBreakAllowance(minMinutes: 5, maxMinutes: 22);

      expect(allowance.durationOptions, contains(22));
    });

    test('a requested duration is clamped into the window', () {
      const allowance = PrayerBreakAllowance(minMinutes: 5, maxMinutes: 30);

      // The server refuses anything outside the window; clamping means the app
      // never sends a value that is guaranteed to be rejected.
      expect(allowance.clampMinutes(2), 5);
      expect(allowance.clampMinutes(45), 30);
      expect(allowance.clampMinutes(15), 15);
    });
  });
}
