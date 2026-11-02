import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

import 'share_card_content_test.dart' show apiItem;

/// A renderer that returns known bytes, so the service can be tested without a
/// rendering pipeline.
class _FakeRenderer implements ShareCardRenderer {
  _FakeRenderer({this.failure});

  final Object? failure;

  /// The bytes the service will write. Fixed rather than parameterised, so a test
  /// can assert the exact file contents.
  static final Uint8List _bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

  int calls = 0;
  ShareCardFormat? lastFormat;
  ShareCardTemplate? lastTemplate;
  ShareCardContent? lastContent;

  @override
  Future<Uint8List> render({
    required BuildContext context,
    required ShareCardContent content,
    required ShareCardFormat format,
    required ShareCardTemplate template,
    ShareCardTranslationLanguage leadingLanguage =
        ShareCardTranslationLanguage.urdu,
    String brandName = 'Zyaad',
    Widget? logo,
    double? pixelRatio,
  }) async {
    calls++;
    lastFormat = format;
    lastTemplate = template;
    lastContent = content;

    if (failure != null) {
      throw failure!;
    }

    return _bytes;
  }
}

/// Records what would have been handed to the share sheet.
class _FakeSharer implements ShareCardSharer {
  _FakeSharer({this.outcome = ShareCardShareOutcome.shared, this.failure});

  final ShareCardShareOutcome outcome;
  final Object? failure;

  File? lastFile;
  String? lastName;
  String? lastText;
  String? lastSubject;
  Rect? lastOrigin;

  @override
  Future<ShareCardShareOutcome> share({
    required File file,
    required String fileName,
    required String text,
    String? subject,
    Rect? origin,
  }) async {
    lastFile = file;
    lastName = fileName;
    lastText = text;
    lastSubject = subject;
    lastOrigin = origin;

    if (failure != null) {
      throw failure!;
    }

    return outcome;
  }
}

/// Decodes a PNG and returns its pixel size — the only honest way to assert the
/// acceptance criterion "images have correct dimensions".
Future<Size> decodePngSize(WidgetTester tester, Uint8List bytes) async {
  final size = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final result = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();

    return result;
  });

  return size!;
}

/// Captures a widget through a `RepaintBoundary` at a format's ratio.
///
/// Uses the same mechanism the production renderer does — `RenderRepaintBoundary`
/// + `toImage` — so the dimension assertions test the real path rather than a
/// restatement of the arithmetic.
Future<Uint8List> capture(
  WidgetTester tester,
  Widget child,
  double pixelRatio,
) async {
  final key = GlobalKey();

  /*
   * The card is 360x640 logical for a Story, which is taller than the default
   * 800x600 test surface. Without room it would be clamped and the capture would be
   * 1800px tall rather than 1920 — the same clamping the renderer guards against
   * with UnconstrainedBox, asserted here from the outside.
   */
  await tester.binding.setSurfaceSize(const Size(1200, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(key: key, child: child),
      ),
    ),
  );

  final bytes = await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    return data!.buffer.asUint8List();
  });

  return bytes!;
}

