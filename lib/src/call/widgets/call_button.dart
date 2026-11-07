import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../call_controller.dart';
import '../screens/in_call_screen.dart';

/// The one call button both apps put on an active order. It knows nothing about the
/// provider — it asks [CallController] to start a session for an order and lets the
/// controller decide which SDK to bring up.
///
/// Use it in place of the old "dial the counterpart's phone number" button.
class CallButton extends StatelessWidget {
  const CallButton({
    super.key,
    required this.orderType,
    required this.orderId,
    this.icon = Icons.call,
    this.size = 24,
    this.color,
    this.showLabel = false,
    this.label = 'Call',
    this.child,
  });

  /// 'trip' for a ride/parcel, 'delivery' for a merchant delivery.
  final String orderType;

  /// The order/trip id the call belongs to.
  final String orderId;

  final IconData icon;
  final double size;
  final Color? color;
  final bool showLabel;
  final String label;

  /// Optional custom visual (e.g. the app's existing call icon asset). When null the
  /// button renders [icon].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CallController>();
    final tint = color ?? Theme.of(context).primaryColor;

    final visual = child ??
        (showLabel
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: size, color: tint),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: tint)),
              ])
            : Icon(icon, size: size, color: tint));

    return InkWell(
      onTap: () async {
        if (controller.isBusy) {
          return;
        }
        final ok = await controller.start(orderType: orderType, orderId: orderId);
        if (ok) {
          Get.to(() => const InCallScreen());
        } else if (controller.useChatFallback.value) {
          Get.snackbar('Call', 'Call failed, use chat.', snackPosition: SnackPosition.BOTTOM);
        } else if (controller.error.value != null) {
          Get.snackbar('Call', controller.error.value!, snackPosition: SnackPosition.BOTTOM);
        }
      },
      child: Padding(padding: const EdgeInsets.all(4), child: visual),
    );
  }
}
