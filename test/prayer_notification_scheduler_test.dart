import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

/*
|--------------------------------------------------------------------------
| The device-side notification scheduler
|--------------------------------------------------------------------------
|
| The planner is unit-tested in zyaad_core; this covers the part that talks to the
| plugin: which ids are cancelled, which instants are handed to the OS, and whether
| the azan sound is on. The plugin is replaced by a recording fake, so the suite
| needs no device and no permission prompts.
|
*/

/// Records everything the scheduler asks the platform to do.
class FakePrayerNotificationChannel implements PrayerNotificationChannel {
  int initializeCalls = 0;
  bool exactAlarms = true;
  bool permissionGranted = true;

  final List<int> cancelled = [];
  final List<({int id, DateTime fireAtUtc, String timezone, bool sound, String payload})>
      scheduled = [];

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<bool> requestExactAlarmPermission() async => exactAlarms;

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarms;

  @override
  Future<void> cancel(Iterable<int> ids) async => cancelled.addAll(ids);

  @override
  Future<void> schedule({
    required int id,
    required DateTime fireAtUtc,
    required String timezone,
    required String title,
    required String body,
    required String payload,
    required bool sound,
  }) async {
    scheduled.add(
      (id: id, fireAtUtc: fireAtUtc, timezone: timezone, sound: sound, payload: payload),
    );
  }
}

/// The API shape `GET /api/v1/prayer-times` returns.
PrayerDay day(String date) => PrayerDay.fromApi({
      'date': date,
      'timezone': 'Asia/Karachi',
      'times': {
        for (final entry in const {
          'fajr': '04:52',
          'sunrise': '06:13',
          'dhuhr': '12:12',
          'asr': '16:28',
          'maghrib': '18:11',
          'isha': '19:32',
        }.entries)
          entry.key: {
            'label': entry.key,
            'time': entry.value,
            'at': '${date}T${entry.value}:00+05:00',
            'offset_minutes': 0,
          },
      },
    });

List<PrayerDay> window({int count = 7}) {
  final start = DateTime.parse('2025-03-15T00:00:00Z');

  return [
    for (var i = 0; i < count; i++)
      () {
        final date = start.add(Duration(days: i));

        return day(
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
        );
      }(),
  ];
}

/// Just before Fajr on the first day.
final beforeWindow = DateTime.parse('2025-03-14T22:00:00Z');

({String title, String body}) plainText(PlannedPrayerReminder reminder) =>
    (title: '${reminder.prayer.key} ${reminder.prayerWallClock}', body: 'reminder');

