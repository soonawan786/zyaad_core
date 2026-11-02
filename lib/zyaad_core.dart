/// Shared domain logic for the Zyaad Islamic features.
///
/// Everything here is pure Dart with no plugin or platform dependency, so the
/// rules that matter — when a reminder fires, which way the Qibla is, when the
/// compass must be switched off — are unit-tested rather than eyeballed on a
/// device.
library;

export 'src/api/prayer_api.dart';
export 'src/features/sharing/sharing.dart';
export 'src/motion/motion_gate.dart';
export 'src/notifications/prayer_notification_channel.dart';
export 'src/notifications/prayer_notification_scheduler.dart';
export 'src/prayer/islamic_feature_settings.dart';
export 'src/prayer/prayer.dart';
export 'src/prayer/prayer_break.dart';
export 'src/prayer/prayer_day.dart';
export 'src/prayer/prayer_notification_planner.dart';
export 'src/prayer/prayer_time.dart';
export 'src/prayer_controller.dart';
export 'src/prayer_messages.dart';
export 'src/prayer_storage_keys.dart';
export 'src/qibla/qibla.dart';
export 'src/qibla/qibla_controller.dart';
export 'src/qibla/qibla_screen.dart';
export 'src/sensors/heading.dart';
export 'src/widgets/battery_optimisation_guide.dart';
export 'src/widgets/next_prayer_card.dart';
export 'src/widgets/prayer_settings_view.dart';
export 'src/widgets/prayer_stop_widgets.dart';
