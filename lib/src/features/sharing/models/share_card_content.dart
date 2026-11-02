/// One ayah or one hadith, exactly as the API described it.
///
/// The card renders *this* and nothing else. There is no default text, no
/// placeholder reference and no generated translation anywhere in the class,
/// because a card is a public quotation of scripture and an invented or
/// mis-attributed one is the single worst output this feature could produce.
///
/// That rule is enforced by construction rather than by discipline:
/// [ShareCardContent.fromApiItem] throws when `arabic_text`, `reference` or the
/// source name is missing or blank, so a card without a citation cannot exist and
/// therefore cannot be shared.
///
/// Fields the API did not send stay null and are simply not rendered — a null
/// [hadithGrade] hides the grade line rather than showing "unknown".
class ShareCardContent {
  const ShareCardContent({
    required this.arabicText,
    required this.reference,
    required this.sourceName,
    required this.type,
    this.translationUr,
    this.translationEn,
    this.hadithGrade,
    this.sourceLicense,
    this.sourceUrl,
    this.date,
    this.isFallback = false,
  });

  /// The Arabic. Never blank.
  final String arabicText;

  /// As the API stated it: "2:255" for an ayah, "Sahih al-Bukhari, Hadith 1" for a
  /// hadith. Reproduced verbatim — never reformatted, never shortened.
  final String reference;

  /// The publisher or collection the text came from. Never blank.
  final String sourceName;

  final ShareCardContentType type;

  final String? translationUr;
  final String? translationEn;

  /// hadith only, and only when the source graded it.
  final String? hadithGrade;

  /// The licence the text is used under, shown verbatim when present.
  final String? sourceLicense;

  /// Only rendered when the API actually sent one. Not synthesised from
  /// [sourceName] — a guessed URL would be a fabricated attribution.
  final String? sourceUrl;

  /// The date the API assigned this content, when it sent one.
  final String? date;

  /// True when the API served this by falling back to a repeat. Surfaced so the
  /// caller can decide not to feature a repeat, rather than hidden.
  final bool isFallback;

  /// Builds from one element of `data.items[]` in `GET /api/v1/daily-content`.
  ///
  /// Throws [ShareCardContentException] when a field that must be present is not.
  /// The caller is expected to catch it and show the error state — never to
  /// substitute a value.
  factory ShareCardContent.fromApiItem(Map<String, dynamic> item) {
    final arabic = _required(item['arabic_text'], 'arabic_text');
    final reference = _required(item['reference'], 'reference');

    final source = item['source'];
    if (source is! Map) {
      throw const ShareCardContentException(
        'source is missing: a card must always carry its attribution.',
      );
    }

    final sourceName = _required(source['name'], 'source.name');

    final translations = item['translations'];
    final map = translations is Map ? translations : const {};

    return ShareCardContent(
      arabicText: arabic,
      reference: reference,
      sourceName: sourceName,
      type: ShareCardContentType.fromApi(item['type']),
      translationUr: _optional(map['ur']),
      translationEn: _optional(map['en']),
      hadithGrade: _optional(item['hadith_grade']),
      sourceLicense: _optional(source['license']),
      // Tolerated when absent: the current payload does not send it yet.
      sourceUrl: _optional(source['url']),
      date: _optional(item['scheduled_date']),
      isFallback: item['is_fallback'] == true,
    );
  }

  static String _required(Object? value, String field) {
    final text = _optional(value);

    if (text == null) {
      throw ShareCardContentException(
        '$field is empty. A card is a quotation: without it there is nothing '
        'truthful to show, and no placeholder may be substituted.',
      );
    }

    return text;
  }

  static String? _optional(Object? value) {
    if (value is! String) {
      return null;
    }

    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  /// The translation to show first for a given language, or null when the API
  /// sent none for it.
  String? translationFor(ShareCardTranslationLanguage language) =>
      switch (language) {
        ShareCardTranslationLanguage.urdu => translationUr,
        ShareCardTranslationLanguage.english => translationEn,
      };

  /// True when neither translation is available, so the card shows Arabic alone
  /// rather than an empty translation block.
  bool get hasNoTranslation => translationUr == null && translationEn == null;

  @override
  String toString() =>
      'ShareCardContent(${type.name}, $reference, $sourceName)';
}

/// Which series an item belongs to.
enum ShareCardContentType {
  ayah,
  hadith;

  static ShareCardContentType fromApi(Object? value) =>
      value == 'hadith' ? ShareCardContentType.hadith : ShareCardContentType.ayah;

  String get label => this == ShareCardContentType.hadith ? 'Hadith' : 'Ayah';
}

/// Which translation the card leads with.
enum ShareCardTranslationLanguage { urdu, english }

/// Thrown when the API payload cannot produce a truthful card.
class ShareCardContentException implements Exception {
  const ShareCardContentException(this.message);

  final String message;

  @override
  String toString() => 'ShareCardContentException: $message';
}