void main() {
  late FakePrayerNotificationChannel channel;
  late PrayerNotificationScheduler scheduler;

  setUp(() {
    channel = FakePrayerNotificationChannel();
    scheduler = PrayerNotificationScheduler(channel: channel);
  });

  group('scheduling produces the right notification times', () {
    test('seven days of five prayers are armed', () async {
      final outcome = await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(reminderLeadMinutes: 10),
        nowUtc: beforeWindow,
        text: plainText,
      );

      expect(outcome.scheduled, 35);
      expect(channel.scheduled, hasLength(35));
    });

    test('each instant is the prayer minus the lead time', () async {
      await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(reminderLeadMinutes: 10),
        nowUtc: beforeWindow,
        text: plainText,
      );

      final fajr = channel.scheduled.firstWhere(
        (entry) => entry.id == PrayerNotificationPlanner.notificationId(Prayer.fajr, 0),
      );

      // 04:52 Karachi minus ten minutes is 04:42 Karachi, i.e. 23:42 UTC the day
      // before.
      expect(fajr.fireAtUtc, DateTime.utc(2025, 3, 14, 23, 42));
      expect(fajr.timezone, 'Asia/Karachi');
      expect(fajr.payload, 'prayer:fajr:2025-03-15');
    });

    test('the lead time shifts every instant', () async {
      await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(reminderLeadMinutes: 0),
        nowUtc: beforeWindow,
        text: plainText,
      );

      final dhuhr = channel.scheduled.firstWhere(
        (entry) => entry.id == PrayerNotificationPlanner.notificationId(Prayer.dhuhr, 0),
      );

      expect(dhuhr.fireAtUtc, DateTime.parse('2025-03-15T12:12:00+05:00').toUtc());
    });

    test('a reminder already in the past is not armed', () async {
      // Mid-morning: today's Fajr reminder is gone.
      final now = DateTime.parse('2025-03-15T11:00:00+05:00').toUtc();

      await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(reminderLeadMinutes: 10),
        nowUtc: now,
        text: plainText,
      );

      final armedIds = channel.scheduled.map((entry) => entry.id);

      expect(armedIds, isNot(contains(PrayerNotificationPlanner.notificationId(Prayer.fajr, 0))));
      expect(armedIds, contains(PrayerNotificationPlanner.notificationId(Prayer.asr, 0)));
    });
  });

  group('toggles remove scheduled notifications', () {
    test('everything is cancelled before anything is armed', () async {
      await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(),
        nowUtc: beforeWindow,
        text: plainText,
      );

      // The whole reserved id space is cleared first, so a prayer switched off in a
      // previous session cannot survive as an orphan.
      expect(
        channel.cancelled,
        containsAll(PrayerNotificationPlanner.allNotificationIds()),
      );
    });

    test('switching Fajr off leaves no Fajr notification armed', () async {
      final settings = const IslamicFeatureSettings().withReminder(Prayer.fajr, false);

      final outcome = await scheduler.reschedule(
        days: window(),
        settings: settings,
        nowUtc: beforeWindow,
        text: plainText,
      );

      expect(outcome.scheduled, 28);

      final armedIds = channel.scheduled.map((entry) => entry.id).toSet();

      for (var slot = 0; slot < PrayerNotificationPlanner.defaultWindowDays; slot++) {
        final fajrId = PrayerNotificationPlanner.notificationId(Prayer.fajr, slot);

        // Cancelled (it is in the cleared space) and not re-armed.
        expect(channel.cancelled, contains(fajrId));
        expect(armedIds, isNot(contains(fajrId)));
      }
    });

    test('switching the master off cancels everything and arms nothing', () async {
      final outcome = await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(islamicFeaturesEnabled: false),
        nowUtc: beforeWindow,
        text: plainText,
      );

      expect(outcome.scheduled, 0);
      expect(channel.scheduled, isEmpty);
      expect(
        channel.cancelled,
        hasLength(PrayerNotificationPlanner.allNotificationIds().length),
      );
    });

    test('switching the reminders master off arms nothing', () async {
      final outcome = await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(azanRemindersEnabled: false),
        nowUtc: beforeWindow,
        text: plainText,
      );

      expect(outcome.scheduled, 0);
      expect(channel.scheduled, isEmpty);
    });

    test('cancelAll clears the reserved space without scheduling', () async {
      await scheduler.cancelAll();

      expect(channel.scheduled, isEmpty);
      expect(
        channel.cancelled,
        hasLength(PrayerNotificationPlanner.allNotificationIds().length),
      );
    });
  });

  group('azan sound', () {
    test('is off on every notification by default', () async {
      await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(),
        nowUtc: beforeWindow,
        text: plainText,
      );

      expect(channel.scheduled.every((entry) => entry.sound), isFalse);
    });

    test('is on when the user asked for it', () async {
      await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(azanSoundEnabled: true),
        nowUtc: beforeWindow,
        text: plainText,
      );

      expect(channel.scheduled.every((entry) => entry.sound), isTrue);
    });

    test('is suppressed during a ride unless the user allowed it', () async {
      await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(azanSoundEnabled: true),
        nowUtc: beforeWindow,
        text: plainText,
        rideActive: true,
      );

      expect(
        channel.scheduled.every((entry) => entry.sound),
        isFalse,
        reason: 'the azan must not autoplay over a live ride',
      );
    });

    test('a ride keeps the sound for a user who explicitly allowed it', () async {
      await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(
          azanSoundEnabled: true,
          azanSoundDuringRide: true,
        ),
        nowUtc: beforeWindow,
        text: plainText,
        rideActive: true,
      );

      expect(channel.scheduled.every((entry) => entry.sound), isTrue);
    });
  });

  group('exact alarms', () {
    test('are reported as granted when the OS allows them', () async {
      final outcome = await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(),
        nowUtc: beforeWindow,
        text: plainText,
      );

      expect(outcome.exactAlarmsGranted, isTrue);
    });

    test('are reported as refused, and the reminders are still armed inexactly', () async {
      channel.exactAlarms = false;

      final outcome = await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(),
        nowUtc: beforeWindow,
        text: plainText,
      );

      expect(outcome.exactAlarmsGranted, isFalse);
      // The reminders are not dropped just because the permission is missing.
      expect(outcome.scheduled, 35);
    });
  });

  group('the outcome the settings screen shows', () {
    test('reports the soonest reminder', () async {
      final outcome = await scheduler.reschedule(
        days: window(),
        settings: const IslamicFeatureSettings(reminderLeadMinutes: 10),
        nowUtc: beforeWindow,
        text: plainText,
      );

      expect(outcome.nextFireAtUtc, DateTime.utc(2025, 3, 14, 23, 42));
    });
  });
}



