import '../prayer/islamic_feature_settings.dart';
import '../prayer/prayer_day.dart';
import '../prayer/prayer_notification_planner.dart';

import 'prayer_notification_channel.dart';

/// The title and body for one reminder, built by the app (which owns the
/// translations) so the scheduler itself stays free of UI and locale concerns.
typedef PrayerReminderText = ({String title, String body}) Function(
  PlannedPrayerReminder reminder,
);

/// What a reschedule actually did, so the settings screen can tell the truth
/// about it rather than assuming success.
class PrayerScheduleOutcome {
  const PrayerScheduleOutcome({
    required this.scheduled,
    required this.cancelled,
    required this.exactAlarmsGranted,
    this.nextFireAtUtc,
  });

  /// How many notifications are now armed.
  final int scheduled;

  /// How many ids were cleared first.
  final int cancelled;

  /// False means the reminders are inexact and the OS may delay them.
  final bool exactAlarmsGranted;

  /// The soonest reminder, for the "next reminder in ..." line.
  final DateTime? nextFireAtUtc;

  static const PrayerScheduleOutcome none = PrayerScheduleOutcome(
    scheduled: 0,
    cancelled: 0,
    exactAlarmsGranted: true,
  );
}

/// Puts the planner's output on the device.
///
/// The strategy is deliberately **cancel everything, then schedule the plan**:
/// every id the planner may ever use is cleared first, so a prayer the user has
/// just switched off cannot survive as an orphan the app no longer knows about.
class PrayerNotificationScheduler {
  PrayerNotificationScheduler({
    required PrayerNotificationChannel channel,
    PrayerNotificationPlanner planner = const PrayerNotificationPlanner(),
  })  : _channel = channel,
        _planner = planner;

  final PrayerNotificationChannel _channel;
  final PrayerNotificationPlanner _planner;

  /// Rebuilds the device's schedule from the next [windowDays] of prayer times.
  ///
  /// Called on app start, on a city or timezone change, and after the settings
  /// change — anywhere the answer could have moved.
  Future<PrayerScheduleOutcome> reschedule({
    required List<PrayerDay> days,
    required IslamicFeatureSettings settings,
    required DateTime nowUtc,
    required PrayerReminderText text,
    bool rideActive = false,
    int windowDays = PrayerNotificationPlanner.defaultWindowDays,
  }) async {
    final ids = PrayerNotificationPlanner.allNotificationIds();

    await _channel.cancel(ids);

    final plan = _planner.plan(
      days: days,
      settings: settings,
      nowUtc: nowUtc,
      rideActive: rideActive,
      windowDays: windowDays,
    );

    if (plan.isEmpty) {
      return PrayerScheduleOutcome(
        scheduled: 0,
        cancelled: ids.length,
        exactAlarmsGranted: await _channel.canScheduleExactAlarms(),
      );
    }

    // The timezone each reminder belongs to: a city's own zone, taken from the day
    // the reminder came from, so a DST city stays correct.
    final timezoneByDate = <String, String>{
      for (final day in days) day.date: day.timezone,
    };

    for (final reminder in plan) {
      final copy = text(reminder);

      await _channel.schedule(
        id: reminder.id,
        fireAtUtc: reminder.fireAtUtc,
        timezone: timezoneByDate[reminder.date] ?? 'UTC',
        title: copy.title,
        body: copy.body,
        payload: 'prayer:${reminder.prayer.key}:${reminder.date}',
        sound: reminder.sound,
      );
    }

    return PrayerScheduleOutcome(
      scheduled: plan.length,
      cancelled: ids.length,
      exactAlarmsGranted: await _channel.canScheduleExactAlarms(),
      nextFireAtUtc: plan.first.fireAtUtc,
    );
  }

  /// Removes every prayer reminder the app could have armed.
  Future<void> cancelAll() =>
      _channel.cancel(PrayerNotificationPlanner.allNotificationIds());
}
