import 'prayer.dart';

/// One prayer's timestamp for one day.
///
/// [instantUtc] is the absolute moment (what a notification must be scheduled at)
/// and [wallClock] is the time as the city's own clock shows it (`04:52`), which
/// is what a human expects to read. Keeping both is deliberate: a device whose
/// timezone differs from the city's must still be reminded at the right *instant*,
/// while the card still says "Fajr 04:52".
class PrayerTime {
  const PrayerTime({
    required this.prayer,
    required this.wallClock,
    required this.instantUtc,
    this.offsetMinutes = 0,
    this.label,
  });

  final Prayer prayer;

  /// `HH:mm` in the city's timezone.
  final String wallClock;

  /// The absolute instant, in UTC.
  final DateTime instantUtc;

  /// The per-prayer minute offset the admin applied (for display/debugging).
  final int offsetMinutes;

  /// The label the API sent, if any. Falls back to the prayer's English label.
  final String? label;

  String labelFor(String localeCode) => label ?? prayer.label(localeCode);

  /// Parses one entry of the API's `times` map.
  ///
  /// Returns null when the entry is unusable rather than throwing: a single bad
  /// prayer must not blank the whole day.
  static PrayerTime? fromApi(Prayer prayer, Object? raw) {
    if (raw is! Map) return null;

    final at = raw['at'];
    final wallClock = raw['time'];

    if (at is! String || wallClock is! String) return null;

    final DateTime instant;

    try {
      instant = DateTime.parse(at).toUtc();
    } on FormatException {
      return null;
    }

    final offset = raw['offset_minutes'];

    return PrayerTime(
      prayer: prayer,
      wallClock: wallClock,
      instantUtc: instant,
      offsetMinutes: offset is num ? offset.toInt() : 0,
      label: raw['label'] is String ? raw['label'] as String : null,
    );
  }

  @override
  String toString() => '${prayer.key} $wallClock (${instantUtc.toIso8601String()})';
}
