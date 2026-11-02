import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../models/share_card_content.dart';
import '../models/share_card_format.dart';
import '../models/share_card_template.dart';
import '../rendering/share_card_file_store.dart';
import '../rendering/share_card_renderer.dart';
import 'share_card_sharer.dart';

/// Render → write → share, with the failure modes handled rather than thrown.
///
/// Every step can fail for a reason the user cannot act on (no GPU context, an
/// unwritable temp directory, a platform with no share sheet), so the public
/// methods return a [ShareCardShareResult] instead of throwing. The one exception
/// is deliberately *not* caught here: [ShareCardContentException] is thrown while
/// building the content, before the service is involved, because a payload without
/// a reference is a programming error rather than a share failure.
///
/// [sharer] is **required** and has no default. A default would have to be a no-op,
/// because this package deliberately does not depend on `share_plus` (see
/// [ShareCardSharer]), and a no-op default turns a forgotten wiring into a button
/// that appears to work and shares nothing. Pass `const NoopShareCardSharer()`
/// explicitly when only the preview is wanted.
class ShareCardService {
  ShareCardService({
    required ShareCardSharer sharer,
    ShareCardRenderer renderer = const WidgetShareCardRenderer(),
    ShareCardFileStore? fileStore,
  })  : _renderer = renderer,
        _fileStore = fileStore ?? ShareCardFileStore(),
        _sharer = sharer;

  final ShareCardRenderer _renderer;
  final ShareCardFileStore _fileStore;
  final ShareCardSharer _sharer;

  /// PNG bytes for an on-screen preview or a save-to-gallery action.
  Future<Uint8List> renderPng({
    required BuildContext context,
    required ShareCardContent content,
    ShareCardFormat format = ShareCardFormat.portrait,
    ShareCardTemplate template = ShareCardTemplate.classic,
    ShareCardTranslationLanguage leadingLanguage =
        ShareCardTranslationLanguage.urdu,
    String brandName = 'Zyaad',
    Widget? logo,
  }) {
    return _renderer.render(
      context: context,
      content: content,
      format: format,
      template: template,
      leadingLanguage: leadingLanguage,
      brandName: brandName,
      logo: logo,
    );
  }

  /// Renders the card and opens the share sheet.
  ///
  /// [origin] must be the global bounds of the button that started the share. It
  /// is required on iPad — the sheet is a popover there and iOS needs a rectangle
  /// to anchor it to — and harmless elsewhere.
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
    try {
      final bytes = await renderPng(
        context: context,
        content: content,
        format: format,
        template: template,
        leadingLanguage: leadingLanguage,
        brandName: brandName,
        logo: logo,
      );

      final file = await _fileStore.write(bytes, stem: format.fileStem);

      final outcome = await _sharer.share(
        file: file,
        fileName: '${format.fileStem}.png',
        text: shareTextFor(content, leadingLanguage: leadingLanguage),
        subject: '${content.type.label} · ${content.reference}',
        origin: origin,
      );

      return ShareCardShareResult.completed(outcome, file: file);
    } on ShareCardRenderException catch (error) {
      return ShareCardShareResult.failure(
        'The card could not be created on this device. ${error.message}',
      );
    } on FileSystemException {
      return ShareCardShareResult.failure(
        'There was not enough space to prepare the image.',
      );
    } catch (_) {
      // The share sheet itself failed. The cause is platform-specific and not
      // actionable by the user, so it is not surfaced verbatim.
      return ShareCardShareResult.failure(
        'Sharing did not open. Please try again.',
      );
    }
  }

  /// Reaps stale rendered cards. Safe to call on app start.
  Future<int> cleanUp() => _fileStore.cleanStale();

  /// The caption that accompanies the image.
  ///
  /// Built only from what the API sent — the Arabic, whichever translations are
  /// present, the reference and the source. Nothing is composed, summarised or
  /// paraphrased, and a missing field is omitted rather than filled in.
  ///
  /// The caption repeats the verse rather than relying on the image, because some
  /// destinations (an SMS, a plain-text chat) drop the attachment, and a citation
  /// with no text would be worse than no message at all.
  static String shareTextFor(
    ShareCardContent content, {
    ShareCardTranslationLanguage leadingLanguage =
        ShareCardTranslationLanguage.urdu,
  }) {
    final parts = <String>[content.arabicText];

    final leading = content.translationFor(leadingLanguage);
    if (leading != null) {
      parts.add(leading);
    }

    final other = content.translationFor(
      leadingLanguage == ShareCardTranslationLanguage.urdu
          ? ShareCardTranslationLanguage.english
          : ShareCardTranslationLanguage.urdu,
    );

    if (other != null) {
      parts.add(other);
    }

    parts
      ..add('— ${content.reference}')
      ..add(content.sourceName);

    if (content.hadithGrade != null) {
      parts.add(content.hadithGrade!);
    }

    return parts.join('\n\n');
  }
}

/// The outcome of a share attempt.
class ShareCardShareResult {
  const ShareCardShareResult._({
    required this.outcome,
    this.file,
    this.message,
  });

  factory ShareCardShareResult.completed(
    ShareCardShareOutcome outcome, {
    File? file,
  }) =>
      ShareCardShareResult._(outcome: outcome, file: file);

  factory ShareCardShareResult.failure(String message) =>
      ShareCardShareResult._(
        outcome: ShareCardShareOutcome.unavailable,
        message: message,
      );

  final ShareCardShareOutcome outcome;

  /// The rendered file, kept for a caller that wants to preview or re-share it.
  final File? file;

  /// A user-facing sentence, present only on failure.
  final String? message;

  bool get isFailure => message != null;

  bool get isShared => !isFailure && outcome.isShared;
}
