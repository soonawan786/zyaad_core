import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

import 'share_card_content_test.dart' show apiItem;

/// A service that never shares, for the card's render tests.
ShareCardService noopService() =>
    ShareCardService(sharer: const NoopShareCardSharer());

Future<void> pumpCard(WidgetTester tester, DailyContentDay? day,
    {bool isLoading = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DailyContentSection(
          day: day,
          isLoading: isLoading,
          service: noopService(),
        ),
      ),
    ),
  );
}

void main() {
  group('DailyContentDay.fromApiData', () {
    test('keeps both series, because which to feature is a product decision', () {
      final day = DailyContentDay.fromApiData(<String, dynamic>{
        'date': '2026-11-03',
        'items': <dynamic>[
          apiItem(),
          apiItem(overrides: {
            'type': 'hadith',
            'reference': 'Sahih al-Bukhari, Hadith 1',
            'hadith_grade': 'Sahih',
          }),
        ],
        'fallback_used': false,
      });

      expect(day, isNotNull);
      expect(day!.date, '2026-11-03');
      expect(day.items, hasLength(2));
      expect(day.ayah, isNotNull);
      expect(day.hadith, isNotNull);
      expect(day.hadith!.hadithGrade, 'Sahih');
      expect(day.fallbackUsed, isFalse);
      expect(day.isNotEmpty, isTrue);
    });

    test('skips a malformed item instead of blanking the whole day', () {
      final day = DailyContentDay.fromApiData(<String, dynamic>{
        'date': '2026-11-03',
        'items': <dynamic>[
          // No reference: cannot produce a truthful card.
          apiItem(overrides: {'reference': ''}),
          apiItem(),
        ],
      });

      // One bad row must not cost the user the day's content.
      expect(day!.items, hasLength(1));
      expect(day.items.single.reference, '2:255');
    });

    test('surfaces the fallback flag rather than hiding a repeat', () {
      final day = DailyContentDay.fromApiData(<String, dynamic>{
        'date': '2026-11-03',
        'items': <dynamic>[apiItem()],
        'fallback_used': true,
      });

      expect(day!.fallbackUsed, isTrue);
    });

    test('returns null for a payload it cannot read', () {
      expect(DailyContentDay.fromApiData(null), isNull);
      expect(DailyContentDay.fromApiData('nonsense'), isNull);
      expect(DailyContentDay.fromApiData(<String, dynamic>{}), isNull);
    });

    test('treats an empty list as an empty day, not an error', () {
      final day = DailyContentDay.fromApiData(<String, dynamic>{
        'date': '2026-11-03',
        'items': <dynamic>[],
      });

      expect(day!.isEmpty, isTrue);
      expect(day.ayah, isNull);
      expect(day.hadith, isNull);
    });
  });

  group('DailyContentSection', () {
    testWidgets('renders the Arabic, both translations and the citation',
        (tester) async {
      final day = DailyContentDay.fromApiData(<String, dynamic>{
        'date': '2026-11-03',
        'items': <dynamic>[apiItem()],
      });

      await pumpCard(tester, day);

      expect(find.text(day!.items.single.arabicText), findsOneWidget);
      expect(find.text(day.items.single.translationUr!), findsOneWidget);
      expect(find.text(day.items.single.translationEn!), findsOneWidget);
      expect(find.text('2:255'), findsOneWidget);
      expect(find.text('UmmahAPI (Quran)'), findsOneWidget);

      // The share action is present, which is the point of the card.
      expect(find.byType(ShareCardButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a skeleton while the first load is in flight',
        (tester) async {
      await pumpCard(tester, null, isLoading: true);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders nothing when there is no content and no load running',
        (tester) async {
      await pumpCard(tester, null);

      // An empty frame where a verse should be reads as a bug.
      expect(find.byType(Card), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders nothing for an empty day', (tester) async {
      final day = DailyContentDay.fromApiData(<String, dynamic>{
        'date': '2026-11-03',
        'items': <dynamic>[],
      });

      await pumpCard(tester, day);

      expect(find.byType(Card), findsNothing);
    });

    testWidgets('shows both series when the API sent both', (tester) async {
      final day = DailyContentDay.fromApiData(<String, dynamic>{
        'date': '2026-11-03',
        'items': <dynamic>[
          apiItem(),
          apiItem(
            // No licence, so the metadata line is the grade alone and can be
            // asserted exactly rather than as part of a joined string.
            sourceOverrides: {'license': ''},
            overrides: {
              'type': 'hadith',
              'arabic_text': 'إنما الأعمال بالنيات',
              'reference': 'Sahih al-Bukhari, Hadith 1',
              'hadith_grade': 'Sahih',
            },
          ),
        ],
      });

      await pumpCard(tester, day);

      expect(find.byType(ShareCardButton), findsNWidgets(2));
      expect(find.text('Sahih al-Bukhari, Hadith 1'), findsOneWidget);
      expect(find.text('Sahih'), findsOneWidget);
    });

    testWidgets('shows the Arabic alone when the API sent no translation',
        (tester) async {
      final day = DailyContentDay.fromApiData(<String, dynamic>{
        'date': '2026-11-03',
        'items': <dynamic>[
          apiItem(overrides: {
            'translations': <String, dynamic>{},
          }),
        ],
      });

      await pumpCard(tester, day);

      expect(find.text(day!.items.single.arabicText), findsOneWidget);
      expect(find.text('2:255'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
