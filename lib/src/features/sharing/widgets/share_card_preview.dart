import 'package:flutter/widgets.dart';

import '../models/share_card_content.dart';
import '../models/share_card_format.dart';
import '../models/share_card_template.dart';
import 'share_card.dart';

/// The global bounds of the widget that started a share.
///
/// Required on iPad: the share sheet is a popover there and iOS needs a rectangle
/// to anchor it to. Returning null is fine on phones, where iOS falls back to the
/// screen centre rather than failing.
Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();

  if (box is! RenderBox || !box.hasSize) {
    return null;
  }

  return box.localToGlobal(Offset.zero) & box.size;
}

/// An on-screen preview of the card, at its true proportions.
///
/// Renders the *same* widget the renderer captures, scaled to fit — not a
/// lookalike. A preview built separately from the exported image is the classic
/// source of "it looked fine in the app" complaints, because the two drift.
///
/// Stateless on purpose: the host owns `isBusy` and `errorMessage`, so this works
/// with GetX (the rest of this package), with a plain `setState`, or with nothing
/// at all.
class ShareCardPreview extends StatelessWidget {
  const ShareCardPreview({
    super.key,
    required this.content,
    this.format = ShareCardFormat.portrait,
    this.template = ShareCardTemplate.classic,
    this.leadingLanguage = ShareCardTranslationLanguage.urdu,
    this.brandName = 'Zyaad',
    this.logo,
    this.isBusy = false,
    this.busyLabel = 'Preparing the image…',
    this.errorMessage,
  });

  final ShareCardContent content;
  final ShareCardFormat format;
  final ShareCardTemplate template;
  final ShareCardTranslationLanguage leadingLanguage;
  final String brandName;
  final Widget? logo;

  /// Shows a scrim over the card while a render or a share is in flight.
  final bool isBusy;

  final String busyLabel;

  /// Shown as a banner beneath the card. Null hides it.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          // Reserves the card's true box before it lays out, so the sheet does not
          // jump when the preview appears.
          aspectRatio: format.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.contain,
                child: ShareCard(
                  content: content,
                  format: format,
                  template: template,
                  leadingLanguage: leadingLanguage,
                  brandName: brandName,
                  logo: logo,
                ),
              ),
              if (isBusy) _BusyScrim(label: busyLabel),
            ],
          ),
        ),
        if (errorMessage != null) _ErrorBanner(message: errorMessage!),
      ],
    );
  }
}

/// The loading state.
///
/// Deliberately not a spinner centred on the card: the card is what the user is
/// looking at, and covering it with an opaque spinner makes the screen feel
/// broken. A translucent scrim plus a sentence keeps the card visible and says
/// what is happening.
class _BusyScrim extends StatelessWidget {
  const _BusyScrim({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0x99000000)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 22, height: 22, child: _Spinner()),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFFFFFFF),
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A minimal ring spinner.
///
/// Hand-rolled rather than `CircularProgressIndicator`, because that requires a
/// `Material` ancestor and this widget is also mounted inside a bare
/// `RepaintBoundary` with no app above it.
class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border(
            top: BorderSide(color: Color(0xFFFFFFFF), width: 2),
            right: BorderSide(color: Color(0x55FFFFFF), width: 2),
            bottom: BorderSide(color: Color(0x55FFFFFF), width: 2),
            left: BorderSide(color: Color(0x55FFFFFF), width: 2),
          ),
        ),
      ),
    );
  }
}

/// The error state: one sentence, no stack trace, no retry button.
///
/// The service already decides what the user can usefully be told, so this only
/// presents it. A retry affordance belongs on the share button the user just
/// pressed, which is still on screen.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF3C2C2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF8A1F1F),
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
