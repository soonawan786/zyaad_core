/// SharedPreferences keys for the prayer feature.
///
/// They live in the package rather than in each app's `AppConstants` so the cached
/// window and the user's switches survive a change in either app, and so a bug in
/// one app cannot read the other's half-written state.
class PrayerStorageKeys {
  const PrayerStorageKeys._();

  /// The cached window: `{city_id, cached_at, days: [...]}`.
  static const String cache = 'prayer_cache_v1';

  /// The user's switches, including the device-only sound flags.
  static const String settings = 'prayer_settings_v1';

  /// The device timezone offset last seen, used to detect a timezone change and
  /// reschedule.
  static const String lastTimezoneOffset = 'prayer_last_tz_offset_v1';

  /// The city the cached window belongs to.
  static const String cityId = 'prayer_city_id_v1';
}
