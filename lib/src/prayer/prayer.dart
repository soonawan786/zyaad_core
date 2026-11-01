/// The six timestamps a day produces.
///
/// Sunrise is not a prayer: it is exposed because it bounds Fajr, and it is never
/// a reminder and never a "next prayer".
enum Prayer {
  fajr('fajr', 'Fajr', 'فجر'),
  sunrise('sunrise', 'Sunrise', 'طلوعِ آفتاب'),
  dhuhr('dhuhr', 'Dhuhr', 'ظہر'),
  asr('asr', 'Asr', 'عصر'),
  maghrib('maghrib', 'Maghrib', 'مغرب'),
  isha('isha', 'Isha', 'عشاء');

  const Prayer(this.key, this.englishLabel, this.urduLabel);

  /// The value the API uses.
  final String key;

  final String englishLabel;
  final String urduLabel;

  /// The five prayers, in order. Sunrise is excluded.
  static const List<Prayer> obligatory = [fajr, dhuhr, asr, maghrib, isha];

  static const List<Prayer> all = [fajr, sunrise, dhuhr, asr, maghrib, isha];

  /// The label for a locale, falling back to English.
  ///
  /// The prayer names are domain data, not UI copy, so they live here rather than
  /// in each app's translation file — the name of a prayer does not change with
  /// the screen it is shown on.
  String label(String localeCode) =>
      localeCode.toLowerCase().startsWith('ur') ? urduLabel : englishLabel;

  bool get isRemindable => this != sunrise;

  /// Ramadan is bounded by these two: Sehri ends at Fajr, iftar is Maghrib.
  bool get isRamadanBoundary => this == fajr || this == maghrib;

  static Prayer? tryParse(String? key) {
    if (key == null) return null;

    for (final prayer in all) {
      if (prayer.key == key) return prayer;
    }

    return null;
  }

  static Prayer parse(String key) =>
      tryParse(key) ?? (throw ArgumentError.value(key, 'key', 'Unknown prayer'));
}
