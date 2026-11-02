import 'package:flutter/material.dart';

import '../models/share_card_content.dart';
import '../models/share_card_format.dart';
import '../models/share_card_template.dart';
import '../services/share_card_service.dart';
import 'share_card_sheet.dart';

/// Opens the share sheet for a card.
///
/// The conventional Flutter entry point: one call, no state to own, returns when
/// the sheet closes.
///
/// ```dart
/// final item = controller.todayAyah;            // from the API
/// final result = await showShareCardSheet(
///   context: context,
///   content: ShareCardContent.fromApiItem(item),
///   service: Get.find<ShareCardService>(),
/// );
/// if (result != null && result.isFailure) { /* show result.message */ }
/// ```
///
/// Returns null when the user dismissed the sheet without sharing. A failure is
/// returned rather than shown here, so the caller decides how to surface it.
Future<ShareCardShareResult?> showShareCardSheet({
  required BuildContext context,
  required ShareCardContent content,
  required ShareCardService service,
  ShareCardFormat? initialFormat,
  ShareCardTemplate? initialTemplate,
  ShareCardTranslationLanguage leadingLanguage =
      ShareCardTranslationLanguage.urdu,
  String brandName = 'Zyaad',
  Widget? logo,
}) {
  return showModalBottomSheet<ShareCardShareResult>(
    context: context,
    // The sheet is tall (a 4:5 preview plus two pickers). `isScrollControlled` plus
    // a bounded height is the standard way to let it size itself on a small screen
    // without the preview being clipped.
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => ShareCardSheet(
      content: content,
      service: service,
      initialFormat: initialFormat ?? ShareCardFormat.portrait,
      initialTemplate: initialTemplate,
      leadingLanguage: leadingLanguage,
      brandName: brandName,
      logo: logo,
    ),
  );
}

/// A button that opens the share sheet.
///
/// Exists so the iPad origin is never forgotten. On iPad the share sheet is a
/// popover and iOS needs a rectangle to anchor it to; the button measures itself
/// and passes that down, which is the one thing a caller would otherwise have to
/// remember at every call site.
class ShareCardButton extends StatelessWidget {
  const ShareCardButton({
    super.key,
    required this.content,
    required this.service,
    this.label = 'Share',
    this.icon = Icons.ios_share,
    this.format,
    this.template,
    this.leadingLanguage = ShareCardTranslationLanguage.urdu,
    this.brandName = 'Zyaad',
    this.logo,
    this.onResult,
  });

  final ShareCardContent content;
  final ShareCardService service;
  final String label;
  final IconData icon;
  final ShareCardFormat? format;
  final ShareCardTemplate? template;
  final ShareCardTranslationLanguage leadingLanguage;
  final String brandName;
  final Widget? logo;

  /// Called with the outcome when the sheet closes. Optional: the sheet already
  /// shows its own error state, so a caller that only wants the happy path can
  /// ignore this.
  final ValueChanged<ShareCardShareResult?>? onResult;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () async {
        final result = await showShareCardSheet(
          context: context,
          content: content,
          service: service,
          initialFormat: format,
          initialTemplate: template,
          leadingLanguage: leadingLanguage,
          brandName: brandName,
          logo: logo,
        );

        onResult?.call(result);
      },
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
