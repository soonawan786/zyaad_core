import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

import 'support/prayer_fixtures.dart';

/*
|--------------------------------------------------------------------------
| Local-notification schedule planner
|--------------------------------------------------------------------------
|
| These are the facts the notification service depends on: a reminder fires at the
| prayer's instant minus the lead time, a switched-off prayer produces no reminder,
| and a hidden section produces nothing at all.
|
| The planner is pure, so all of it is asserted without an Android device.
|
*/

const _planner = PrayerNotificationPlanner();

/// Just before Fajr on the first fixture day, so nothing in the window is past.
final _startOfWindow = DateTime.parse('2025-03-14T22:00:00Z');

void main() {
  group('the right notification times', () {
    test('a ten minute lead puts Fajr at 04:42 Karachi time', () {
      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: const IslamicFeatureSettings(reminderLeadMinutes: 10),
        nowUtc: _startOfWindow,
      );

      final fajr = plan.firstWhere((r) => r.prayer == Prayer.fajr && r.date == '2025-03-15');

      expect(fajr.fireAtUtc, karachiInstant('2025-03-15', '04:42'));
      expect(fajr.fireAtUtc, DateTime.utc(2025, 3, 14, 23, 42));
      expect(fajr.prayerWallClock, '04:52');
      expect(fajr.leadMinutes, 10);
    });

    test('a zero lead fires exactly at the prayer', () {
      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: const IslamicFeatureSettings(reminderLeadMinutes: 0),
        nowUtc: _startOfWindow,
      );

      final dhuhr = plan.firstWhere((r) => r.prayer == Prayer.dhuhr && r.date == '2025-03-15');

      expect(dhuhr.fireAtUtc, karachiInstant('2025-03-15', '12:12'));
    });

    test('a thirty minute lead moves every prayer back thirty minutes', () {
      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: const IslamicFeatureSettings(reminderLeadMinutes: 30),
        nowUtc: _startOfWindow,
      );

      final maghrib = plan.firstWhere((r) => r.prayer == Prayer.maghrib && r.date == '2025-03-15');

      expect(maghrib.fireAtUtc, karachiInstant('2025-03-15', '17:41'));
    });

    test('seven days of five prayers is thirty-five notifications', () {
      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: const IslamicFeatureSettings(),
        nowUtc: _startOfWindow,
      );

      expect(plan, hasLength(35));
    });

    test('sunrise never produces a reminder', () {
      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: const IslamicFeatureSettings(),
        nowUtc: _startOfWindow,
      );

      expect(plan.any((r) => r.prayer == Prayer.sunrise), isFalse);
    });

    test('the plan is ordered by fire time', () {
      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: const IslamicFeatureSettings(),
        nowUtc: _startOfWindow,
      );

      for (var i = 1; i < plan.length; i++) {
        expect(
          plan[i].fireAtUtc.isBefore(plan[i - 1].fireAtUtc),
          isFalse,
          reason: 'entry $i is out of order',
        );
      }
    });

    test('a reminder too close to now is not armed', () {
      // 04:45 Karachi, Fajr at 04:52, lead 10 -> 04:42, which has already gone.
      final now = DateTime.parse('2025-03-15T04:45:00+05:00').toUtc();

      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: const IslamicFeatureSettings(),
        nowUtc: now,
      );

      expect(
        plan.any((r) => r.prayer == Prayer.fajr && r.date == '2025-03-15'),
        isFalse,
        reason: "today's Fajr reminder is in the past and must not be armed",
      );

      // The rest of today and the following days are still planned.
      expect(plan.any((r) => r.prayer == Prayer.dhuhr && r.date == '2025-03-15'), isTrue);
      expect(plan.any((r) => r.prayer == Prayer.fajr && r.date == '2025-03-16'), isTrue);
    });

    test('only the requested window is planned', () {
      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15', count: 30),
        settings: const IslamicFeatureSettings(),
        nowUtc: _startOfWindow,
        windowDays: 7,
      );

      final dates = plan.map((r) => r.date).toSet();

      expect(dates, hasLength(7));
      expect(dates, contains('2025-03-21'));
      expect(dates, isNot(contains('2025-03-22')));
    });
  });

  group('toggles remove scheduled notifications', () {
    test('switching Fajr off removes every Fajr reminder', () {
      final settings = const IslamicFeatureSettings().withReminder(Prayer.fajr, false);

      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: settings,
        nowUtc: _startOfWindow,
      );

      expect(plan.any((r) => r.prayer == Prayer.fajr), isFalse);
      expect(plan, hasLength(28)); // 7 days x 4 prayers
    });

    test('the removed ids are still in the cancel set, so nothing is orphaned', () {
      final settings = const IslamicFeatureSettings().withReminder(Prayer.fajr, false);

      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: settings,
        nowUtc: _startOfWindow,
      );
      final ids = PrayerNotificationPlanner.allNotificationIds();
      final plannedIds = plan.map((r) => r.id).toSet();

      // The scheduler cancels every id it could ever use and then schedules the
      // plan, so a prayer switched off is cancelled rather than left behind.
      for (var slot = 0; slot < PrayerNotificationPlanner.defaultWindowDays; slot++) {
        final fajrId = PrayerNotificationPlanner.notificationId(Prayer.fajr, slot);

        expect(ids, contains(fajrId));
        expect(plannedIds, isNot(contains(fajrId)));
      }
    });

    test('switching the reminders master off empties the plan', () {
      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: const IslamicFeatureSettings(azanRemindersEnabled: false),
        nowUtc: _startOfWindow,
      );

      expect(plan, isEmpty);
    });

    test('switching Islamic features off entirely empties the plan', () {
      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: const IslamicFeatureSettings(islamicFeaturesEnabled: false),
        nowUtc: _startOfWindow,
      );

      expect(plan, isEmpty);
    });

    test('switching every prayer off empties the plan', () {
      var settings = const IslamicFeatureSettings();

      for (final prayer in Prayer.obligatory) {
        settings = settings.withReminder(prayer, false);
      }

      final plan = _planner.plan(
        days: daysFixture(from: '2025-03-15'),
        settings: settings,
        nowUtc: _startOfWindow,
      );

      expect(plan, isEmpty);
    });
  });
}

