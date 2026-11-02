import 'dart:ui';

/// The two export sizes the card supports.
///
/// The card is laid out at a small **logical** size and captured at a pixel ratio
/// of 3, which is what makes the output exactly 1080 px wide with no post-scaling
/// and no rounding drift:
///
///   portrait  360 × 450  × 3 = 1080 × 1350
///   story     360 × 640  × 3 = 1080 × 1920
///
/// Laying out at 1080 logical pixels instead would be a mistake: every font size,
/// padding and line height would then have to be written in output pixels, and the
/// card could not be reused for an on-screen preview at all.
enum ShareCardFormat {
  /// 4:5 — the standard feed post. Fits Instagram, Facebook and WhatsApp Status
  /// without the platform cropping the reference line off the bottom.
  portrait(width: 1080, height: 1350, logicalWidth: 360, logicalHeight: 450),

  /// 9:16 — full-screen Story and Status.
  story(width: 1080, height: 1920, logicalWidth: 360, logicalHeight: 640);

  const ShareCardFormat({
    required this.width,
    required this.height,
    required this.logicalWidth,
    required this.logicalHeight,
  });

  /// Output width in device pixels.
  final int width;

  /// Output height in device pixels.
  final int height;

  /// The width the widget is laid out at before capture.
  final double logicalWidth;

  /// The height the widget is laid out at before capture.
  final double logicalHeight;

  /// The ratio to hand to `RenderRepaintBoundary.toImage`.
  ///
  /// Derived rather than hardcoded, so changing an output size cannot leave the
  /// ratio behind and silently produce a wrongly-sized PNG.
  double get pixelRatio => width / logicalWidth;

  Size get logicalSize => Size(logicalWidth, logicalHeight);

  Size get outputSize => Size(width.toDouble(), height.toDouble());

  double get aspectRatio => width / height;

  /// Story formats have much more vertical room, so the templates give the Arabic
  /// a larger type scale there rather than stretching the portrait layout.
  bool get isTall => this == ShareCardFormat.story;

  String get label => switch (this) {
        ShareCardFormat.portrait => 'Portrait 1080×1350',
        ShareCardFormat.story => 'Story 1080×1920',
      };

  /// A file-safe name stem, e.g. `zyaad-card-1080x1350`.
  String get fileStem => 'zyaad-card-${width}x$height';
}
