import 'package:zyaad_core/zyaad_core.dart';

/// Builds a [PrayerDay] from the exact JSON shape `GET /api/v1/prayer-times`
/// returns, so the tests exercise the real parser rather than a hand-built object.
///
/// Asia/Karachi is a fixed +05:00 offset (Pakistan has no DST), which is why the
/// fixtures can hard-code it.
PrayerDay dayFixture({
  required String date,
  Map<String, String> times = const {
    'fajr': '04:52',
    'sunrise': '06:13',
    'dhuhr': '12:12',
    'asr': '16:28',
    'maghrib': '18:11',
    'isha': '19:32',
  },
  Object? ramadan,
}) {
  return PrayerDay.fromApi({
    'date': date,
    'timezone': 'Asia/Karachi',
    'method': 'karachi',
    'asr_method': 'hanafi',
    'times': {
      for (final entry in times.entries)
        entry.key: {
          'label': entry.key,
          'time': entry.value,
          'at': '${date}T${entry.value}:00+05:00',
          'offset_minutes': 0,
        },
    },
    'ramadan': ramadan,
  });
}

/// A run of consecutive days starting at [from].
List<PrayerDay> daysFixture({
  required String from,
  int count = 7,
  Map<String, String>? times,
}) {
  final start = DateTime.parse('$from 00:00:00Z');
  final days = <PrayerDay>[];

  for (var i = 0; i < count; i++) {
    final date = start.add(Duration(days: i));
    final label = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    days.add(dayFixture(date: label, times: times ?? const {
      'fajr': '04:52',
      'sunrise': '06:13',
      'dhuhr': '12:12',
      'asr': '16:28',
      'maghrib': '18:11',
      'isha': '19:32',
    }));
  }

  return days;
}

/// The instant a city wall-clock time on a given date corresponds to.
DateTime karachiInstant(String date, String hhmm) =>
    DateTime.parse('${date}T$hhmm:00+05:00').toUtc();
