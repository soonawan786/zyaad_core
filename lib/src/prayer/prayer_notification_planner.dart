import 'islamic_feature_settings.dart';
import 'prayer.dart';
import 'prayer_day.dart';

/// One notification the device must have scheduled.
class PlannedPrayerReminder {
  const PlannedPrayerReminder({
    required this.id,
    required this.prayer,
    required this.fireAtUtc,
    required this.prayerWallClock,
    required this.date,
    required this.leadMinutes,
    required this.sound,
  });

  /// Stable id, derived from the prayer and its slot in the window.
  final int id;

  final Prayer prayer;

  /// When the notification must fire — the prayer's instant minus the lead time.
  final DateTime fireAtUtc;

  /// The prayer's own city time, for the notification body.
  final String prayerWallClock;

  final String date;
  final int leadMinutes;

  /// Whether this one carries the azan sound.
  final bool sound;

  Duration timeUntil(DateTime nowUtc) => fireAtUtc.difference(nowUtc.toUtc());

  @override
  String toString() => '#$id ${prayer.key} $date ${fireAtUtc.toIso8601String()}';
}

/// Turns a window of prayer times into the exact list of local notifications the
/// device should hold.
///
/// Pure and deterministic, which is the point: "the reminder fires at the right
/// minute" and "switching a prayer off removes its notification" are testable
/// facts rather than things someone has to check on a phone at 4am.
///
/// The scheduler is expected to **cancel every id in [allNotificationIds] and then
/// schedule the plan**. That makes a toggle-off take effect without the app having
/// to remember what it scheduled last time, and it cannot leave an orphan behind.
class PrayerNotificationPlanner {
  const PrayerNotificationPlanner();

  /// Base of the notification id space reserved for prayer reminders.
  static const int notificationIdBase = 910000;

  /// How many day slots ids are reserved for. Larger than the default window so a
  /// window change cannot collide with an id that is still scheduled.
  static const int idSlots = 14;

  /// The default planning window, in days.
  static const int defaultWindowDays = 7;

  /// A notification scheduled this close to "now" is not worth arming: Android
  /// would fire it immediately, which reads as a duplicate.
  static const Duration minimumLead = Duration(seconds: 45);

  /// The deterministic id for a prayer in a given day slot.
  static int notificationId(Prayer prayer, int slot) {
    final index = Prayer.all.indexOf(prayer);

    return notificationIdBase + (index * 100) + slot;
  }

  /// Every id the planner may ever use, for the cancel-then-schedule pass.
  static List<int> allNotificationIds({int slots = idSlots}) => [
        for (final prayer in Prayer.all)
          for (var slot = 0; slot < slots; slot++) notificationId(prayer, slot),
      ];

  /// The notifications to hold on the device.
  ///
  /// [days] must start at today and be in ascending order. [rideActive] suppresses
  /// the azan sound unless the user allowed it during a ride.
  List<PlannedPrayerReminder> plan({
    required List<PrayerDay> days,
    required IslamicFeatureSettings settings,
    required DateTime nowUtc,
    bool rideActive = false,
    int windowDays = defaultWindowDays,
  }) {
    if (settings.hidden || !settings.azanRemindersEnabled) return const [];

    final now = nowUtc.toUtc();
    final earliest = now.add(minimumLead);
    final reminders = <PlannedPrayerReminder>[];

    final window = days.take(windowDays).toList();

    for (var slot = 0; slot < window.length; slot++) {
      final day = window[slot];

      for (final prayer in Prayer.obligatory) {
        if (!settings.wantsReminder(prayer)) continue;

        final entry = day.time(prayer);

        if (entry == null) continue;

        final fireAt = entry.instantUtc.subtract(Duration(minutes: settings.reminderLeadMinutes));

        // Already past (or too close to arm): the device cannot notify about a
        // moment that has gone.
        if (!fireAt.isAfter(earliest)) continue;

        reminders.add(
          PlannedPrayerReminder(
            id: notificationId(prayer, slot),
            prayer: prayer,
            fireAtUtc: fireAt,
            prayerWallClock: entry.wallClock,
            date: day.date,
            leadMinutes: settings.reminderLeadMinutes,
            sound: settings.soundFor(rideActive: rideActive),
          ),
        );
      }
    }

    reminders.sort((a, b) => a.fireAtUtc.compareTo(b.fireAtUtc));

    return reminders;
  }
}
