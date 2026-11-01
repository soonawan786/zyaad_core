import 'prayer.dart';

/// The twilight conventions the API accepts. Mirrors the backend enum exactly.
enum CalculationMethodOption {
  karachi('karachi', 'University of Islamic Sciences, Karachi'),
  jafari('jafari', 'Shia Ithna-Ashari (Jafari)'),
  muslimWorldLeague('muslim_world_league', 'Muslim World League'),
  egyptian('egyptian', 'Egyptian General Authority of Survey'),
  ummAlQura('umm_al_qura', 'Umm al-Qura University, Makkah'),
  northAmerica('north_america', 'Islamic Society of North America (ISNA)'),
  kuwait('kuwait', 'Kuwait'),
  qatar('qatar', 'Qatar'),
  singapore('singapore', 'Majlis Ugama Islam Singapura'),
  turkey('turkey', 'Diyanet İşleri Başkanlığı (Turkey)'),
  dubai('dubai', 'Dubai'),
  custom('custom', 'Custom (admin defined)');

  const CalculationMethodOption(this.key, this.label);

  final String key;
  final String label;

  static CalculationMethodOption? tryParse(String? key) {
    if (key == null || key.isEmpty) return null;

    for (final option in values) {
      if (option.key == key) return option;
    }

    return null;
  }
}

/// Asr is defined by the length of an object's shadow.
enum AsrMethodOption {
  hanafi('hanafi', 'Hanafi'),
  standard('standard', 'Standard (Shafi\'i, Maliki, Hanbali)');

  const AsrMethodOption(this.key, this.label);

  final String key;
  final String label;

  static AsrMethodOption? tryParse(String? key) {
    if (key == null || key.isEmpty) return null;

    for (final option in values) {
      if (option.key == key) return option;
    }

    return null;
  }
}

/// The user's Islamic-feature switches.
///
/// Two of these are **device-only** — [azanSoundEnabled] and
/// [azanSoundDuringRide] — because the server has no opinion about whether this
/// handset should make a noise. They are persisted locally and deliberately
/// excluded from [toApiJson].
class IslamicFeatureSettings {
  const IslamicFeatureSettings({
    this.islamicFeaturesEnabled = true,
    this.calculationMethod,
    this.asrMethod,
    this.azanRemindersEnabled = true,
    this.reminders = const {
      Prayer.fajr: true,
      Prayer.dhuhr: true,
      Prayer.asr: true,
      Prayer.maghrib: true,
      Prayer.isha: true,
    },
    this.reminderLeadMinutes = 10,
    this.azanSoundEnabled = false,
    this.azanSoundDuringRide = false,
  });

  /// The master switch. Off means the app hides every Islamic surface, and the
  /// notification planner returns an empty plan.
  final bool islamicFeaturesEnabled;

  /// null means "follow the city".
  final CalculationMethodOption? calculationMethod;
  final AsrMethodOption? asrMethod;

  final bool azanRemindersEnabled;

  /// Per-prayer toggles. A missing prayer defaults to on.
  final Map<Prayer, bool> reminders;

  final int reminderLeadMinutes;

  /// Device-only: play a short azan sound with the notification.
  final bool azanSoundEnabled;

  /// Device-only: allow that sound while a ride is active. Off by default — a loud
  /// azan over a live navigation prompt is worse than a silent reminder.
  final bool azanSoundDuringRide;

  /// The lead times the settings screen offers.
  static const List<int> leadMinuteOptions = [0, 5, 10, 15, 20, 30];

  /// Everything off, which is what a hidden section looks like.
  bool get hidden => !islamicFeaturesEnabled;

  /// Whether the user wants a reminder for [prayer]. Sunrise is never remindable.
  bool wantsReminder(Prayer prayer) {
    if (hidden || !azanRemindersEnabled || !prayer.isRemindable) return false;

    return reminders[prayer] ?? true;
  }

  /// Whether the notification should carry the azan sound.
  ///
  /// Requirement: never autoplay loud audio while a ride is active unless the user
  /// explicitly allowed it.
  bool soundFor({required bool rideActive}) {
    if (!azanSoundEnabled) return false;
    if (rideActive) return azanSoundDuringRide;

    return true;
  }

  /// The next lead time in the cycle, for the settings stepper.
  int nextLeadMinutes() {
    final index = leadMinuteOptions.indexOf(reminderLeadMinutes);

    if (index < 0 || index >= leadMinuteOptions.length - 1) {
      return leadMinuteOptions.first;
    }

    return leadMinuteOptions[index + 1];
  }

