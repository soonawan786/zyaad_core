import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The slice of the notifications plugin the scheduler needs.
///
/// An interface rather than a direct plugin call, because "the reminder fires at
/// the right minute" and "switching a prayer off removes its notification" are
/// facts that must be assertable in a unit test, not only on a phone at 4am.
abstract class PrayerNotificationChannel {
  /// Prepares the timezone database and the notification channels.
  ///
  /// Deliberately does **not** call `FlutterLocalNotificationsPlugin.initialize`:
  /// the app already initializes the single shared plugin instance in `main.dart`
  /// (`NotificationHelper.initialize`), and calling it a second time would replace
  /// that handler and break the app's existing notification taps. Prayer reminders
  /// are routed from their payload instead (`prayer:<name>:<date>`).
  Future<void> initialize();

  /// Asks for POST_NOTIFICATIONS / iOS notification permission.
  Future<bool> requestPermission();

  /// Sends the user to the "Alarms & reminders" screen on Android 12+.
  Future<bool> requestExactAlarmPermission();

  /// Whether exact alarms are currently allowed. False means reminders are
  /// scheduled inexactly (the OS may delay them by a few minutes).
  Future<bool> canScheduleExactAlarms();

  /// Removes the given notifications, ignoring ids that are not scheduled.
  Future<void> cancel(Iterable<int> ids);

  /// Arms one notification at an absolute instant.
  Future<void> schedule({
    required int id,
    required DateTime fireAtUtc,
    required String timezone,
    required String title,
    required String body,
    required String payload,
    required bool sound,
  });
}

/// The real channel: `flutter_local_notifications` + the `timezone` database.
///
/// It takes the plugin instance rather than creating one, because the app keeps a
/// single `FlutterLocalNotificationsPlugin` in `main.dart` and two instances would
/// fight over the same platform channel — and over which callback receives a tap.
///
/// Two Android channels are registered on purpose. Android bakes the sound into a
/// channel at creation time and it cannot be changed afterwards, so a single
/// channel could not offer "azan sound on for Fajr, silent for the rest" — or
/// honour the rule that a ride silences the azan — without the user having to dig
/// into system settings.
class LocalPrayerNotificationChannel implements PrayerNotificationChannel {
  LocalPrayerNotificationChannel({required FlutterLocalNotificationsPlugin plugin})
      : _plugin = plugin;

  final FlutterLocalNotificationsPlugin _plugin;

  /// Fires with the azan sound (the user switched sound on and no ride is active).
  static const String azanChannelId = 'prayer_azan_v1';

  /// Fires silently: the reminder still appears, it just does not make a noise.
  static const String silentChannelId = 'prayer_silent_v1';

  static const String _azanChannelName = 'Azan reminders';
  static const String _silentChannelName = 'Prayer reminders (silent)';

  bool? _exactAlarmsAllowed;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    // The `timezone` package needs its database before any TZDateTime is built.
    tz_data.initializeTimeZones();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          azanChannelId,
          _azanChannelName,
          description: 'Prayer reminders that play a short azan.',
          importance: Importance.high,
          playSound: true,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          silentChannelId,
          _silentChannelName,
          description: 'Prayer reminders without sound.',
          importance: Importance.high,
          playSound: false,
        ),
      );
    }

    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }

    return false;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return true;

    final granted = await android.requestExactAlarmsPermission() ?? false;
    _exactAlarmsAllowed = granted;

    return granted;
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    if (_exactAlarmsAllowed != null) return _exactAlarmsAllowed!;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Not Android: the platform has no equivalent restriction.
    if (android == null) return _exactAlarmsAllowed = true;

    return _exactAlarmsAllowed = await android.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> cancel(Iterable<int> ids) async {
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }

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
    final location = _resolveLocation(timezone);
    final scheduled = tz.TZDateTime.from(fireAtUtc.toUtc(), location);

    // An exact alarm is only armed when the OS says it is allowed; otherwise the
    // reminder is scheduled inexactly rather than not at all.
    final exact = await canScheduleExactAlarms();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          sound ? azanChannelId : silentChannelId,
          sound ? _azanChannelName : _silentChannelName,
          channelDescription: sound
              ? 'Prayer reminders that play a short azan.'
              : 'Prayer reminders without sound.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: sound,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: sound,
          // `active` respects the ringer switch and Do Not Disturb. We never use
          // `critical`, which would bypass silent mode — an azan must not override
          // a user who has silenced their phone.
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      androidScheduleMode: mode,
      payload: payload,
    );
  }

  /// Resolves an IANA name, falling back to the device zone when the API sends
  /// something the database does not know.
  tz.Location _resolveLocation(String timezone) {
    try {
      return tz.getLocation(timezone);
    } catch (_) {
      return tz.local;
    }
  }
}

