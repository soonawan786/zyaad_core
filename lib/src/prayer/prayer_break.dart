/// A running driver prayer break, as the API describes it.
///
/// The countdown is computed from [endsAtUtc] against the device clock rather than
/// polled from the server, so the timer keeps ticking when the driver drives into a
/// dead spot. The server is still the authority on when the break actually ends —
/// its `prayer:end-breaks` command returns the driver to dispatch — so this is for
/// display only.
///
/// It lives in the shared package rather than in the driver app because it is pure
/// arithmetic with no plugin or platform dependency, which is what makes it
/// testable without a device.
class PrayerBreak {
  const PrayerBreak({
    required this.id,
    required this.startedAtUtc,
    required this.endsAtUtc,
    required this.durationMinutes,
  });

  final String id;
  final DateTime startedAtUtc;
  final DateTime endsAtUtc;
  final int durationMinutes;

  static PrayerBreak? fromApi(Object? raw) {
    if (raw is! Map) return null;

    final id = raw['id'];
    final endsAt = raw['ends_at'];

    if (id is! String || endsAt is! String) return null;

    final DateTime ends;
    final DateTime started;

    try {
      ends = DateTime.parse(endsAt).toUtc();
      started = raw['started_at'] is String
          ? DateTime.parse(raw['started_at'] as String).toUtc()
          : ends.subtract(Duration(minutes: prayerBreakInt(raw['duration_minutes'], 0)));
    } on FormatException {
      return null;
    }

    return PrayerBreak(
      id: id,
      startedAtUtc: started,
      endsAtUtc: ends,
      durationMinutes: prayerBreakInt(raw['duration_minutes'], 0),
    );
  }

  Duration remaining(DateTime nowUtc) {
    final left = endsAtUtc.difference(nowUtc.toUtc());

    return left.isNegative ? Duration.zero : left;
  }

  /// Whole minutes, rounded up, so "1 minute left" never reads 0.
  int remainingMinutes(DateTime nowUtc) => (remaining(nowUtc).inSeconds / 60).ceil();

  bool isFinishedAt(DateTime nowUtc) => !endsAtUtc.isAfter(nowUtc.toUtc());

  /// 0 at the start, 1 at the end — for the progress ring.
  double progressAt(DateTime nowUtc) {
    final total = endsAtUtc.difference(startedAtUtc).inSeconds;

    if (total <= 0) return 1;

    final elapsed = nowUtc.toUtc().difference(startedAtUtc).inSeconds;

    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// `MM:SS`, for the button.
  String countdownLabel(DateTime nowUtc) {
    final left = remaining(nowUtc);
    final minutes = left.inMinutes.toString().padLeft(2, '0');
    final seconds = left.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }
}

/// How many breaks the driver has left today, and the window the server allows.
class PrayerBreakAllowance {
  const PrayerBreakAllowance({
    this.usedToday = 0,
    this.remainingToday = 0,
    this.minMinutes = 5,
    this.maxMinutes = 30,
    this.dailyLimit = 3,
  });

  final int usedToday;
  final int remainingToday;
  final int minMinutes;
  final int maxMinutes;
  final int dailyLimit;

  bool get canStart => remainingToday > 0;

  static PrayerBreakAllowance fromApi(Map<String, dynamic> data) {
    final limits = data['limits'] is Map
        ? Map<String, dynamic>.from(data['limits'] as Map)
        : const <String, dynamic>{};

    return PrayerBreakAllowance(
      usedToday: prayerBreakInt(data['used_today'], 0),
      remainingToday: prayerBreakInt(data['remaining_today'], 0),
      minMinutes: prayerBreakInt(limits['min_minutes'], 5),
      maxMinutes: prayerBreakInt(limits['max_minutes'], 30),
      dailyLimit: prayerBreakInt(limits['daily_limit'], 3),
    );
  }

  /// The durations the picker offers: the configured window in five minute steps,
  /// always including the maximum.
  List<int> get durationOptions {
    final options = <int>[];

    for (var minutes = minMinutes; minutes <= maxMinutes; minutes += 5) {
      options.add(minutes);
    }

    if (!options.contains(maxMinutes)) options.add(maxMinutes);

    return options;
  }

  /// The server refuses anything outside the window, so clamping here means the app
  /// never sends a value that is guaranteed to be rejected.
  int clampMinutes(int requested) => requested.clamp(minMinutes, maxMinutes);
}

/// Exposed so the parser above and the tests read numbers the same way.
int prayerBreakInt(Object? value, int fallback) => value is num ? value.toInt() : fallback;
