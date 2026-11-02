import 'dart:async';
import 'dart:convert';

import 'package:app_settings/app_settings.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'api/prayer_api.dart';
import 'notifications/prayer_notification_channel.dart';
import 'notifications/prayer_notification_scheduler.dart';
import 'prayer/daily_content.dart';
import 'prayer/islamic_feature_settings.dart';
import 'prayer/prayer.dart';
import 'prayer/prayer_day.dart';
import 'prayer/prayer_notification_planner.dart';
import 'prayer_messages.dart';
import 'prayer_storage_keys.dart';

/// Everything the Islamic-feature screens read and write, shared by both apps.
///
/// The host app supplies the [PrayerServiceInterface] (its own HTTP client and base
/// URL) and the notification [channel]; everything else — caching, the schedule,
/// the settings sync — is identical in the rider app and the driver app, which is
/// why it lives here.
///
/// Two responsibilities worth calling out:
///
///  * **Offline first.** The next seven days are fetched once per day, cached in
///    SharedPreferences, and reused. The home card, the Qibla screen and the
///    reminder schedule all work with no network — which is the whole point of
///    scheduling locally instead of using a server push.
///  * **The master switch is respected everywhere.** [hidden] short-circuits the
///    card, the Qibla screen, the settings rows and the reminder schedule, so the
///    app has one answer for "does this user want any of this?".
class PrayerController extends GetxController {
  PrayerController({
    required this.prayerServiceInterface,
    required this.sharedPreferences,
    required this.scheduler,
    required this.channel,
  });

  final PrayerServiceInterface prayerServiceInterface;
  final SharedPreferences sharedPreferences;
  final PrayerNotificationScheduler scheduler;
  final PrayerNotificationChannel channel;

  /// The cached window, today first.
  List<PrayerDay> days = [];

  IslamicFeatureSettings settings = const IslamicFeatureSettings();

  /// The city the cached window belongs to.
  String? cityId;

  bool isLoading = false;
  bool remindersPermissionGranted = true;
  bool exactAlarmsGranted = true;
  int scheduledReminders = 0;
  DateTime? nextReminderAt;

  /// Today's ayah and hadith, or null before the first load.
  ///
  /// Separate from [days] because it is fetched on a different schedule: the prayer
  /// window is needed on app start, the daily content only when its card is shown.
  DailyContentDay? dailyContent;

  bool isLoadingDailyContent = false;

  Timer? _ticker;

  /// True when the user has switched the whole section off.
  bool get hidden => settings.hidden;

  bool get hasDailyContent => dailyContent?.isNotEmpty ?? false;

  bool get hasData => days.isNotEmpty;

  PrayerDay? get today => days.isEmpty ? null : days.first;

  RamadanWindow? get ramadan => today?.ramadan;

  /// The next prayer, recomputed against the current clock rather than trusting a
  /// value fetched minutes ago.
  NextPrayer? get nextPrayer {
    if (days.isEmpty) return null;

    return PrayerDay.nextAcross(days, DateTime.now().toUtc());
  }

  @override
  void onInit() {
    super.onInit();
    _restoreLocalSettings();
    _startTicker();
  }

  @override
  void onClose() {
    _ticker?.cancel();
    super.onClose();
  }

