import 'package:flutter/material.dart';

import '../models/share_card_content.dart';
import '../models/share_card_format.dart';
import '../models/share_card_template.dart';
import '../services/share_card_service.dart';
import '../templates/share_card_templates.dart';
import 'share_card_preview.dart';

/// The share flow: preview, format, treatment, share.
///
/// A `StatefulWidget` rather than a controller, because everything it owns —
/// the chosen format, the chosen template, the in-flight flag, the error — lives
/// and dies with the sheet. Pushing that into the app's DI would leave stale state
/// behind every time a user closed and reopened it.
///
/// Opened through [showShareCardSheet] rather than constructed directly.
class ShareCardSheet extends StatefulWidget {
  const ShareCardSheet({
    super.key,
    required this.content,
    required this.service,
    this.initialFormat = ShareCardFormat.portrait,
    this.initialTemplate,
    this.leadingLanguage = ShareCardTranslationLanguage.urdu,
    this.brandName = 'Zyaad',
    this.logo,
  });

  final ShareCardContent content;
  final ShareCardService service;
  final ShareCardFormat initialFormat;

  /// Defaults to the treatment that suits [initialFormat] — a Story is read
  /// against a dark UI, a feed against a light timeline.
  final ShareCardTemplate? initialTemplate;

  final ShareCardTranslationLanguage leadingLanguage;
  final String brandName;
  final Widget? logo;

  @override
  State<ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<ShareCardSheet> {
  /// Measures the share button, so the iPad popover has something to anchor to.
  final GlobalKey _shareKey = GlobalKey();

  late ShareCardFormat _format = widget.initialFormat;
  late ShareCardTemplate _template =
      widget.initialTemplate ?? ShareCardTemplates.defaultFor(widget.initialFormat);

  bool _busy = false;
  String? _error;

  Future<void> _share() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await widget.service.share(
      context: context,
      content: widget.content,
      format: _format,
      template: _template,
      leadingLanguage: widget.leadingLanguage,
      brandName: widget.brandName,
      logo: widget.logo,
      origin: shareOriginOf(_shareKey.currentContext ?? context),
    );

    if (!mounted) {
      // The user closed the sheet while the render was in flight. Nothing to
      // update, and touching setState here would throw.
      return;
    }

    setState(() {
      _busy = false;
      _error = result.isFailure ? result.message : null;
    });

    if (result.isShared) {
      // Only a completed share closes the sheet. A dismissal means the user
      // changed their mind about the destination, not about the card, so the
      // sheet stays open for another attempt.
      Navigator.of(context).pop(result);
    }
  }

  void _setFormat(ShareCardFormat format) {
    setState(() {
      _format = format;

      // A template chosen for a feed is usually wrong for a Story, so re-apply the
      // format's default unless the user had already picked one for this format.
      if (widget.initialTemplate == null) {
        _template = ShareCardTemplates.defaultFor(format);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: ShareCardPreview(
                content: widget.content,
                format: _format,
                template: _template,
                leadingLanguage: widget.leadingLanguage,
                brandName: widget.brandName,
                logo: widget.logo,
                isBusy: _busy,
                errorMessage: _error,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FormatPicker(
            value: _format,
            enabled: !_busy,
            onChanged: _setFormat,
          ),
          const SizedBox(height: 10),
          _TemplatePicker(
            value: _template,
            enabled: !_busy,
            onChanged: (template) => setState(() => _template = template),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: _shareKey,
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text(_busy ? 'Preparing…' : 'Share'),
          ),
          const SizedBox(height: 4),
          Text(
            // Stated rather than implied: the caption carries the reference and the
            // source, and a user should know that before sending.
            'The image includes the Arabic, the translation, the reference and the source.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Portrait or Story.
///
/// Labelled by where the card is going rather than by its dimensions, because
/// "1080×1350" means nothing to the person choosing.
class _FormatPicker extends StatelessWidget {
  const _FormatPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ShareCardFormat value;
  final bool enabled;
  final ValueChanged<ShareCardFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ShareCardFormat>(
      segments: <ButtonSegment<ShareCardFormat>>[
        ButtonSegment<ShareCardFormat>(
          value: ShareCardFormat.portrait,
          icon: const Icon(Icons.crop_landscape, size: 16),
          label: const Text('Post'),
          tooltip: ShareCardFormat.portrait.label,
        ),
        ButtonSegment<ShareCardFormat>(
          value: ShareCardFormat.story,
          icon: const Icon(Icons.crop_portrait, size: 16),
          label: const Text('Story'),
          tooltip: ShareCardFormat.story.label,
        ),
      ],
      selected: <ShareCardFormat>{value},
      onSelectionChanged: enabled
          ? (selection) => onChanged(selection.first)
          : null,
      showSelectedIcon: false,
    );
  }
}

/// The three treatments.
class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ShareCardTemplate value;
  final bool enabled;
  final ValueChanged<ShareCardTemplate> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ShareCardTemplate>(
      segments: <ButtonSegment<ShareCardTemplate>>[
        for (final template in ShareCardTemplates.all)
          ButtonSegment<ShareCardTemplate>(
            value: template,
            label: Text(template.label),
          ),
      ],
      selected: <ShareCardTemplate>{value},
      onSelectionChanged: enabled
          ? (selection) => onChanged(selection.first)
          : null,
      showSelectedIcon: false,
    );
  }
}