void main() {
  final content = ShareCardContent.fromApiItem(apiItem());

  group('ShareCard layout', () {
    testWidgets('renders the Arabic, the reference, the source and the grade',
        (tester) async {
      // A source with no licence, so the metadata line is the grade alone and can
      // be asserted exactly rather than as part of a joined string.
      final graded = ShareCardContent.fromApiItem(
        apiItem(
          sourceOverrides: {'license': ''},
          overrides: {
            'type': 'hadith',
            'reference': 'Sahih al-Bukhari, Hadith 1',
            'hadith_grade': 'Sahih',
          },
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ShareCard(content: graded),
        ),
      );

      expect(find.text(graded.arabicText), findsOneWidget);
      expect(find.text('Sahih al-Bukhari, Hadith 1'), findsOneWidget);
      expect(find.text('UmmahAPI (Quran)'), findsOneWidget);
      expect(find.text('Sahih'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the Urdu first and the English beneath it',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ShareCard(content: content),
        ),
      );

      // Mixed-language content is the normal case: both are on the card.
      expect(find.text(content.translationUr!), findsOneWidget);
      expect(find.text(content.translationEn!), findsOneWidget);
    });

    testWidgets('is not clamped by a surface narrower than the card',
        (tester) async {
      /*
       * Regression guard for a silent wrong-size export. A story card is 360x640
       * logical; on a 320dp-wide phone the overlay's constraints would clamp it and
       * the PNG would come out 960 wide instead of 1080, with no error anywhere.
       * The renderer wraps the card in an UnconstrainedBox for this reason.
       */
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final format in ShareCardFormat.values) {
        final bytes = await capture(
          tester,
          ShareCard(content: content, format: format),
          format.pixelRatio,
        );

        expect(
          await decodePngSize(tester, bytes),
          format.outputSize,
          reason: '${format.name} must not be clamped by the device',
        );
      }
    });

    testWidgets('renders every template without error', (tester) async {
      for (final template in ShareCardTemplates.all) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ShareCard(content: content, template: template),
          ),
        );

        expect(tester.takeException(), isNull, reason: template.name);
      }
    });

    testWidgets('renders the Arabic without a MediaQuery ancestor',
        (tester) async {
      // The renderer mounts the card inside a bare RepaintBoundary, so the widget
      // must not require an app above it.
      await tester.pumpWidget(ShareCard(content: content));

      expect(tester.takeException(), isNull);
      expect(find.text(content.arabicText), findsOneWidget);
    });

    testWidgets('does not clip or overflow a very long ayah', (tester) async {
      // Ayat al-Kursi is the longest verse in the Quran; the card must scale it
      // down rather than drop its tail.
      final long = ShareCardContent.fromApiItem(apiItem(overrides: {
        'arabic_text': 'ٱللَّهُ لَآ إِلَـٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ '
            'لَا تَأْخُذُهُۥ سِنَةٌ وَلَا نَوْمٌ لَّهُۥ مَا فِى ٱلسَّمَـٰوَٰتِ '
            'وَمَا فِى ٱلْأَرْضِ مَن ذَا ٱلَّذِى يَشْفَعُ عِندَهُۥٓ إِلَّا '
            'بِإِذْنِهِۦ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ '
            'وَلَا يُحِيطُونَ بِشَىْءٍ مِّنْ عِلْمِهِۦٓ إِلَّا بِمَا شَآءَ '
            'وَسِعَ كُرْسِيُّهُ ٱلسَّمَـٰوَٰتِ وَٱلْأَرْضَ وَلَا يَـُٔودُهُۥ '
            'حِفْظُهُمَا وَهُوَ ٱلْعَلِىُّ ٱلْعَظِيمُ',
        'reference': '2:255',
      }));

      for (final format in ShareCardFormat.values) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ShareCard(content: long, format: format),
          ),
        );

        // A RenderFlex overflow or a clipped Text raises here.
        expect(tester.takeException(), isNull, reason: format.name);

        // The whole verse is present in the tree, not a truncated prefix.
        final widget = tester.widget<Text>(find.text(long.arabicText));
        expect(widget.maxLines, isNull);
        expect(widget.overflow, isNull);
      }
    });
  });

  group('RepaintBoundary capture', () {
    testWidgets('produces exactly 1080x1350 for the portrait card',
        (tester) async {
      final bytes = await capture(
        tester,
        ShareCard(content: content, format: ShareCardFormat.portrait),
        ShareCardFormat.portrait.pixelRatio,
      );

      expect(
        await decodePngSize(tester, bytes),
        const Size(1080, 1350),
      );
    });

    testWidgets('produces exactly 1080x1920 for the story card',
        (tester) async {
      final bytes = await capture(
        tester,
        ShareCard(content: content, format: ShareCardFormat.story),
        ShareCardFormat.story.pixelRatio,
      );

      expect(
        await decodePngSize(tester, bytes),
        const Size(1080, 1920),
      );
    });
  });

  group('ShareCardService', () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('zyaad_share_test');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    testWidgets('renders, writes a png and hands it to the share sheet',
        (tester) async {
      final renderer = _FakeRenderer();
      final sharer = _FakeSharer();
      final store = ShareCardFileStore(root: tempRoot);

      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      /*
       * Wrapped in runAsync: the store does real dart:io work, and inside a
       * testWidgets body the fake-async zone never completes a real file
       * operation — the test would simply hang rather than fail.
       */
      final result = await tester.runAsync(
        () => ShareCardService(
          renderer: renderer,
          fileStore: store,
          sharer: sharer,
        ).share(
          context: context,
          content: content,
          format: ShareCardFormat.story,
          template: ShareCardTemplate.night,
        ),
      );

      expect(result!.isShared, isTrue);
      expect(result.isFailure, isFalse);

      expect(renderer.calls, 1);
      expect(renderer.lastFormat, ShareCardFormat.story);
      expect(renderer.lastTemplate, ShareCardTemplate.night);

      // The file exists, is named for the format, and carries the rendered bytes.
      expect(sharer.lastFile!.existsSync(), isTrue);
      expect(sharer.lastFile!.path, endsWith('.png'));
      expect(sharer.lastName, 'zyaad-card-1080x1920.png');
      expect(sharer.lastFile!.readAsBytesSync(), <int>[1, 2, 3, 4]);

      // The caption is the API content, not a generic invitation.
      expect(sharer.lastText, contains(content.arabicText));
      expect(sharer.lastText, contains('— 2:255'));
      expect(sharer.lastText, contains('UmmahAPI (Quran)'));
      expect(sharer.lastSubject, contains('Ayah · 2:255'));
    });

    testWidgets('passes the origin through, which iPad needs', (tester) async {
      final sharer = _FakeSharer();
      const origin = Rect.fromLTWH(12, 34, 56, 78);

      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      await tester.runAsync(
        () => ShareCardService(
          renderer: _FakeRenderer(),
          fileStore: ShareCardFileStore(root: tempRoot),
          sharer: sharer,
        ).share(context: context, content: content, origin: origin),
      );

      expect(sharer.lastOrigin, origin);
    });

    testWidgets('reports a render failure as a message rather than throwing',
        (tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      final result = await tester.runAsync(
        () => ShareCardService(
          renderer: _FakeRenderer(
            failure: const ShareCardRenderException('no GPU context'),
          ),
          fileStore: ShareCardFileStore(root: tempRoot),
          sharer: _FakeSharer(),
        ).share(context: context, content: content),
      );

      expect(result!.isFailure, isTrue);
      expect(result.isShared, isFalse);
      expect(result.message, contains('no GPU context'));
    });

    testWidgets('reports a share-sheet failure without leaking the cause',
        (tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      final result = await tester.runAsync(
        () => ShareCardService(
          renderer: _FakeRenderer(),
          fileStore: ShareCardFileStore(root: tempRoot),
          sharer: _FakeSharer(failure: Exception('PlatformException(boom)')),
        ).share(context: context, content: content),
      );

      expect(result!.isFailure, isTrue);
      expect(result.message, 'Sharing did not open. Please try again.');
      // The platform exception text is not shown to the user.
      expect(result.message, isNot(contains('PlatformException')));
    });

    testWidgets('treats a dismissed sheet as neither success nor failure',
        (tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      final result = await tester.runAsync(
        () => ShareCardService(
          renderer: _FakeRenderer(),
          fileStore: ShareCardFileStore(root: tempRoot),
          sharer: _FakeSharer(outcome: ShareCardShareOutcome.dismissed),
        ).share(context: context, content: content),
      );

      expect(result!.isFailure, isFalse);
      expect(result.isShared, isFalse);
      expect(result.outcome, ShareCardShareOutcome.dismissed);
    });
  });

  group('ShareCardFileStore', () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('zyaad_store_test');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('writes a png and gives every share a unique name', () async {
      final store = ShareCardFileStore(root: tempRoot);
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);

      final first = await store.write(bytes, stem: 'zyaad-card-1080x1350');
      final second = await store.write(bytes, stem: 'zyaad-card-1080x1350');

      expect(first.existsSync(), isTrue);
      expect(second.existsSync(), isTrue);
      // A stable name would let a receiving app serve a cached previous card.
      expect(first.path, isNot(second.path));
      expect(first.path, endsWith('.png'));
    });

    test('reaps stale cards but never the one just written', () async {
      final store = ShareCardFileStore(root: tempRoot);
      final bytes = Uint8List.fromList(<int>[1]);

      final stale = await store.write(bytes, stem: 'old');
      // Backdate it past the retention window.
      stale.setLastModifiedSync(
        DateTime.now().subtract(const Duration(hours: 3)),
      );

      final fresh = await store.write(bytes, stem: 'new');

      expect(stale.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
    });

    test('is safe to call on a directory that does not exist', () async {
      final store = ShareCardFileStore(
        root: Directory('${tempRoot.path}/nested/never-created'),
      );

      // Must not throw: an unwritable temp directory cannot be allowed to break
      // sharing, and app start may call this before anything has been written.
      expect(await store.cleanStale(), 0);
    });

    test('clear removes everything it wrote', () async {
      final store = ShareCardFileStore(root: tempRoot);

      await store.write(Uint8List.fromList(<int>[1]), stem: 'a');
      await store.write(Uint8List.fromList(<int>[2]), stem: 'b');

      await store.clear();

      expect(tempRoot.existsSync(), isFalse);
    });
  });
}
