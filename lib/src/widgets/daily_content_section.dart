import 'package:flutter/material.dart';

import '../features/sharing/models/share_card_content.dart';
import '../features/sharing/services/share_card_service.dart';
import '../features/sharing/widgets/share_card.dart'
    show arabicFontFallback, arabicFontFamily;
import '../features/sharing/widgets/share_card_button.dart';
import '../prayer/daily_content.dart';

/// Today's ayah and hadith, each with a share action.
///
/// Controller-agnostic on purpose, like [NextPrayerCard]: the host app binds its
/// controller and passes the day in, so both apps render the same card from the same
/// code and neither has to know how the other fetches it.
///
/// Renders nothing when there is nothing to show — an empty frame where a verse
/// should be looks like a bug.
///
/// This is the **reading** card, not the exported one. It uses the app's typography
/// and layout; `ShareCard` is the fixed 1080-wide artefact. They are deliberately
/// different widgets, because a screen layout and a printable one are not the same
/// problem.
class DailyContentSection extends StatelessWidget {
  const DailyContentSection({
    super.key,
    required this.day,
    required this.service,
    this.isLoading = false,
    this.brandName = 'Zyaad',
    this.logo,
    this.leadingLanguage = ShareCardTranslationLanguage.urdu,
  });

  /// Null before the first load, or when the fetch failed.
  final DailyContentDay? day;

  /// The share flow. Passed in rather than resolved here, so this widget stays
  /// testable without a DI container.
  final ShareCardService service;

  final bool isLoading;
  final String brandName;
  final Widget? logo;
  final ShareCardTranslationLanguage leadingLanguage;

  @override
  Widget build(BuildContext context) {
    final current = day;

    if (current == null || current.isEmpty) {
      // A skeleton only while the first load is in flight; otherwise nothing at all.
      return isLoading ? const _LoadingTile() : const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in current.items) ...[
          _ContentTile(
            content: item,
            service: service,
            brandName: brandName,
            logo: logo,
            leadingLanguage: leadingLanguage,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// One ayah or hadith, with its citation and a share button.
class _ContentTile extends StatelessWidget {
  const _ContentTile({
    required this.content,
    required this.service,
    required this.brandName,
    required this.logo,
    required this.leadingLanguage,
  });

  final ShareCardContent content;
  final ShareCardService service;
  final String brandName;
  final Widget? logo;
  final ShareCardTranslationLanguage leadingLanguage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUrduLeading =
        leadingLanguage == ShareCardTranslationLanguage.urdu;

    final leading = content.translationFor(leadingLanguage);
    final secondary = content.translationFor(
      isUrduLeading
          ? ShareCardTranslationLanguage.english
          : ShareCardTranslationLanguage.urdu,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              content.arabicText,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: arabicFontFamily,
                fontFamilyFallback: arabicFontFallback,
                fontSize: 22,
                // Naskh diacritics sit high and low and collide at normal leading.
                height: 2.0,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (leading != null) ...[
              const SizedBox(height: 10),
              Text(
                leading,
                textDirection:
                    isUrduLeading ? TextDirection.rtl : TextDirection.ltr,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.9),
              ),
            ],
            if (secondary != null) ...[
              const SizedBox(height: 6),
              Text(
                secondary,
                textDirection:
                    isUrduLeading ? TextDirection.ltr : TextDirection.rtl,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _Citation(content: content),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ShareCardButton(
                content: content,
                service: service,
                brandName: brandName,
                logo: logo,
                leadingLanguage: leadingLanguage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reference, the source and the grade, exactly as the API stated them.
///
/// The reference is on its own line and reproduced character-for-character; the
/// grade and the licence are separate API fields shown as their own tokens, so
/// nothing about the citation string is altered by presentation.
class _Citation extends StatelessWidget {
  const _Citation({required this.content});

  final ShareCardContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final meta = <String>[
      if (content.hadithGrade != null) content.hadithGrade!,
      if (content.sourceLicense != null) content.sourceLicense!,
    ];

    return Column(
      children: [
        Text(
          content.reference,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 2),
        Text(
          content.sourceName,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            meta.join(' · '),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// A skeleton while the first load is in flight.
class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