  IslamicFeatureSettings copyWith({
    bool? islamicFeaturesEnabled,
    CalculationMethodOption? calculationMethod,
    bool clearCalculationMethod = false,
    AsrMethodOption? asrMethod,
    bool clearAsrMethod = false,
    bool? azanRemindersEnabled,
    Map<Prayer, bool>? reminders,
    int? reminderLeadMinutes,
    bool? azanSoundEnabled,
    bool? azanSoundDuringRide,
  }) {
    return IslamicFeatureSettings(
      islamicFeaturesEnabled: islamicFeaturesEnabled ?? this.islamicFeaturesEnabled,
      calculationMethod:
          clearCalculationMethod ? null : (calculationMethod ?? this.calculationMethod),
      asrMethod: clearAsrMethod ? null : (asrMethod ?? this.asrMethod),
      azanRemindersEnabled: azanRemindersEnabled ?? this.azanRemindersEnabled,
      reminders: reminders ?? this.reminders,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      azanSoundEnabled: azanSoundEnabled ?? this.azanSoundEnabled,
      azanSoundDuringRide: azanSoundDuringRide ?? this.azanSoundDuringRide,
    );
  }

  IslamicFeatureSettings withReminder(Prayer prayer, bool enabled) =>
      copyWith(reminders: {...reminders, prayer: enabled});

  /// The fields the API owns. Device-only preferences are not sent.
  Map<String, dynamic> toApiJson() => {
        'islamic_features_enabled': islamicFeaturesEnabled,
        'calculation_method': calculationMethod?.key,
        'asr_method': asrMethod?.key,
        'azan_reminders_enabled': azanRemindersEnabled,
        'reminder_lead_minutes': reminderLeadMinutes,
        'reminders': {
          for (final prayer in Prayer.obligatory) prayer.key: wantsReminder(prayer),
        },
      };

  /// Everything, for local persistence.
  Map<String, dynamic> toJson() => {
        ...toApiJson(),
        'azan_sound_enabled': azanSoundEnabled,
        'azan_sound_during_ride': azanSoundDuringRide,
      };

  /// Builds settings from the API payload (`data` of `GET /api/v1/prayer-settings`),
  /// keeping the locally stored sound preferences.
  static IslamicFeatureSettings fromApi(
    Map<String, dynamic> data, {
    IslamicFeatureSettings? local,
  }) {
    return _fromMap(
      data,
      azanSoundEnabled: local?.azanSoundEnabled ?? false,
      azanSoundDuringRide: local?.azanSoundDuringRide ?? false,
    );
  }

  /// Reads settings back out of local storage.
  static IslamicFeatureSettings fromJson(Map<String, dynamic> json) => _fromMap(
        json,
        azanSoundEnabled: json['azan_sound_enabled'] is bool
            ? json['azan_sound_enabled'] as bool
            : false,
        azanSoundDuringRide: json['azan_sound_during_ride'] is bool
            ? json['azan_sound_during_ride'] as bool
            : false,
      );

  static IslamicFeatureSettings _fromMap(
    Map<String, dynamic> json, {
    required bool azanSoundEnabled,
    required bool azanSoundDuringRide,
  }) {
    final rawReminders = json['reminders'];
    final lead = json['reminder_lead_minutes'];

    return IslamicFeatureSettings(
      islamicFeaturesEnabled: json['islamic_features_enabled'] is bool
          ? json['islamic_features_enabled'] as bool
          : true,
      calculationMethod: CalculationMethodOption.tryParse(
        json['calculation_method'] is String ? json['calculation_method'] as String : null,
      ),
      asrMethod: AsrMethodOption.tryParse(
        json['asr_method'] is String ? json['asr_method'] as String : null,
      ),
      azanRemindersEnabled:
          json['azan_reminders_enabled'] is bool ? json['azan_reminders_enabled'] as bool : true,
      reminders: {
        for (final prayer in Prayer.obligatory)
          prayer: rawReminders is Map
              ? (rawReminders[prayer.key] is bool ? rawReminders[prayer.key] as bool : true)
              : true,
      },
      reminderLeadMinutes: lead is num ? lead.toInt() : 10,
      azanSoundEnabled: azanSoundEnabled,
      azanSoundDuringRide: azanSoundDuringRide,
    );
  }
}

