import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../call_controller.dart';
import '../call_models.dart';
import 'in_call_screen.dart';

/// Full-screen incoming-call UI. Shows only the ROLE ("Driver calling"), never a
/// name or a number. Works for both a foreground Reverb ring and a background FCM
/// ring, because both only set [CallController] state and push this route.
class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CallController>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.decline();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF111318),
        body: SafeArea(
          child: Obx(() {
            return Column(
              children: [
                const Spacer(),
                const Icon(Icons.account_circle, color: Colors.white38, size: 96),
                const SizedBox(height: 20),
                Text(
                  _who(controller.callerRole.value),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('Incoming call', style: TextStyle(color: Colors.white70, fontSize: 15)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RingAction(
                      icon: Icons.call_end,
                      label: 'Decline',
                      background: Colors.red,
                      onTap: () async {
                        await controller.decline();
                        Get.back();
                      },
                    ),
                    _RingAction(
                      icon: Icons.call,
                      label: 'Accept',
                      background: Colors.green,
                      onTap: () async {
                        final ok = await controller.accept();
                        if (ok) {
                          Get.off(() => const InCallScreen());
                        } else {
                          Get.back();
                          Get.snackbar('Call', 'Call failed, use chat.',
                              snackPosition: SnackPosition.BOTTOM);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 64),
              ],
            );
          }),
        ),
      ),
    );
  }

  String _who(CallRole role) {
    switch (role) {
      case CallRole.driver:
        return 'Driver calling';
      case CallRole.customer:
        return 'Customer calling';
      case CallRole.receiver:
        return 'Receiver calling';
      default:
        return 'Someone is calling';
    }
  }
}

class _RingAction extends StatelessWidget {
  const _RingAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
