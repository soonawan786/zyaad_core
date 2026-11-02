import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../models/share_card_content.dart';
import '../models/share_card_format.dart';
import '../models/share_card_template.dart';
import '../widgets/share_card.dart' as widget;

/// Turns a [widget.ShareCard] into PNG bytes.
///
/// An interface rather than a bare function so the service can be tested without
/// a rendering pipeline: the widget tests assert the *layout* (dimensions, no
/// overflow, text present) and the service tests use a fake that returns a known
/// byte list. Neither has to do the other's job.
abstract class ShareCardRenderer {
  Future<Uint8List> render({
    required BuildContext context,
    required ShareCardContent content,
    required ShareCardFormat format,
    required ShareCardTemplate template,
    ShareCardTranslationLanguage leadingLanguage,
    String brandName,
    Widget? logo,
    double? pixelRatio,
  });
}

/// Captures the card through a `RepaintBoundary`, off-screen, at 3x.
///
/// Why an overlay and not a hidden widget in the page: the card must be laid out
/// and painted to be capturable, but it must not be visible, must not affect the
/// page's layout, and must exist even when the user is on a screen that has never
/// shown a card. An [OverlayEntry] positioned far off-screen gives all three, and
/// is removed in a `finally` so a failed capture cannot leak an entry.
///
/// The capture waits for **two** frames rather than one: the first lays the card
/// out, and the second paints it once text metrics have settled. Capturing after a
/// single frame is the classic cause of a blank or half-painted PNG.
class WidgetShareCardRenderer implements ShareCardRenderer {
  const WidgetShareCardRenderer();

  @override
  Future<Uint8List> render({
    required BuildContext context,
    required ShareCardContent content,
    required ShareCardFormat format,
    required ShareCardTemplate template,
    ShareCardTranslationLanguage leadingLanguage = ShareCardTranslationLanguage.urdu,
    String brandName = 'Zyaad',
    Widget? logo,
    double? pixelRatio,
  }) async {
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        // Off-screen but laid out at its full size. `Offstage` or a zero-size box
        // would skip layout or paint, and there would be nothing to capture.
        left: -(format.logicalWidth * 2),
        top: 0,
        child: RepaintBoundary(
          key: boundaryKey,
          /*
           * `UnconstrainedBox` is load-bearing, not decoration.
           *
           * The overlay hands the entry the *screen's* constraints, so on a narrow
           * device (or a small test surface) the card would be clamped to the
           * available width and height. A story card is 640 logical pixels tall and
           * a 320dp-wide phone is 320 wide: without this the export silently became
           * 960x1920 instead of 1080x1920, and nothing errored.
           *
           * Giving the card unbounded constraints lets it lay out at exactly its
           * declared size, whatever the host device is.
           */
          child: UnconstrainedBox(
            alignment: Alignment.topLeft,
            child: widget.ShareCard(
              content: content,
              format: format,
              template: template,
              leadingLanguage: leadingLanguage,
              brandName: brandName,
              logo: logo,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    try {
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final boundary = boundaryKey.currentContext?.findRenderObject();

      if (boundary is! RenderRepaintBoundary) {
        throw const ShareCardRenderException(
          'The card was not mounted, so there is nothing to capture.',
        );
      }

      // Guards against capturing a boundary whose paint is still pending, which
      // yields a blank image rather than an error.
      if (boundary.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
      }

      final image = await boundary.toImage(
        pixelRatio: pixelRatio ?? format.pixelRatio,
      );

      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);

        if (data == null) {
          throw const ShareCardRenderException('The card produced no PNG data.');
        }

        return data.buffer.asUint8List();
      } finally {
        // Releases the GPU texture. Without this a gallery of previews leaks one
        // image per capture.
        image.dispose();
      }
    } finally {
      entry.remove();
    }
  }
}

/// Thrown when a card cannot be turned into an image.
class ShareCardRenderException implements Exception {
  const ShareCardRenderException(this.message);

  final String message;

  @override
  String toString() => 'ShareCardRenderException: $message';
}
