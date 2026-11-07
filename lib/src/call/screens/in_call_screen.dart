import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../call_controller.dart';
import '../call_models.dart';

/// The in-call screen: mute, speaker, a running timer, end, and Report.
///
/// It renders [CallController] state only — there is no provider here, so the same
/// screen serves Agora, LiveKit, or anything added later.
class InCallScreen extends StatelessWidget {
  const InCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CallController>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.hangUp();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF111318),
        body: SafeArea(
          child: Obx(() {
            final status = controller.status.value;
            final failed = status == CallConnectionStatus.failed ||
                status == CallConnectionStatus.disconnected;
            final seconds = controller.elapsedSeconds.value;
            final time = '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
                '${(seconds % 60).toString().padLeft(2, '0')}';

            return Column(
              children: [
                const SizedBox(height: 40),
                Text(
                  _title(controller, failed),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(failed ? '' : time, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const Spacer(),
                if (failed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      controller.useChatFallback.value || controller.error.value == null
                          ? 'Call failed, use chat.'
                          : controller.error.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ),
                const Spacer(),
                _controls(context, controller, failed),
                const SizedBox(height: 40),
              ],
            );
          }),
        ),
      ),
    );
  }

  String _title(CallController controller, bool failed) {
    if (failed) return 'Call ended';
    switch (controller.status.value) {
      case CallConnectionStatus.connecting:
        return 'Connecting...';
      case CallConnectionStatus.reconnecting:
        return 'Reconnecting...';
      default:
        return 'On call';
    }
  }

  Widget _controls(BuildContext context, CallController controller, bool failed) {
    return Column(
      children: [
        if (!failed)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CircleButton(
                icon: controller.muted.value ? Icons.mic_off : Icons.mic,
                label: controller.muted.value ? 'Unmute' : 'Mute',
                background: Colors.white24,
                onTap: controller.toggleMute,
              ),
              _CircleButton(
                icon: controller.speaker.value ? Icons.volume_up : Icons.volume_down,
                label: controller.speaker.value ? 'Speaker' : 'Earpiece',
                background: Colors.white24,
                onTap: controller.toggleSpeaker,
              ),
            ],
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CircleButton(
              icon: Icons.flag_outlined,
              label: 'Report',
              background: Colors.white24,
              onTap: () => _showReport(controller),
            ),
            _CircleButton(
              icon: Icons.call_end,
              label: failed ? 'Close' : 'End',
              background: Colors.red,
              onTap: () async {
                await controller.hangUp();
                Get.back();
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showReport(CallController controller) {
    const reasons = <String>['Inappropriate behaviour', 'Noise or spam', 'Wrong person', 'Other'];
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report this call', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (final reason in reasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(reason),
                onTap: () async {
                  Get.back();
                  await controller.report(reason);
                  Get.snackbar('Report', 'Report received. Thank you.',
                      snackPosition: SnackPosition.BOTTOM);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

