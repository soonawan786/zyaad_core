import 'package:flutter/material.dart';

/// The in-app guide for the two Android settings that silently break reminders.
///
/// This is not decoration. On Xiaomi (MIUI/HyperOS), Oppo/Realme (ColorOS) and Vivo
/// (Funtouch/OriginOS) the default behaviour is to freeze background alarms: the
/// user switches reminders on, nothing ever arrives, and the app looks broken. The
/// exact-alarm permission has the same effect on stock Android 12+.
///
/// The guide names the vendor setting to look for rather than only opening a system
/// screen, because the path differs per OEM and users cannot find it otherwise.
class BatteryOptimisationGuide extends StatelessWidget {
  const BatteryOptimisationGuide({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  /// The vendor-specific paths, which is what the user actually has to find.
  static const String vendorHint =
      'Xiaomi: Settings > Apps > Manage apps > this app > Battery saver > No restrictions.\n'
      'Oppo/Realme: Settings > Battery > App battery management > allow background activity.\n'
      'Vivo: Settings > Battery > Background power consumption management > allow.';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.battery_alert_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Keep reminders working',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Some phones stop background alarms. Allow this app to run in the '
              'background and turn off battery optimisation for it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(
              vendorHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
            if (onOpenSettings != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onOpenSettings,
                  child: const Text('Open settings'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
