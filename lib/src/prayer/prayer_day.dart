import 'prayer.dart';
import 'prayer_time.dart';

/// The next obligatory prayer, with the countdown.
class NextPrayer {
  const NextPrayer({
    required this.prayer,
    required this.instantUtc,
    required this.wallClock,
    required this.date,
    required this.remaining,
    required this.tomorrow,
  });

  final Prayer prayer;
  final DateTime instantUtc;
  final String wallClock;

  /// `YYYY-MM-DD` in the city's timezone.
  final String date;

  final Duration remaining;

  /// True when the answer rolled over into the next day's Fajr.
  final bool tomorrow;

  int get remainingMinutes => (remaining.inSeconds / 60).ceil();

  /// `H:MM:SS` / `MM:SS` for the countdown, never negative.
  String get countdown {
    final total = remaining.isNegative ? Duration.zero : remaining;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = total.inSeconds.remainder(60).toString().padLeft(2, '0');

    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

/// Sehri and iftar, present only inside a confirmed Ramadan period.
class RamadanWindow {
  const RamadanWindow({
    required this.name,
    required this.hijriYear,
    required this.sehriEndsAtUtc,
    required this.sehriEndsWallClock,
    required this.iftarAtUtc,
    required this.iftarWallClock,
    this.startsOn,
    this.endsOn,
  });

  final String name;
  final int hijriYear;
  final DateTime sehriEndsAtUtc;
  final String sehriEndsWallClock;
  final DateTime iftarAtUtc;
  final String iftarWallClock;
  final String? startsOn;
  final String? endsOn;

  static RamadanWindow? fromApi(Object? raw) {
    if (raw is! Map) return null;

    final sehriAt = raw['sehri_ends_at'];
    final iftarAt = raw['iftar_at'];

    if (sehriAt is! String || iftarAt is! String) return null;

    final DateTime sehri;
    final DateTime iftar;

    try {
      sehri = DateTime.parse(sehriAt).toUtc();
      iftar = DateTime.parse(iftarAt).toUtc();
    } on FormatException {
      return null;
    }

    final year = raw['hijri_year'];

    return RamadanWindow(
      name: raw['name'] is String ? raw['name'] as String : 'Ramadan',
      hijriYear: year is num ? year.toInt() : 0,
      sehriEndsAtUtc: sehri,
      sehriEndsWallClock: raw['sehri_ends_time'] is String ? raw['sehri_ends_time'] as String : '',
      iftarAtUtc: iftar,
      iftarWallClock: raw['iftar_time'] is String ? raw['iftar_time'] as String : '',
      startsOn: raw['starts_on'] is String ? raw['starts_on'] as String : null,
      endsOn: raw['ends_on'] is String ? raw['ends_on'] as String : null,
    );
  }
}

/// One city's times for one local day.
class PrayerDay {
  const PrayerDay({
    required this.date,
    required this.timezone,
    required this.times,
    this.ramadan,
  });

  /// `YYYY-MM-DD` in the city's timezone.
  final String date;

  /// The city's IANA timezone name, e.g. `Asia/Karachi`.
  final String timezone;

  /// Keyed by prayer. Sunrise is present; not every payload carries every prayer.
  final Map<Prayer, PrayerTime> times;

  final RamadanWindow? ramadan;

  bool get isEmpty => times.isEmpty;

  PrayerTime? time(Prayer prayer) => times[prayer];

  /// Fajr → Isha, skipping anything the payload omitted.
  List<PrayerTime> get ordered => [
        for (final prayer in Prayer.all)
          if (times[prayer] != null) times[prayer]!,
      ];

  /// Parses the `data` object of `GET /api/v1/prayer-times`.
  static PrayerDay fromApi(Map<String, dynamic> data) {
    final rawTimes = data['times'];
    final times = <Prayer, PrayerTime>{};

    if (rawTimes is Map) {
      for (final prayer in Prayer.all) {
        final parsed = PrayerTime.fromApi(prayer, rawTimes[prayer.key]);

        if (parsed != null) times[prayer] = parsed;
      }
    }

    return PrayerDay(
      date: data['date'] is String ? data['date'] as String : '',
      timezone: data['timezone'] is String ? data['timezone'] as String : 'UTC',
      times: times,
      ramadan: RamadanWindow.fromApi(data['ramadan']),
    );
  }

  /// The next obligatory prayer strictly after [nowUtc].
  ///
  /// Sunrise is skipped on purpose. When every prayer of this day has passed and
  /// [tomorrow] was supplied, the answer is tomorrow's Fajr.
  NextPrayer? nextAfter(DateTime nowUtc, {PrayerDay? tomorrow}) {
    final now = nowUtc.toUtc();

    for (final prayer in Prayer.obligatory) {
      final entry = times[prayer];

      if (entry != null && entry.instantUtc.isAfter(now)) {
        return _next(entry, now, tomorrow: false);
      }
    }

    final fajr = tomorrow?.time(Prayer.fajr);

    if (tomorrow == null || fajr == null) return null;

    return _next(fajr, now, tomorrow: true, dateOverride: tomorrow.date);
  }

  NextPrayer _next(
    PrayerTime entry,
    DateTime now, {
    required bool tomorrow,
    String? dateOverride,
  }) {
    return NextPrayer(
      prayer: entry.prayer,
      instantUtc: entry.instantUtc,
      wallClock: entry.wallClock,
      date: dateOverride ?? date,
      remaining: entry.instantUtc.difference(now),
      tomorrow: tomorrow,
    );
  }

  /// The next prayer across a window of days, which is what the home card and the
  /// reminder planner both need. [days] must be in ascending date order.
  static NextPrayer? nextAcross(List<PrayerDay> days, DateTime nowUtc) {
    for (var i = 0; i < days.length; i++) {
      final next = days[i].nextAfter(
        nowUtc,
        tomorrow: i + 1 < days.length ? days[i + 1] : null,
      );

      if (next != null) return next;
    }

    return null;
  }
}
