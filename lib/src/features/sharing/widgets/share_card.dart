import 'package:flutter/widgets.dart';

import '../models/share_card_content.dart';
import '../models/share_card_format.dart';
import '../models/share_card_template.dart';

/// The Arabic face the card asks for.
///
/// Noto Naskh Arabic is the bundled family (see assets/font/README.md). Until the
/// .ttf is added the platform's own Arabic face is used via [arabicFontFallback],
/// which still shapes and joins correctly — it is a different typeface, not broken
/// text.
const String arabicFontFamily = 'NotoNaskhArabic';

/// Tried in order when [arabicFontFamily] is not bundled.
///
/// 'Geeza Pro' is iOS's Naskh, 'Noto Naskh Arabic' is Android's. Both are Naskh
/// rather than the Kufic-ish default, so the fallback is typographically closer
/// than the generic sans face Flutter would otherwise pick.
const List<String> arabicFontFallback = <String>[
  'Noto Naskh Arabic',
  'Geeza Pro',
  'Noto Sans Arabic',
  'Arial',
];

/// A shareable card: one ayah or hadith, its translation, and its citation.
///
/// Pure presentation — no I/O, no plugin, no `MaterialApp` needed above it. That
/// matters because the renderer mounts this widget inside a bare
/// `RepaintBoundary` with no app around it, and the same widget is used for the
/// on-screen preview.
///
/// **Text is never truncated.** Every block wraps at a bounded width and is then
/// scaled down to fit its region ([_FittedBlock]). A long ayah such as 2:255
/// therefore renders smaller than 112:1 rather than losing its last line — for
/// scripture, smaller is acceptable and clipped is not.
///
/// **The output is deterministic.** [TextScaler.noScaling] is forced, so a user
/// who has enlarged their system font cannot change the exported image, and a
/// capture taken on a device with a large text setting is byte-identical to one
/// taken without.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.content,
    this.format = ShareCardFormat.portrait,
    this.template = ShareCardTemplate.classic,
    this.leadingLanguage = ShareCardTranslationLanguage.urdu,
    this.showBrandMark = true,
    this.brandName = 'Zyaad',
    this.logo,
  });

  final ShareCardContent content;
  final ShareCardFormat format;
  final ShareCardTemplate template;

  /// Which translation is shown first. The other is still shown when present.
  final ShareCardTranslationLanguage leadingLanguage;

  final bool showBrandMark;
  final String brandName;

  /// An optional logo, supplied by the host app so this package does not have to
  /// ship one. Nothing is drawn in its place when null — a placeholder mark would
  /// be a fabricated brand.
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    final palette = template.palette;
    final scale = format.isTall ? 1.12 : 1.0;

    /*
     * `maybeOf`, not `of`: the card is also mounted inside a bare RepaintBoundary
     * with no app above it, where there is no MediaQuery and `of` would throw. The
     * default data is enough, because the only thing taken from it is replaced
     * immediately below.
     */
    final media = MediaQuery.maybeOf(context) ?? const MediaQueryData();

    return Directionality(
      // The card is Arabic-first, so the whole layout is RTL. Each block sets its
      // own direction for the language it contains.
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: media.copyWith(
          textScaler: TextScaler.noScaling,
          boldText: false,
        ),
        child: SizedBox(
          width: format.logicalWidth,
          height: format.logicalHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.background,
              // A very slight vertical wash gives the flat ground some depth
              // without a gradient that would band in an 8-bit PNG.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.background, palette.backgroundAccent],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24 * scale,
                20 * scale,
                24 * scale,
                20 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBrandMark) _BrandMark(
                    name: brandName,
                    palette: palette,
                    scale: scale,
                    logo: logo,
                  ),
                  _Rule(palette: palette, scale: scale),
                  Expanded(
                    flex: 52,
                    child: _FittedBlock(
                      child: _ArabicText(
                        text: content.arabicText,
                        palette: palette,
                        scale: scale,
                        format: format,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 34,
                    child: _TranslationBlock(
                      content: content,
                      palette: palette,
                      scale: scale,
                      leadingLanguage: leadingLanguage,
                    ),
                  ),
                  _Rule(palette: palette, scale: scale),
                  _AttributionBlock(
                    content: content,
                    palette: palette,
                    scale: scale,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a child at a bounded width, then scales it down to fit the height.
///
/// This is the mechanism behind "never truncated". A `Text` with `maxLines` and
/// `overflow: ellipsis` would silently drop the end of a long ayah; a bare
/// `FittedBox` would lay the text out on one unbounded line and shrink it to
/// illegibility. Constraining the width first lets it wrap naturally, and the
/// `FittedBox` only intervenes when the wrapped block is taller than the region —
/// so a short ayah keeps its full size and a long one shrinks just enough.
class _FittedBlock extends StatelessWidget {
  const _FittedBlock({required this.child, this.alignment = Alignment.center});

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: alignment,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 320,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// The Arabic, right-to-left and centred.
///
/// No `maxLines` and no overflow handling on purpose: the block is sized by
/// [_FittedBlock] instead, so the text is always complete.
class _ArabicText extends StatelessWidget {
  const _ArabicText({
    required this.text,
    required this.palette,
    required this.scale,
    required this.format,
  });

  final String text;
  final ShareCardPalette palette;
  final double scale;
  final ShareCardFormat format;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10 * scale),
      child: Text(
        text,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        softWrap: true,
        style: TextStyle(
          fontFamily: arabicFontFamily,
          fontFamilyFallback: arabicFontFallback,
          fontSize: (format.isTall ? 30 : 26) * scale,
          // Generous leading: Naskh diacritics sit high and low and collide at
          // normal line height.
          height: 2.0,
          color: palette.arabic,
          fontWeight: FontWeight.w400,
          // Explicit, because a bare RepaintBoundary has no inherited style and
          // the system default would vary by platform.
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// A hairline accent rule.
class _Rule extends StatelessWidget {
  const _Rule({required this.palette, required this.scale});

  final ShareCardPalette palette;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * scale),
      child: SizedBox(
        height: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(color: palette.divider),
        ),
      ),
    );
  }
}

/// The translation, leading with the reader's language and showing the other
/// beneath it when the API sent one.
///
/// A card with no translation at all shows the Arabic alone — the block collapses
/// to nothing rather than reserving space or printing "translation unavailable".
class _TranslationBlock extends StatelessWidget {
  const _TranslationBlock({
    required this.content,
    required this.palette,
    required this.scale,
    required this.leadingLanguage,
  });

  final ShareCardContent content;
  final ShareCardPalette palette;
  final double scale;
  final ShareCardTranslationLanguage leadingLanguage;

  @override
  Widget build(BuildContext context) {
    if (content.hasNoTranslation) {
      return const SizedBox.shrink();
    }

    final leading = content.translationFor(leadingLanguage);
    final secondary = content.translationFor(
      leadingLanguage == ShareCardTranslationLanguage.urdu
          ? ShareCardTranslationLanguage.english
          : ShareCardTranslationLanguage.urdu,
    );

    return _FittedBlock(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null)
            _TranslationLine(
              text: leading,
              palette: palette,
              scale: scale,
              isPrimary: true,
              isRtl: leadingLanguage == ShareCardTranslationLanguage.urdu,
            ),
          if (secondary != null)
            _TranslationLine(
              text: secondary,
              palette: palette,
              scale: scale,
              isPrimary: false,
              isRtl: leadingLanguage != ShareCardTranslationLanguage.urdu,
            ),
        ],
      ),
    );
  }
}

