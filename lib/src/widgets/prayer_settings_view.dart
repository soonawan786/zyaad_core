import 'package:flutter/material.dart';

import '../prayer/islamic_feature_settings.dart';
import '../prayer/prayer.dart';
import 'battery_optimisation_guide.dart';

/// The Islamic-feature settings screen, shared by both apps.
///
/// "Fully hideable" is taken literally: with the master switch off, only the master
/// switch is shown. Everything else — method, Asr, reminders, sound, lead time — is
/// hidden, and the caller hides the home card and the Qibla entry with it.
///
/// It is parameterised rather than reading a host-app controller, so the rider app
/// and the driver app share one screen and each wires its own persistence and sync.
class PrayerSettingsView extends StatelessWidget {
  const PrayerSettingsView({
    super.key,
    required this.settings,
    required this.scheduledReminders,
    required this.exactAlarmsGranted,
    required this.onToggleFeatures,
    required this.onToggleReminders,
    required this.onTogglePrayer,
    required this.onChangeCalculationMethod,
    required this.onChangeAsrMethod,
    required this.onChangeLeadMinutes,
    required this.onToggleSound,
    required this.onToggleSoundDuringRide,
    required this.onRequestExactAlarm,
    required this.onOpenBatterySettings,
    this.localeCode = 'en',
  });

  final IslamicFeatureSettings settings;
  final int scheduledReminders;
  final bool exactAlarmsGranted;

  final ValueChanged<bool> onToggleFeatures;
  final ValueChanged<bool> onToggleReminders;
  final void Function(Prayer prayer, bool enabled) onTogglePrayer;
  final ValueChanged<CalculationMethodOption?> onChangeCalculationMethod;
  final ValueChanged<AsrMethodOption?> onChangeAsrMethod;
  final ValueChanged<int> onChangeLeadMinutes;
  final ValueChanged<bool> onToggleSound;
  final ValueChanged<bool> onToggleSoundDuringRide;
  final VoidCallback onRequestExactAlarm;
  final VoidCallback onOpenBatterySettings;

  final String localeCode;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        SwitchListTile(
          title: const Text('Show Islamic features'),
          value: settings.islamicFeaturesEnabled,
          onChanged: onToggleFeatures,
        ),
        if (!settings.islamicFeaturesEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Prayer times, Qibla and reminders are hidden.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (settings.islamicFeaturesEnabled) ...[
          const Divider(),
          _MethodSection(
            settings: settings,
            onChangeCalculationMethod: onChangeCalculationMethod,
            onChangeAsrMethod: onChangeAsrMethod,
          ),
          const Divider(),
          _ReminderSection(
            settings: settings,
            localeCode: localeCode,
            onToggleReminders: onToggleReminders,
            onTogglePrayer: onTogglePrayer,
            onChangeLeadMinutes: onChangeLeadMinutes,
          ),
          const Divider(),
          _SoundSection(
            settings: settings,
            onToggleSound: onToggleSound,
            onToggleSoundDuringRide: onToggleSoundDuringRide,
          ),
          const Divider(),
          BatteryOptimisationGuide(onOpenSettings: onOpenBatterySettings),
          if (!exactAlarmsGranted)
            ListTile(
              leading: const Icon(Icons.alarm_on_outlined),
              title: const Text('Allow exact alarms'),
              subtitle: const Text(
                'Prayer reminders need the exact alarm permission to fire on time.',
              ),
              trailing: TextButton(
                onPressed: onRequestExactAlarm,
                child: const Text('Allow'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '$scheduledReminders reminders scheduled',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

class _MethodSection extends StatelessWidget {
  const _MethodSection({
    required this.settings,
    required this.onChangeCalculationMethod,
    required this.onChangeAsrMethod,
  });

  final IslamicFeatureSettings settings;
  final ValueChanged<CalculationMethodOption?> onChangeCalculationMethod;
  final ValueChanged<AsrMethodOption?> onChangeAsrMethod;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text('Calculation method'),
          subtitle: Text(settings.calculationMethod?.label ?? 'Follow city'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final choice = await _pick<CalculationMethodOption>(
              context,
              title: 'Calculation method',
              options: CalculationMethodOption.values,
              labelOf: (option) => option.label,
              selected: settings.calculationMethod,
            );

            if (choice == null) return;

            onChangeCalculationMethod(
              choice == followCitySentinel ? null : choice as CalculationMethodOption,
            );
          },
        ),
        ListTile(
          title: const Text('Asr method'),
          subtitle: Text(settings.asrMethod?.label ?? 'Follow city'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final choice = await _pick<AsrMethodOption>(
              context,
              title: 'Asr method',
              options: AsrMethodOption.values,
              labelOf: (option) => option.label,
              selected: settings.asrMethod,
            );

            if (choice == null) return;

            onChangeAsrMethod(
              choice == followCitySentinel ? null : choice as AsrMethodOption,
            );
          },
        ),
      ],
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.settings,
    required this.localeCode,
    required this.onToggleReminders,
    required this.onTogglePrayer,
    required this.onChangeLeadMinutes,
  });

  final IslamicFeatureSettings settings;
  final String localeCode;
  final ValueChanged<bool> onToggleReminders;
  final void Function(Prayer prayer, bool enabled) onTogglePrayer;
  final ValueChanged<int> onChangeLeadMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Azan reminders'),
          value: settings.azanRemindersEnabled,
          onChanged: onToggleReminders,
        ),
        if (settings.azanRemindersEnabled) ...[
          for (final prayer in Prayer.obligatory)
            SwitchListTile(
              dense: true,
              title: Text(prayer.label(localeCode)),
              value: settings.wantsReminder(prayer),
              onChanged: (value) => onTogglePrayer(prayer, value),
            ),
          ListTile(
            title: const Text('Remind me before'),
            subtitle: Text('${settings.reminderLeadMinutes} minutes before'),
            trailing: TextButton(
              onPressed: () => onChangeLeadMinutes(settings.nextLeadMinutes()),
              child: const Text('Change'),
            ),
          ),
        ],
      ],
    );
  }
}

class _SoundSection extends StatelessWidget {
  const _SoundSection({
    required this.settings,
    required this.onToggleSound,
    required this.onToggleSoundDuringRide,
  });

  final IslamicFeatureSettings settings;
  final ValueChanged<bool> onToggleSound;
  final ValueChanged<bool> onToggleSoundDuringRide;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Azan sound'),
          value: settings.azanSoundEnabled,
          onChanged: onToggleSound,
        ),
        if (settings.azanSoundEnabled)
          SwitchListTile(
            title: const Text('Play azan sound during a ride'),
            subtitle: const Text(
              'Off by default so the azan never plays over live navigation.',
            ),
            value: settings.azanSoundDuringRide,
            onChanged: onToggleSoundDuringRide,
          ),
      ],
    );
  }
}

/// The "follow the city" sentinel, so the sheet can offer a null choice without
/// fighting the generic type.
final Object followCitySentinel = Object();

Future<Object?> _pick<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T option) labelOf,
  required T? selected,
}) {
  return showModalBottomSheet<Object?>(
    context: context,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ListTile(
            title: const Text('Follow city'),
            trailing: selected == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(followCitySentinel),
          ),
          for (final option in options)
            ListTile(
              title: Text(labelOf(option)),
              trailing: selected == option ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    ),
  );
}

