import '../features/sharing/models/share_card_content.dart';

/// One day of daily content, as `GET /api/v1/daily-content` returns it.
///
/// The API serves **one ayah and one hadith per day**, so both are modelled rather
/// than picking one: which to feature is a product decision, and a model that threw
/// one away would make it for you.
class DailyContentDay {
  const DailyContentDay({
    required this.date,
    required this.items,
    this.fallbackUsed = false,
  });

  /// The day the API assigned, `YYYY-MM-DD`.
  final String date;

  /// Everything the API sent for the day, in its order (ayah, then hadith).
  final List<ShareCardContent> items;

  /// True when the API had nothing scheduled and repeated the most recent content.
  /// Surfaced rather than hidden, so a caller can choose not to feature a repeat.
  final bool fallbackUsed;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  /// The ayah for the day, or null when the API sent none.
  ShareCardContent? get ayah => _firstOfType(ShareCardContentType.ayah);

  /// The hadith for the day, or null when the API sent none.
  ShareCardContent? get hadith => _firstOfType(ShareCardContentType.hadith);

  ShareCardContent? _firstOfType(ShareCardContentType type) {
    for (final item in items) {
      if (item.type == type) {
        return item;
      }
    }

    return null;
  }

  /// Parses the `data` object of a successful response.
  ///
  /// Returns null when the payload is unusable, so a caller can treat "no content"
  /// and "bad content" the same way without a try/catch.
  ///
  /// An individual item that cannot produce a truthful card — no `reference`, no
  /// `source.name` — is **skipped rather than thrown**. One malformed row must not
  /// blank the whole day, and the alternative (surfacing a card with a missing
  /// citation) is the one thing the share feature must never do. The skip is
  /// deliberate and silent here because the API is the only writer and a bad row
  /// is a backend bug, not something a user can act on.
  static DailyContentDay? fromApiData(Object? data) {
    if (data is! Map) {
      return null;
    }

    final rawItems = data['items'];

    if (rawItems is! List) {
      return null;
    }

    final items = <ShareCardContent>[];

    for (final raw in rawItems) {
      if (raw is! Map) {
        continue;
      }

      try {
        items.add(
          ShareCardContent.fromApiItem(Map<String, dynamic>.from(raw)),
        );
      } on ShareCardContentException {
        continue;
      }
    }

    final date = data['date'];

    return DailyContentDay(
      date: date is String ? date : '',
      items: items,
      fallbackUsed: data['fallback_used'] == true,
    );
  }
}
