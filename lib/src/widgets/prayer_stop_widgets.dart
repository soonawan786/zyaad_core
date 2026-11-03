import 'package:flutter/material.dart';

/// Who asked for the prayer stop, which decides the wording both sides see.
enum PrayerStopRequester { customer, driver }

/// The in-ride prayer-stop prompt, shared by both apps.
///
/// Either side may ask and the *other* side answers, so the same card renders in
/// both apps with only the wording changing. It is a card rather than a dialog on
/// purpose: a modal that steals the screen mid-navigation is exactly the kind of
/// interruption this feature should not be.
class PrayerStopRequestCard extends StatelessWidget {
  const PrayerStopRequestCard({
    super.key,
    required this.requestedBy,
    required this.onAccept,
    required this.onDecline,
    this.reason,
    this.waitingTimeLabel,
    this.isBusy = false,
  });

  final PrayerStopRequester requestedBy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// The free-text reason the requester gave, if any.
  final String? reason;

  /// A pre-formatted "12 minutes stopped, 2 chargeable" line, when the caller has
  /// it. Pricing is not decided here — this only displays what the API exposed.
  final String? waitingTimeLabel;

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final who = requestedBy == PrayerStopRequester.driver ? 'driver' : 'customer';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mosque_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The $who requested a prayer stop',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (reason != null && reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(reason!, style: theme.textTheme.bodySmall),
            ],
            if (waitingTimeLabel != null) ...[
              const SizedBox(height: 8),
              Text(waitingTimeLabel!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isBusy ? null : onDecline,
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isBusy ? null : onAccept,
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The "ask for a prayer stop" button, for either side.
///
/// It renders nothing when the caller says the feature is hidden or the trip is in
/// a state the backend refuses — the backend would refuse it anyway, and offering a
/// button that cannot work is worse than not offering it.
class RequestPrayerStopButton extends StatelessWidget {
  const RequestPrayerStopButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.isBusy = false,
    this.label = 'Request prayer stop',
  });

  final VoidCallback onPressed;
  final bool compact;
  final bool isBusy;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Text(label);

    if (compact) {
      return TextButton.icon(
        onPressed: isBusy ? null : onPressed,
        icon: const Icon(Icons.mosque_outlined, size: 18),
        label: text,
      );
    }

    return OutlinedButton.icon(
      onPressed: isBusy ? null : onPressed,
      icon: const Icon(Icons.mosque_outlined, size: 18),
      label: text,
    );
  }
}

/// Confirms before a prayer stop is requested, because it adds waiting time to the
/// trip and the person tapping should know that.
Future<bool> confirmPrayerStopRequest(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Request prayer stop'),
      content: const Text(
        'The driver will be asked to accept. Waiting time during the stop may be '
        'charged after the free grace period.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Ok'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

/// Whether the ride screen should offer the in-ride prayer stop.
///
/// [policy] is `data.policy` from `GET /api/v1/trips/{trip}/prayer-stop`: the
/// backend's own answer to "may this ride have a stop?". [userWantsIt] is the
/// rider's toggle. Both must agree, so the prompt can never appear on a ride the
/// API would refuse — and a rider who switched it off is never asked.
bool shouldOfferPrayerStop({
  required Map<String, dynamic>? policy,
  required bool userWantsIt,
}) {
  if (!userWantsIt || policy == null) return false;

  return policy['can_request'] == true;
}

/// The proactive in-ride prompt: "Do you want a prayer stop during this ride?"
///
/// Distinct from [RequestPrayerStopButton], which is the persistent action. This is
/// the *ask* the rider asked to be given, shown once per ride and dismissible.
class PrayerStopOfferCard extends StatelessWidget {
  const PrayerStopOfferCard({
    super.key,
    required this.onAccept,
    required this.onDismiss,
    this.isBusy = false,
  });

  final VoidCallback onAccept;
  final VoidCallback onDismiss;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mosque_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Do you want a prayer stop during this ride?',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'The driver will be asked to accept. Waiting time during the stop may '
              'be charged after the free grace period.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isBusy ? null : onDismiss,
                  child: const Text('Not now'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isBusy ? null : onAccept,
                  child: const Text('Yes, ask'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