/// One translation line.
///
/// Direction is per-line, not per-card: a card leading in Urdu and trailing in
/// English is the normal mixed-language case and each line has to run the right
/// way on its own.
class _TranslationLine extends StatelessWidget {
  const _TranslationLine({
    required this.text,
    required this.palette,
    required this.scale,
    required this.isPrimary,
    required this.isRtl,
  });

  final String text;
  final ShareCardPalette palette;
  final double scale;
  final bool isPrimary;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3 * scale),
      child: Text(
        text,
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: TextAlign.center,
        softWrap: true,
        style: TextStyle(
          fontFamily: isRtl ? arabicFontFamily : null,
          fontFamilyFallback: isRtl ? arabicFontFallback : null,
          fontSize: (isPrimary ? 13.5 : 11) * scale,
          // Urdu needs the same generous leading as the Arabic; Latin does not.
          height: isRtl ? 1.9 : 1.45,
          color: palette.translation,
          fontWeight: isPrimary ? FontWeight.w500 : FontWeight.w400,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// The citation: the reference, the source, and the grade or licence when the API
/// sent them.
///
/// The reference sits on a line of its own, reproduced character-for-character.
/// The grade and the licence are separate API fields and are shown as their own
/// tokens rather than appended to the reference, so nothing about the citation
/// string itself is altered by presentation.
///
/// `sourceUrl` is deliberately not printed: a URL in a PNG is not actionable, and
/// the source *name* is what the attribution requirement needs. The value stays on
/// the model for callers that want to link it in-app.
class _AttributionBlock extends StatelessWidget {
  const _AttributionBlock({
    required this.content,
    required this.palette,
    required this.scale,
  });

  final ShareCardContent content;
  final ShareCardPalette palette;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (content.hadithGrade != null) content.hadithGrade!,
      if (content.sourceLicense != null) content.sourceLicense!,
    ];

    return _FittedBlock(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            content.reference,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontSize: 12 * scale,
              height: 1.35,
              color: palette.arabic,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            content.sourceName,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontSize: 10 * scale,
              height: 1.3,
              color: palette.reference,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          if (meta.isNotEmpty) ...[
            SizedBox(height: 1 * scale),
            Text(
              meta.join(' · '),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontSize: 8.5 * scale,
                height: 1.3,
                color: palette.reference,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The wordmark, and the app's own logo when it supplied one.
///
/// Nothing is drawn when [logo] is null. A placeholder would be a fabricated brand
/// mark, and this package has no logo of its own to ship.
class _BrandMark extends StatelessWidget {
  const _BrandMark({
    required this.name,
    required this.palette,
    required this.scale,
    this.logo,
  });

  final String name;
  final ShareCardPalette palette;
  final double scale;
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (logo != null) ...[
            SizedBox(height: 18 * scale, child: logo!),
            SizedBox(width: 6 * scale),
          ],
          Text(
            name,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 11 * scale,
              height: 1.2,
              color: palette.brand,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