  /// Recomputes the countdown every second.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (days.isNotEmpty) update();
    });
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  void _restoreLocalSettings() {
    final raw = sharedPreferences.getString(PrayerStorageKeys.settings);

    if (raw == null || raw.isEmpty) return;

    try {
      settings = IslamicFeatureSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A corrupted preference must not brick the app; fall back to defaults.
      settings = const IslamicFeatureSettings();
    }
  }

  Future<void> _persistSettings() async {
    await sharedPreferences.setString(
      PrayerStorageKeys.settings,
      jsonEncode(settings.toJson()),
    );
  }

  /// Applies a settings change locally, persists it, tells the server, and rebuilds
  /// the reminder schedule.
  ///
  /// The local write happens first so the UI is instant and works offline. A failed
  /// sync is reported but does not roll the change back, because the user's intent
  /// is not the server's to refuse.
  Future<void> updateSettings(IslamicFeatureSettings updated, {bool sync = true}) async {
    settings = updated;
    await _persistSettings();
    update();

    if (sync) {
      final response = await prayerServiceInterface.updatePrayerSettings(updated.toApiJson());

      if (response.statusCode != 200) {
        showPrayerMessage(prayerRefusalMessage(response.body), isError: true);
      } else if (response.body is Map && response.body['data'] is Map) {
        // Trust the server's echo for the fields it owns, keep our local ones.
        settings = IslamicFeatureSettings.fromApi(
          Map<String, dynamic>.from(response.body['data'] as Map),
          local: settings,
        );
        await _persistSettings();
      }
    }

    await rescheduleNotifications();
  }

  Future<void> setIslamicFeaturesEnabled(bool enabled) =>
      updateSettings(settings.copyWith(islamicFeaturesEnabled: enabled));

  Future<void> setAzanRemindersEnabled(bool enabled) =>
      updateSettings(settings.copyWith(azanRemindersEnabled: enabled));

  Future<void> setPrayerReminder(Prayer prayer, bool enabled) =>
      updateSettings(settings.withReminder(prayer, enabled));

  Future<void> setCalculationMethod(CalculationMethodOption? method) => updateSettings(
        method == null
            ? settings.copyWith(clearCalculationMethod: true)
            : settings.copyWith(calculationMethod: method),
      );

  Future<void> setAsrMethod(AsrMethodOption? method) => updateSettings(
        method == null
            ? settings.copyWith(clearAsrMethod: true)
            : settings.copyWith(asrMethod: method),
      );

  Future<void> setReminderLeadMinutes(int minutes) =>
      updateSettings(settings.copyWith(reminderLeadMinutes: minutes));

  Future<void> setAzanSoundEnabled(bool enabled) =>
      updateSettings(settings.copyWith(azanSoundEnabled: enabled));

  Future<void> setAzanSoundDuringRide(bool enabled) =>
      updateSettings(settings.copyWith(azanSoundDuringRide: enabled));

  // ---------------------------------------------------------------------------
  // Android permissions and battery restrictions
  // ---------------------------------------------------------------------------

  /// Asks for notification permission, then re-arms the schedule (a schedule built
  /// before the permission was granted would never have been shown).
  Future<bool> requestNotificationPermission() async {
    await initializeNotifications();

    final granted = await channel.requestPermission();
    remindersPermissionGranted = granted;
    update();

    if (granted) await rescheduleNotifications();

    return granted;
  }

  Future<bool> requestExactAlarmPermission() async {
    final granted = await channel.requestExactAlarmPermission();
    exactAlarmsGranted = granted;
    update();

    // Reminders armed inexactly are re-armed exactly once the user allows it.
    await rescheduleNotifications();

    return granted;
  }

  /// Prepares the timezone database and the notification channels. Idempotent, and
  /// safe to call before any permission prompt or schedule rebuild.
  Future<void> initializeNotifications() => channel.initialize();

  /// Opens the OS battery-optimisation screen, which is the other half of "why do
  /// my reminders not arrive" on Xiaomi/Oppo/Vivo.
  Future<void> openBatterySettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
    } catch (_) {
      // Not every OEM exposes this screen; the in-app guide already names the path.
    }
  }

  // ---------------------------------------------------------------------------
  // Loading the window (offline first)
  // ---------------------------------------------------------------------------

  /// Loads the next seven days for [cityId].
  ///
  /// A fresh cache for the same city is used as-is (no network at all), which is
  /// what makes the card, the Qibla screen and the reminder schedule work on a
  /// plane. A stale or missing cache is replaced.
  Future<void> load({String? cityId, bool force = false}) async {
    /*
     * The city is optional, and usually absent.
     *
     * The apps hold a zone rather than a city and send it as a `zoneId` header; the
     * backend resolves the city from `zones.city_id` (App\Domain\Prayer\
     * PrayerCityContext). Requiring a city here is what made this method
     * uncallable and the whole feature unreachable — nothing in either app has one.
     *
     * The local cache still works without a city: it is keyed on whatever the
     * controller was last given, which is nothing on a fresh install.
     */
    if (cityId != null) {
      this.cityId = cityId;
      await sharedPreferences.setString(PrayerStorageKeys.cityId, cityId);
    }

    final cacheKey = this.cityId ?? '';

    // Timezone database + notification channels, before anything is scheduled.
    await initializeNotifications();

    final cached = _readCache(cacheKey);

    if (cached.isNotEmpty) {
      days = cached;
      update();

      if (!force && _cacheIsFresh(cached)) {
        await rescheduleNotifications();
        return;
      }
    }

    await _fetchWindow(this.cityId, cacheKey);
  }

  bool _cacheIsFresh(List<PrayerDay> cached) =>
      cached.first.date == _todayIn(cached.first.timezone);

  Future<void> _fetchWindow(String? cityId, String cacheKey) async {
    isLoading = true;
    update();

    const windowDays = PrayerNotificationPlanner.defaultWindowDays;
    final collected = <PrayerDay>[];

    // The first request omits the date, so the backend answers for *its* today; the
    // returned timezone then drives the remaining six dates. Guessing the city's
    // today from the device clock would be wrong for a user travelling abroad.
    final firstResponse = await prayerServiceInterface.getPrayerTimes(cityId: cityId);
    final first = _dayFromResponse(firstResponse);

    if (first == null) {
      isLoading = false;
      update();

      return;
    }

    collected.add(first);

    final location = _location(first.timezone);
    final base = tz.TZDateTime(
      location,
      int.parse(first.date.substring(0, 4)),
      int.parse(first.date.substring(5, 7)),
      int.parse(first.date.substring(8, 10)),
    );

    for (var i = 1; i < windowDays; i++) {
      // Constructing the date through the tz database (rather than adding 24h)
      // keeps it correct across a DST change.
      final day = tz.TZDateTime(location, base.year, base.month, base.day + i);
      final dateString = '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';

      final response = await prayerServiceInterface.getPrayerTimes(
        cityId: cityId,
        date: dateString,
      );
      final parsed = _dayFromResponse(response);

      if (parsed != null) collected.add(parsed);
    }

    days = collected;
    _writeCache(cacheKey, collected);
    isLoading = false;
    update();

    await rescheduleNotifications();
  }

  PrayerDay? _dayFromResponse(Response response) {
    if (response.statusCode != 200) {
      showPrayerMessage(prayerRefusalMessage(response.body), isError: true);

      return null;
    }

    final body = response.body;

    if (body is! Map || body['data'] is! Map) return null;

    return PrayerDay.fromApi(Map<String, dynamic>.from(body['data'] as Map));
  }

  // ---------------------------------------------------------------------------
  // Reminders
  // ---------------------------------------------------------------------------

  /// Rebuilds the device's schedule. Safe to call often: it cancels the whole id
  /// space first, so it cannot leave an orphan behind.
  Future<void> rescheduleNotifications({bool rideActive = false}) async {
    if (days.isEmpty) {
      await scheduler.cancelAll();
      scheduledReminders = 0;
      nextReminderAt = null;
      update();

      return;
    }

    final outcome = await scheduler.reschedule(
      days: days,
      settings: settings,
      nowUtc: DateTime.now().toUtc(),
      text: _reminderText,
      rideActive: rideActive,
    );

    scheduledReminders = outcome.scheduled;
    nextReminderAt = outcome.nextFireAtUtc;
    exactAlarmsGranted = outcome.exactAlarmsGranted;
    update();
  }

  ({String title, String body}) _reminderText(PlannedPrayerReminder reminder) {
    final name = reminder.prayer.label(_localeCode);

    return (
      title: '$name · ${reminder.prayerWallClock}',
      body: reminder.leadMinutes > 0
          ? '${reminder.leadMinutes} minutes before'
          : 'Time for prayer',
    );
  }

  /// Loads today's ayah and hadith.
  ///
  /// Deliberately separate from [load]. The prayer window is needed on app start
  /// because the home card and the reminders depend on it; the daily content is only
  /// needed when its card is on screen. Fetching both together would make every
  /// launch pay for content the user may never scroll to.
  ///
  /// **Never throws.** A failure leaves [dailyContent] as it was, so a transient
  /// network error cannot blank a card the user is already reading.
  ///
  /// Re-fetches when the local date has moved on, so a card left open overnight does
  /// not keep showing yesterday's ayah.
  Future<void> loadDailyContent({String? cityId, bool force = false}) async {
    if (isLoadingDailyContent) {
      return;
    }

    if (hidden) {
      // The section is switched off, so there is nothing to show and no reason to
      // spend a request on it.
      dailyContent = null;
      update();

      return;
    }

    if (!force && dailyContent != null && dailyContent!.date == _todayIso) {
      return;
    }

    isLoadingDailyContent = true;
    update();

    try {
      final response = await prayerServiceInterface.getDailyContent(cityId: cityId);

      if (response.statusCode == 200) {
        final body = response.body;
        final parsed = DailyContentDay.fromApiData(
          body is Map ? body['data'] : null,
        );

        if (parsed != null) {
          dailyContent = parsed;
        }
      }
    } catch (_) {
      // Swallowed on purpose: see the doc comment. The card keeps whatever it had.
    } finally {
      isLoadingDailyContent = false;
      update();
    }
  }

  /// The local calendar date, `YYYY-MM-DD`.
  ///
  /// Local rather than UTC: the user sees their own day, and the API's content day
  /// is configured in the same zone (config/prayer.php, `daily_content.timezone`).
  String get _todayIso {
    final now = DateTime.now();

    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String get _localeCode => Get.locale?.languageCode ?? 'en';

  // ---------------------------------------------------------------------------
  // Prayer stop (ride only)
  // ---------------------------------------------------------------------------

  /// Asks the other side for a prayer stop. Either side may ask; the other answers.
  Future<bool> requestPrayerStop(String tripId, {String? reason}) async {
    final response = await prayerServiceInterface.requestPrayerStop(tripId, reason: reason);

    final ok = response.statusCode == 200 || response.statusCode == 201;

    if (!ok) showPrayerMessage(prayerRefusalMessage(response.body), isError: true);

    return ok;
  }

  Future<bool> respondToPrayerStop(String stopId, {required bool accept}) async {
    final response = await prayerServiceInterface.respondToPrayerStop(stopId, accept: accept);

    final ok = response.statusCode == 200;

    if (!ok) showPrayerMessage(prayerRefusalMessage(response.body), isError: true);

    return ok;
  }

  /// The open prayer stop for a trip, if any, and the waiting summary.
  Future<Map<String, dynamic>?> loadPrayerStop(String tripId) async {
    final response = await prayerServiceInterface.getPrayerStop(tripId);

    if (response.statusCode != 200 || response.body is! Map || response.body['data'] is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(response.body['data'] as Map);
  }

  // ---------------------------------------------------------------------------
  // Cache
  // ---------------------------------------------------------------------------

  /// The cached window, but only when it belongs to [cityId]. A user who moves city
  /// must not see the previous city's times.
  List<PrayerDay> _readCache(String cityId) {
    final raw = sharedPreferences.getString(PrayerStorageKeys.cache);

    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      if (decoded['city_id'] != cityId) return const [];

      final entries = decoded['days'];

      if (entries is! List) return const [];

      return [
        for (final entry in entries)
          if (entry is Map) PrayerDay.fromApi(Map<String, dynamic>.from(entry)),
      ].where((day) => !day.isEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  void _writeCache(String cityId, List<PrayerDay> days) {
    sharedPreferences.setString(
      PrayerStorageKeys.cache,
      jsonEncode({
        'city_id': cityId,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
        'days': [for (final day in days) _dayToJson(day)],
      }),
    );
  }

  /// Writes a [PrayerDay] back into the API's own shape, so the cache round-trips
  /// through the same parser the network path uses.
  Map<String, dynamic> _dayToJson(PrayerDay day) => {
        'date': day.date,
        'timezone': day.timezone,
        'times': {
          for (final entry in day.times.values)
            entry.prayer.key: {
              'label': entry.labelFor('en'),
              'time': entry.wallClock,
              'at': entry.instantUtc.toIso8601String(),
              'offset_minutes': entry.offsetMinutes,
            },
        },
        'ramadan': day.ramadan == null
            ? null
            : {
                'name': day.ramadan!.name,
                'hijri_year': day.ramadan!.hijriYear,
                'starts_on': day.ramadan!.startsOn,
                'ends_on': day.ramadan!.endsOn,
                'sehri_ends_at': day.ramadan!.sehriEndsAtUtc.toIso8601String(),
                'sehri_ends_time': day.ramadan!.sehriEndsWallClock,
                'iftar_at': day.ramadan!.iftarAtUtc.toIso8601String(),
                'iftar_time': day.ramadan!.iftarWallClock,
              },
      };

  /// Today's date *in the city*, which is what decides whether the cache is stale.
  String _todayIn(String timezone) {
    final now = tz.TZDateTime.now(_location(timezone));

    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  tz.Location _location(String timezone) {
    try {
      return tz.getLocation(timezone);
    } catch (_) {
      return tz.local;
    }
  }
}



