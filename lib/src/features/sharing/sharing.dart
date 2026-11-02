/// Shareable ayah/hadith cards.
///
/// Renders one verse or narration from the daily-content API as a 1080-wide PNG
/// and hands it to the OS share sheet. Text, reference, source and attribution all
/// come from the API payload and are never composed here — see
/// [ShareCardContent], which refuses to build without a citation.
///
/// Typical use:
///
/// ```dart
/// final content = ShareCardContent.fromApiItem(item);
/// final result = await ShareCardService().share(
///   context: context,
///   content: content,
///   format: ShareCardFormat.story,
///   origin: shareOriginOf(buttonContext), // required on iPad
/// );
/// ```
library;

export 'models/share_card_content.dart';
export 'models/share_card_format.dart';
export 'models/share_card_template.dart';
export 'rendering/share_card_file_store.dart';
export 'rendering/share_card_renderer.dart';
export 'services/share_card_service.dart';
export 'services/share_card_sharer.dart';
export 'templates/share_card_templates.dart';
export 'widgets/share_card.dart';
export 'widgets/share_card_button.dart';
export 'widgets/share_card_preview.dart';
export 'widgets/share_card_sheet.dart';
