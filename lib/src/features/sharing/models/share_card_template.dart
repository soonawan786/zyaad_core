import 'package:flutter/widgets.dart';

/// The visual treatments offered.
///
/// Three rather than one so a card can be matched to where it is going: a feed
/// post is usually read in daylight on a white timeline, a Story is read on a
/// bright screen against a dark UI. Each is a full palette, not a colour tweak, so
/// the templates stay legible rather than merely different.
enum ShareCardTemplate {
  /// Warm ivory ground, deep green text, a single gold rule. Reads as a printed
  /// Mushaf page and is the safest default for a feed.
  classic,

  /// Deep green ground with gold and ivory text. For Stories and Status, where a
  /// light card looks like a screenshot of a broken page.
  night,

  /// White ground, hairline rules, no ornament. For a card that will sit next to
  /// other content without competing with it.
  minimal;

  String get label => switch (this) {
        ShareCardTemplate.classic => 'Classic',
        ShareCardTemplate.night => 'Night',
        ShareCardTemplate.minimal => 'Minimal',
      };

  ShareCardPalette get palette => switch (this) {
        ShareCardTemplate.classic => const ShareCardPalette(
            background: Color(0xFFFBF7EF),
            backgroundAccent: Color(0xFFF3EADA),
            arabic: Color(0xFF123B2E),
            translation: Color(0xFF3C4A44),
            reference: Color(0xFF6B7A72),
            accent: Color(0xFFC9A227),
            divider: Color(0xFFE2D6BF),
            brand: Color(0xFF123B2E),
          ),
        ShareCardTemplate.night => const ShareCardPalette(
            background: Color(0xFF0E2A22),
            backgroundAccent: Color(0xFF143A2F),
            arabic: Color(0xFFFDF8EC),
            translation: Color(0xFFD8E3DC),
            reference: Color(0xFF9FB3A8),
            accent: Color(0xFFD9B44A),
            divider: Color(0xFF25523F),
            brand: Color(0xFFD9B44A),
          ),
        ShareCardTemplate.minimal => const ShareCardPalette(
            background: Color(0xFFFFFFFF),
            backgroundAccent: Color(0xFFF7F7F7),
            arabic: Color(0xFF14181C),
            translation: Color(0xFF42484D),
            reference: Color(0xFF8A9199),
            accent: Color(0xFF123B2E),
            divider: Color(0xFFE6E8EA),
            brand: Color(0xFF123B2E),
          ),
      };
}

/// The colours one template uses.
///
/// A plain value object rather than a `ThemeData`: the card must render
/// identically inside the app's theme, inside a bare `RepaintBoundary` with no
/// `MaterialApp` above it (which is how the renderer captures it), and in a widget
/// test. Inheriting the host theme would make the exported PNG depend on which app
/// exported it.
@immutable
class ShareCardPalette {
  const ShareCardPalette({
    required this.background,
    required this.backgroundAccent,
    required this.arabic,
    required this.translation,
    required this.reference,
    required this.accent,
    required this.divider,
    required this.brand,
  });

  final Color background;
  final Color backgroundAccent;

  /// The Arabic itself — the highest-contrast colour in the palette.
  final Color arabic;

  final Color translation;

  /// The reference and the attribution. Readable, deliberately quieter than the
  /// verse but never below a legible contrast.
  final Color reference;

  final Color accent;
  final Color divider;

  /// The app wordmark.
  final Color brand;

  bool get isDark => background.computeLuminance() < 0.5;
}
