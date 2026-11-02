import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

/// The shape `GET /api/v1/daily-content` actually returns, as captured from the
/// running endpoint. Every field the card reads is present, so the model is tested
/// against the real contract rather than an invented one.
Map<String, dynamic> apiItem({
  Map<String, dynamic> overrides = const {},
  Map<String, dynamic> sourceOverrides = const {},
}) {
  return <String, dynamic>{
    'id': '0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0',
    'type': 'ayah',
    'arabic_text': 'ٱللَّهُ لَآ إِلَـٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ',
    'translations': <String, dynamic>{
      'ur': 'اللہ، وہ زندہ جاوید ہستی',
      'en': 'Allah - there is no deity except Him',
    },
    'reference': '2:255',
    'hadith_grade': null,
    'source': <String, dynamic>{
      'name': 'UmmahAPI (Quran)',
      'license': 'UmmahAPI — free to use (sadaqah jariah).',
      ...sourceOverrides,
    },
    'scheduled_date': '2026-11-03',
    'is_fallback': false,
    ...overrides,
  };
}

void main() {
  group('ShareCardContent.fromApiItem', () {
    test('reads every field the card renders', () {
      final content = ShareCardContent.fromApiItem(apiItem());

      expect(content.arabicText, contains('ٱللَّهُ'));
      expect(content.reference, '2:255');
      expect(content.sourceName, 'UmmahAPI (Quran)');
      expect(content.type, ShareCardContentType.ayah);
      expect(content.translationUr, 'اللہ، وہ زندہ جاوید ہستی');
      expect(content.translationEn, 'Allah - there is no deity except Him');
      expect(content.sourceLicense, contains('sadaqah jariah'));
      expect(content.date, '2026-11-03');
      expect(content.isFallback, isFalse);
      expect(content.hasNoTranslation, isFalse);
    });

    test('reproduces the reference verbatim, including a hadith citation', () {
      final content = ShareCardContent.fromApiItem(apiItem(overrides: {
        'type': 'hadith',
        'reference': 'Sahih al-Bukhari, Hadith 1',
        'hadith_grade': 'Sahih',
      }));

      // Not trimmed to "1", not reformatted, not shortened.
      expect(content.reference, 'Sahih al-Bukhari, Hadith 1');
      expect(content.type, ShareCardContentType.hadith);
      expect(content.hadithGrade, 'Sahih');
    });

    test('refuses to build without the Arabic', () {
      expect(
        () =>
            ShareCardContent.fromApiItem(apiItem(overrides: {'arabic_text': ''})),
        throwsA(isA<ShareCardContentException>()),
      );
    });

    test('refuses to build without a reference', () {
      // The rule that matters most: a card is a quotation, and an uncited one must
      // not be constructible, so it can never be shared.
      expect(
        () => ShareCardContent.fromApiItem(
          apiItem(overrides: {'reference': '   '}),
        ),
        throwsA(
          isA<ShareCardContentException>()
              .having((e) => e.message, 'message', contains('reference')),
        ),
      );
    });

    test('refuses to build without an attribution', () {
      expect(
        () => ShareCardContent.fromApiItem(
          apiItem(sourceOverrides: {'name': ''}),
        ),
        throwsA(
          isA<ShareCardContentException>()
              .having((e) => e.message, 'message', contains('source.name')),
        ),
      );

      expect(
        () => ShareCardContent.fromApiItem(apiItem(overrides: {'source': null})),
        throwsA(isA<ShareCardContentException>()),
      );
    });

    test('leaves absent fields null instead of substituting a placeholder', () {
      final content = ShareCardContent.fromApiItem(apiItem(overrides: {
        'hadith_grade': null,
        'translations': <String, dynamic>{'ur': 'اردو'},
      }));

      // No "unknown", no dash, no empty string — null, so the card omits the line.
      expect(content.hadithGrade, isNull);
      expect(content.translationEn, isNull);
      expect(content.sourceUrl, isNull);
      expect(content.translationFor(ShareCardTranslationLanguage.english), isNull);
    });

    test('treats a blank string as absent rather than as content', () {
      final content = ShareCardContent.fromApiItem(apiItem(overrides: {
        'translations': <String, dynamic>{'ur': '   ', 'en': ''},
      }));

      expect(content.translationUr, isNull);
      expect(content.translationEn, isNull);
      expect(content.hasNoTranslation, isTrue);
    });

    test('reads a source url when the API sends one, without inventing it', () {
      final withUrl = ShareCardContent.fromApiItem(
        apiItem(sourceOverrides: {'url': 'https://ummahapi.com'}),
      );
      expect(withUrl.sourceUrl, 'https://ummahapi.com');

      // Never derived from sourceName.
      expect(ShareCardContent.fromApiItem(apiItem()).sourceUrl, isNull);
    });

    test('surfaces the fallback flag rather than hiding a repeat', () {
      final content = ShareCardContent.fromApiItem(
        apiItem(overrides: {'is_fallback': true}),
      );

      expect(content.isFallback, isTrue);
    });
  });

  group('ShareCardFormat', () {
    test('produces exactly 1080x1350 and 1080x1920', () {
      expect(ShareCardFormat.portrait.outputSize, const Size(1080, 1350));
      expect(ShareCardFormat.story.outputSize, const Size(1080, 1920));
    });

    test('captures at 3x, with the ratio derived from the sizes', () {
      for (final format in ShareCardFormat.values) {
        expect(format.pixelRatio, 3.0, reason: format.name);
        expect(format.logicalWidth * format.pixelRatio, format.width);
        expect(format.logicalHeight * format.pixelRatio, format.height);
      }
    });

    test('keeps the published aspect ratios', () {
      expect(ShareCardFormat.portrait.aspectRatio, closeTo(0.8, 0.0001));
      expect(ShareCardFormat.story.aspectRatio, closeTo(0.5625, 0.0001));
    });

    test('gives each format a distinct file name', () {
      expect(ShareCardFormat.portrait.fileStem, 'zyaad-card-1080x1350');
      expect(ShareCardFormat.story.fileStem, 'zyaad-card-1080x1920');
    });
  });

  group('ShareCardService.shareTextFor', () {
    test('is built only from the API payload', () {
      final content = ShareCardContent.fromApiItem(apiItem());
      final text = ShareCardService.shareTextFor(content);

      expect(text, contains(content.arabicText));
      expect(text, contains(content.translationUr!));
      expect(text, contains(content.translationEn!));
      expect(text, contains('— 2:255'));
      expect(text, contains('UmmahAPI (Quran)'));
    });

    test('omits a translation the API did not send rather than filling it in', () {
      final content = ShareCardContent.fromApiItem(apiItem(overrides: {
        'translations': <String, dynamic>{'ur': 'اردو ترجمہ'},
      }));

      final text = ShareCardService.shareTextFor(content);

      expect(text, contains('اردو ترجمہ'));
      expect(text, isNot(contains('Allah')));
    });

    test('leads with the requested language', () {
      final content = ShareCardContent.fromApiItem(apiItem());

      final urduFirst = ShareCardService.shareTextFor(content);
      final englishFirst = ShareCardService.shareTextFor(
        content,
        leadingLanguage: ShareCardTranslationLanguage.english,
      );

      expect(
        urduFirst.indexOf(content.translationUr!),
        lessThan(urduFirst.indexOf(content.translationEn!)),
      );
      expect(
        englishFirst.indexOf(content.translationEn!),
        lessThan(englishFirst.indexOf(content.translationUr!)),
      );
    });

    test('includes the grade for a graded hadith', () {
      final content = ShareCardContent.fromApiItem(apiItem(overrides: {
        'type': 'hadith',
        'reference': 'Sahih al-Bukhari, Hadith 1',
        'hadith_grade': 'Sahih',
      }));

      expect(ShareCardService.shareTextFor(content), contains('Sahih'));
    });
  });

  group('ShareCardTemplates', () {
    test('offers three treatments', () {
      expect(ShareCardTemplates.all, hasLength(3));
      expect(
        ShareCardTemplates.all,
        containsAll(<ShareCardTemplate>[
          ShareCardTemplate.classic,
          ShareCardTemplate.night,
          ShareCardTemplate.minimal,
        ]),
      );
    });

    test('defaults a Story to the dark treatment and a feed to the light one', () {
      expect(
        ShareCardTemplates.defaultFor(ShareCardFormat.story),
        ShareCardTemplate.night,
      );
      expect(
        ShareCardTemplates.defaultFor(ShareCardFormat.portrait),
        ShareCardTemplate.classic,
      );
    });

    test('every template has a complete palette', () {
      for (final template in ShareCardTemplate.values) {
        expect(template.label, isNotEmpty);
        expect(template.palette.isDark, template == ShareCardTemplate.night);
      }
    });
  });
}
