import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

import 'share_card_content_test.dart' show apiItem;

/// A service that records the call instead of rendering and sharing.
///
/// `ShareCardService` is a concrete class, so it is subclassed rather than mocked;
/// `share` is an ordinary method and overrides cleanly. The real constructor still
/// runs, which is why it needs a sharer — `NoopShareCardSharer` is the one this
/// package ships for exactly this.
class _FakeService extends ShareCardService {
  _FakeService(this.result) : super(sharer: const NoopShareCardSharer());

  final ShareCardShareResult result;

  int calls = 0;
  ShareCardFormat? lastFormat;
  ShareCardTemplate? lastTemplate;
  Rect? lastOrigin;

  @override
  Future<ShareCardShareResult> share({
    required BuildContext context,
    required ShareCardContent content,
    ShareCardFormat format = ShareCardFormat.portrait,
    ShareCardTemplate template = ShareCardTemplate.classic,
    ShareCardTranslationLanguage leadingLanguage =
        ShareCardTranslationLanguage.urdu,
    String brandName = 'Zyaad',
    Widget? logo,
    Rect? origin,
  }) async {
    calls++;
    lastFormat = format;
    lastTemplate = template;
    lastOrigin = origin;

    return result;
  }
}

/// Hosts a widget in a Material app, which the sheet needs —
/// `showModalBottomSheet` requires a `Navigator` and a `Material` ancestor.
Future<void> pumpHost(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

/// The share button *inside* the sheet.
///
/// Scoped to the sheet on purpose: the host button is also a `FilledButton` with
/// the text "Share", so an unscoped finder matches two widgets and the tap fails.
Finder sheetShareButton() => find.descendant(
      of: find.byType(ShareCardSheet),
      matching: find.widgetWithText(FilledButton, 'Share'),
    );

void main() {
  final content = ShareCardContent.fromApiItem(apiItem());

  group('ShareCardButton', () {
    testWidgets('opens the sheet and shows the card', (tester) async {
      final service = _FakeService(
        ShareCardShareResult.completed(ShareCardShareOutcome.shared),
      );

      await pumpHost(
        tester,
        ShareCardButton(content: content, service: service),
      );

      expect(find.text('Share'), findsOneWidget);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      // The sheet is open and the card is rendered inside it — the same widget the
      // renderer captures, not a lookalike.
      expect(find.byType(ShareCardSheet), findsOneWidget);
      expect(find.byType(ShareCard), findsOneWidget);
      expect(find.text(content.arabicText), findsOneWidget);
      expect(find.text(content.reference), findsOneWidget);
      expect(find.text(content.sourceName), findsOneWidget);
    });

    testWidgets('passes the button rect as the origin, which iPad needs',
        (tester) async {
      final service = _FakeService(
        ShareCardShareResult.completed(ShareCardShareOutcome.shared),
      );

      await pumpHost(
        tester,
        ShareCardButton(content: content, service: service),
      );

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      // Tap the sheet's own share button.
      await tester.tap(sheetShareButton());
      await tester.pumpAndSettle();

      expect(service.calls, 1);
      expect(
        service.lastOrigin,
        isNotNull,
        reason: 'the iPad popover must be anchored to a rectangle',
      );
    });
  });

  group('ShareCardSheet', () {
    testWidgets('starts on the format that suits the treatment', (tester) async {
      final service = _FakeService(
        ShareCardShareResult.completed(ShareCardShareOutcome.shared),
      );

      await pumpHost(
        tester,
        ShareCardButton(content: content, service: service),
      );

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      // A feed card is the default, and it defaults to the light treatment.
      final preview =
          tester.widget<ShareCardPreview>(find.byType(ShareCardPreview));

      expect(preview.format, ShareCardFormat.portrait);
      expect(preview.template, ShareCardTemplate.classic);
    });

    testWidgets('shares with the format and treatment the user chose',
        (tester) async {
      final service = _FakeService(
        ShareCardShareResult.completed(ShareCardShareOutcome.shared),
      );

      await pumpHost(
        tester,
        ShareCardButton(content: content, service: service),
      );

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      // Switch to Story, which should also move the treatment to the dark one.
      await tester.tap(find.text('Story'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<ShareCardPreview>(find.byType(ShareCardPreview)).format,
        ShareCardFormat.story,
      );
      expect(
        tester.widget<ShareCardPreview>(find.byType(ShareCardPreview)).template,
        ShareCardTemplate.night,
        reason: 'a Story is read against a dark UI',
      );

      // Pick the minimal treatment explicitly.
      await tester.tap(find.text('Minimal'));
      await tester.pumpAndSettle();

      await tester.tap(sheetShareButton());
      await tester.pumpAndSettle();

      expect(service.lastFormat, ShareCardFormat.story);
      expect(service.lastTemplate, ShareCardTemplate.minimal);
    });

    testWidgets('closes on a completed share', (tester) async {
      final service = _FakeService(
        ShareCardShareResult.completed(ShareCardShareOutcome.shared),
      );

      await pumpHost(
        tester,
        ShareCardButton(content: content, service: service),
      );

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      await tester.tap(sheetShareButton());
      await tester.pumpAndSettle();

      expect(find.byType(ShareCardSheet), findsNothing);
    });

    testWidgets('stays open and shows the error when sharing fails',
        (tester) async {
      final service = _FakeService(
        ShareCardShareResult.failure('There was not enough space.'),
      );

      await pumpHost(
        tester,
        ShareCardButton(content: content, service: service),
      );

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      await tester.tap(sheetShareButton());
      await tester.pumpAndSettle();

      // The sheet stays so the user can retry, and the reason is shown.
      expect(find.byType(ShareCardSheet), findsOneWidget);
      expect(find.text('There was not enough space.'), findsOneWidget);
    });

    testWidgets('stays open when the user dismisses the share sheet',
        (tester) async {
      final service = _FakeService(
        ShareCardShareResult.completed(ShareCardShareOutcome.dismissed),
      );

      await pumpHost(
        tester,
        ShareCardButton(content: content, service: service),
      );

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      await tester.tap(sheetShareButton());
      await tester.pumpAndSettle();

      // A dismissal is about the destination, not the card, so the sheet remains.
      expect(find.byType(ShareCardSheet), findsOneWidget);
      expect(find.textContaining('not enough space'), findsNothing);
    });
  });
}
