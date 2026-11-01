import 'package:flutter_test/flutter_test.dart';
import 'package:zyaad_core/zyaad_core.dart';

/*
|--------------------------------------------------------------------------
| Islamic feature settings
|--------------------------------------------------------------------------
*/

void main() {
  group('defaults', () {
    test('are on, with every prayer reminding and no sound', () {
      const settings = IslamicFeatureSettings();

      expect(settings.islamicFeaturesEnabled, isTrue);
      expect(settings.hidden, isFalse);
      expect(settings.azanRemindersEnabled, isTrue);
      expect(settings.reminderLeadMinutes, 10);
      expect(settings.calculationMethod, isNull);
      expect(settings.asrMethod, isNull);
      expect(settings.azanSoundEnabled, isFalse);
      expect(settings.azanSoundDuringRide, isFalse);

      for (final prayer in Prayer.obligatory) {
        expect(settings.wantsReminder(prayer), isTrue);
      }
    });

    test('sunrise is never remindable even if a stale map says so', () {
      final settings = const IslamicFeatureSettings().withReminder(Prayer.sunrise, true);

      expect(settings.wantsReminder(Prayer.sunrise), isFalse);
    });
  });

  group('the master toggle', () {
    test('hides everything', () {
      const settings = IslamicFeatureSettings(islamicFeaturesEnabled: false);

      expect(settings.hidden, isTrue);

      for (final prayer in Prayer.obligatory) {
        expect(settings.wantsReminder(prayer), isFalse);
      }
    });

    test('can be turned back on', () {
      final settings = const IslamicFeatureSettings(islamicFeaturesEnabled: false)
          .copyWith(islamicFeaturesEnabled: true);

      expect(settings.hidden, isFalse);
      expect(settings.wantsReminder(Prayer.fajr), isTrue);
    });
  });

  group('the reminders master', () {
    test('off silences every prayer but keeps the individual choices', () {
      const settings = IslamicFeatureSettings(azanRemindersEnabled: false);

      expect(settings.wantsReminder(Prayer.fajr), isFalse);
      expect(settings.reminders[Prayer.fajr], isTrue);

      // Turning it back on restores what the user had chosen.
      expect(settings.copyWith(azanRemindersEnabled: true).wantsReminder(Prayer.fajr), isTrue);
    });
  });

  group('per-prayer toggles', () {
    test('a missing entry defaults to on', () {
      const settings = IslamicFeatureSettings(reminders: {});

      expect(settings.wantsReminder(Prayer.isha), isTrue);
    });

    test('withReminder only changes the prayer it names', () {
      final settings = const IslamicFeatureSettings().withReminder(Prayer.asr, false);

      expect(settings.wantsReminder(Prayer.asr), isFalse);
      expect(settings.wantsReminder(Prayer.fajr), isTrue);
      expect(settings.wantsReminder(Prayer.maghrib), isTrue);
    });
  });

  group('lead minutes', () {
    test('cycles through the offered values', () {
      expect(const IslamicFeatureSettings(reminderLeadMinutes: 10).nextLeadMinutes(), 15);
      expect(const IslamicFeatureSettings(reminderLeadMinutes: 30).nextLeadMinutes(), 0);
    });

    test('an unlisted value restarts the cycle', () {
      expect(const IslamicFeatureSettings(reminderLeadMinutes: 7).nextLeadMinutes(), 0);
    });
  });

  group('sound', () {
    test('off by default, on when asked for, and off during a ride', () {
      expect(const IslamicFeatureSettings().soundFor(rideActive: false), isFalse);

      const withSound = IslamicFeatureSettings(azanSoundEnabled: true);
      expect(withSound.soundFor(rideActive: false), isTrue);
      expect(withSound.soundFor(rideActive: true), isFalse);
    });

    test('an explicit opt-in allows sound during a ride', () {
      const settings = IslamicFeatureSettings(
        azanSoundEnabled: true,
        azanSoundDuringRide: true,
      );

      expect(settings.soundFor(rideActive: true), isTrue);
    });
  });

  group('serialisation', () {
    test('toApiJson sends exactly the fields the backend owns', () {
      const settings = IslamicFeatureSettings(
        islamicFeaturesEnabled: true,
        calculationMethod: CalculationMethodOption.jafari,
        asrMethod: AsrMethodOption.standard,
        azanRemindersEnabled: true,
        reminderLeadMinutes: 15,
        azanSoundEnabled: true,
        azanSoundDuringRide: true,
      );

      final json = settings.toApiJson();

      expect(json['islamic_features_enabled'], isTrue);
      expect(json['calculation_method'], 'jafari');
      expect(json['asr_method'], 'standard');
      expect(json['azan_reminders_enabled'], isTrue);
      expect(json['reminder_lead_minutes'], 15);
      expect((json['reminders'] as Map)['fajr'], isTrue);

      // The sound preferences are device-only and must not be sent.
      expect(json.containsKey('azan_sound_enabled'), isFalse);
      expect(json.containsKey('azan_sound_during_ride'), isFalse);
    });

    test('fromApi keeps the locally stored sound preferences', () {
      const local = IslamicFeatureSettings(
        azanSoundEnabled: true,
        azanSoundDuringRide: true,
      );

      final settings = IslamicFeatureSettings.fromApi({
        'islamic_features_enabled': true,
        'calculation_method': 'karachi',
        'asr_method': 'hanafi',
        'azan_reminders_enabled': true,
        'reminder_lead_minutes': 20,
        'reminders': {
          'fajr': false,
          'dhuhr': true,
          'asr': true,
          'maghrib': true,
          'isha': false,
        },
      }, local: local);

      expect(settings.calculationMethod, CalculationMethodOption.karachi);
      expect(settings.asrMethod, AsrMethodOption.hanafi);
      expect(settings.reminderLeadMinutes, 20);
      expect(settings.wantsReminder(Prayer.fajr), isFalse);
      expect(settings.wantsReminder(Prayer.isha), isFalse);
      expect(settings.wantsReminder(Prayer.dhuhr), isTrue);

      // Local-only values survive the server round trip.
      expect(settings.azanSoundEnabled, isTrue);
      expect(settings.azanSoundDuringRide, isTrue);
    });

    test('an unknown method from the server falls back to "follow the city"', () {
      final settings = IslamicFeatureSettings.fromApi({
        'calculation_method': 'something_new',
        'asr_method': '',
      });

      expect(settings.calculationMethod, isNull);
      expect(settings.asrMethod, isNull);
    });

    test('toJson / fromJson round-trips everything', () {
      const original = IslamicFeatureSettings(
        islamicFeaturesEnabled: false,
        calculationMethod: CalculationMethodOption.ummAlQura,
        asrMethod: AsrMethodOption.standard,
        azanRemindersEnabled: false,
        reminders: {Prayer.fajr: false, Prayer.isha: false},
        reminderLeadMinutes: 30,
        azanSoundEnabled: true,
        azanSoundDuringRide: true,
      );

      final restored = IslamicFeatureSettings.fromJson(original.toJson());

      expect(restored.islamicFeaturesEnabled, isFalse);
      expect(restored.calculationMethod, CalculationMethodOption.ummAlQura);
      expect(restored.asrMethod, AsrMethodOption.standard);
      expect(restored.azanRemindersEnabled, isFalse);
      expect(restored.reminderLeadMinutes, 30);
      expect(restored.reminders[Prayer.fajr], isFalse);
      expect(restored.reminders[Prayer.isha], isFalse);
      expect(restored.azanSoundEnabled, isTrue);
      expect(restored.azanSoundDuringRide, isTrue);
    });

    test('an empty map still yields usable defaults', () {
      final settings = IslamicFeatureSettings.fromJson(const {});

      expect(settings.islamicFeaturesEnabled, isTrue);
      expect(settings.reminderLeadMinutes, 10);
      expect(settings.wantsReminder(Prayer.fajr), isTrue);
    });
  });

  group('clearing an override', () {
    test('copyWith can return a field to "follow the city"', () {
      const settings = IslamicFeatureSettings(
        calculationMethod: CalculationMethodOption.jafari,
        asrMethod: AsrMethodOption.standard,
      );

      final cleared = settings.copyWith(clearCalculationMethod: true, clearAsrMethod: true);

      expect(cleared.calculationMethod, isNull);
      expect(cleared.asrMethod, isNull);
    });
  });
}

