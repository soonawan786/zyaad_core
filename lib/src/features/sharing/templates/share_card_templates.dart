import '../models/share_card_format.dart';
import '../models/share_card_template.dart';
import '../widgets/share_card.dart';

/// The template catalogue.
///
/// A registry rather than one widget per template, deliberately. Each of the three
/// treatments is the *same* layout with a different palette and type scale, so
/// three widget files would be three copies of the Arabic/translation/attribution
/// structure — and the citation rules that must never drift (reference verbatim,
/// source always shown) would then exist in triplicate.
///
/// Keeping the treatments as data means a fourth template is an entry here, not a
/// fourth copy of the layout, and the acceptance criteria for the card are
/// asserted once.
///
/// Branding stays the caller's: [ShareCard.brandName] and [ShareCard.logo] are
/// supplied by the host app, so this package never invents a mark.
class ShareCardTemplates {
  const ShareCardTemplates._();

  /// Every template, in the order a picker should offer them.
  static const List<ShareCardTemplate> all = <ShareCardTemplate>[
    ShareCardTemplate.classic,
    ShareCardTemplate.night,
    ShareCardTemplate.minimal,
  ];

  /// The template to start on for a format.
  ///
  /// Stories and Status are read against a dark UI, where a light card reads as a
  /// screenshot; a feed is usually read on a light timeline. The default therefore
  /// depends on where the card is going.
  static ShareCardTemplate defaultFor(ShareCardFormat format) =>
      format.isTall ? ShareCardTemplate.night : ShareCardTemplate.classic;
}
