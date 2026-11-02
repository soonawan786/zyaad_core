# zyaad_core

Shared, platform-free domain logic for the Zyaad Islamic features: prayer-time
models, the local-notification schedule planner, Qibla bearing, the
tilt-compensated compass heading, the motion gate and the driver prayer-break timer.

Pure Dart (no Flutter dependency) so every rule can be unit-tested without a
device, and so `user_app` and `driver_app` share one implementation.

```
dart test
dart analyze
```

133 tests, analyzer clean.

**Consumed by the apps** from a pinned tag:

```yaml
zyaad_core:
  git:
    url: https://github.com/soonawan786/zyaad_core.git
    ref: v1.0.0
```

See [INTEGRATION.md](INTEGRATION.md) for the release process, the local-development
override, and the things that will bite you (the single notifications plugin
instance, the per-app manifest entries, and why the break-timer tests live here
rather than in the driver app).

## Package choices, and the checks behind them

The brief was explicit: check current compatibility before choosing, and say if
unsure. What was actually verified (on 2026-11-01, against the app's toolchain —
**Flutter 3.44.9 / Dart 3.12.2** — and the resolved `pubspec.lock`):

### Local notifications — `flutter_local_notifications: ^22.0.1` (already a dependency)

* latest is **22.3.3**; the apps pin `^22.0.1` and the lock resolves 22.0.1/22.3.3.
* v21 (and therefore v22) requires **Flutter >= 3.38.1 / Dart >= 3.10.0** — the
  toolchain is 3.44.9 / 3.12.2, so this is satisfied.
* its Android module declares `namespace` and `compileSdk 36`, `minSdk 24`, so it
  builds against the AGP 8.x these apps use.
* the API used here was read from the package source, not from memory:
  `initialize({required InitializationSettings settings, ...})`,
  `zonedSchedule({required int id, required TZDateTime scheduledDate,
  required NotificationDetails notificationDetails,
  required AndroidScheduleMode androidScheduleMode, ...})`,
  `AndroidScheduleMode.{exactAllowWhileIdle, inexactAllowWhileIdle}`,
  `AndroidFlutterLocalNotificationsPlugin.{requestNotificationsPermission,
  requestExactAlarmsPermission, canScheduleExactNotifications}`.
* the manifest requirements were taken from its README: `RECEIVE_BOOT_COMPLETED`
  plus `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver`.

### Timezone — `timezone: ^0.11.0` (declared directly)

Already present **transitively** (`flutter_local_notifications` depends on
`timezone: ^0.11.0`; the lock resolves 0.11.0). Declared directly because the code
uses it for `TZDateTime` conversion. Latest is 0.11.2 (`sdk: ^3.10.0`), compatible.

Note: the device's own timezone is deliberately **not** read. Every reminder is
converted from the absolute instant the API returns using the *city's* IANA zone
from the same payload, so a user travelling abroad is still reminded at the right
moment, and a device timezone change cannot shift a reminder.

### Compass — `sensors_plus: ^7.1.1` + our own fusion

This is the one place a judgement call was needed, so here is the evidence.

| package | latest | sdk | flutter | published | verdict |
| --- | --- | --- | --- | --- | --- |
| `flutter_compass` | 0.8.1 | `>=2.12.0 <4.0.0` | `>=1.10.0` | 2024-11-17 | **rejected** |
| `flutter_compass_v2` | 1.0.3 | `>=2.12.0 <4.0.0` | `>=1.10.0` | 2024-03-28 | rejected |
| `compassx` | 1.0.1 | `>=3.0.0 <4.0.0` | `>=3.3.0` | 2024-05-16 | rejected |
| `precise_compass` | 0.2.0 | `^3.12.0` | `>=3.44.0` | 2026-08-31 | too new/niche |
| `heading_sensor` | 0.1.0 | `^3.5.0` | `>=3.24.0` | 2026-09-29 | too new/niche |
| `sensors_plus` | 7.1.1 | `>=3.3.0 <4.0.0` | `>=3.19.0` | 2026-10-01 | **chosen** |

`flutter_compass` is the mature option and its SDK constraint would technically
resolve, but its Android module still ships
`buildscript { classpath 'com.android.tools.build:gradle:4.1.1' }` with
`compileSdkVersion 34` and a `lintOptions` block — a build risk against the AGP 8.x
these apps use, and its last release is nearly two years old. The newer
alternatives are all either 0.1.0/0.2.0 or depend on a single maintainer.

`sensors_plus` is the fluttercommunity plugin (published 2026-10-01, matched SDK
constraints) and gives raw `magnetometerEventStream()` and
`accelerometerEventStream()`. The tilt-compensated heading is therefore ours
(`HeadingCalculator`), which has a real upside: it is unit-tested with synthetic
sensor vectors (`test/heading_test.dart` builds the forward problem from a known
attitude and asserts the heading is recovered at every yaw, and at pitch/roll).

**The trade-off, stated plainly:** we do not get the OS-fused rotation-vector
heading, so we own the calibration warning. `HeadingCalculator.qualityForField`
flags a field below 20 µT (unusable) or above 100 µT (a magnet nearby — show
"move your phone in a figure 8"). This is a heuristic on field strength, not a
calibration-accuracy reading from the sensor framework. If a hardware-accuracy
signal is wanted later, `sensors_plus` does not expose one and a different plugin
would be needed.

## What is where

| file | what it owns |
| --- | --- |
| `src/prayer/prayer.dart` | the six timestamps, English/Urdu labels, sunrise is never a reminder |
| `src/prayer/prayer_time.dart` | one prayer's absolute instant + city wall clock |
| `src/prayer/prayer_day.dart` | one day, the next prayer, the Ramadan window |
| `src/prayer/islamic_feature_settings.dart` | the user's switches; the two sound flags are device-only and never sent to the server |
| `src/prayer/prayer_notification_planner.dart` | which notifications to hold, and the deterministic id space |
| `src/prayer/prayer_break.dart` | the driver break countdown and the daily allowance |
| `src/qibla/qibla.dart` | great-circle bearing/distance to the Kaaba, relative bearing |
| `src/sensors/heading.dart` | tilt-compensated heading, calibration quality, smoothing |
| `src/motion/motion_gate.dart` | the "stop to use the compass" speed gate (with hysteresis) |

## Qibla reference values

`test/qibla_test.dart` asserts the bearing for 13 cities within one degree against
the published directions from an independent source (the Aladhan API's `/qibla`
endpoint), e.g. Lahore 260.31°, Karachi 267.74°, London 118.99°, New York 58.48°,
Sydney 277.50°.

London (~119°) and New York (~58.5°) are values that are widely published, which is
what confirms the formula and the Kaaba coordinates are right rather than merely
self-consistent.

> The brief's illustrative example text — "Qibla is 258 degrees from North" — does
> not match any of the launch cities. The nearest is Sialkot at 259.0°; Karachi is
> 267.7° and Faisalabad 259.6°. The app always shows the computed value for the
> user's own position.

## Share card

`lib/src/features/sharing/` renders one ayah or hadith as a 1080-wide PNG and hands
it to the OS share sheet.

```dart
final content = ShareCardContent.fromApiItem(item); // from GET /api/v1/daily-content
await Get.find<ShareCardService>().share(
  context: context,
  content: content,
  format: ShareCardFormat.story,
  origin: shareOriginOf(buttonContext), // required on iPad
);
```

* **Both formats**, captured at 3x: 1080×1350 (feed) and 1080×1920 (Story/Status).
  The card is laid out at 360×450 and 360×640 logical pixels and the ratio is derived
  from the sizes, so the output is exact with no post-scaling.
* **Three templates** — `classic`, `night`, `minimal` — as palettes rather than three
  widget files, because the layout is identical across them and three copies would
  mean three copies of the citation rules that must never drift.
* **Text is never truncated.** Each block wraps at a bounded width and is then scaled
  down to fit, so Ayat al-Kursi renders smaller than 112:1 rather than losing its
  last line.
* **Nothing is fabricated.** `ShareCardContent.fromApiItem` throws when
  `arabic_text`, `reference` or `source.name` is missing, so a card without a citation
  cannot exist. Absent fields are omitted, never defaulted.
* **`share_plus` is not a dependency here.** See `INTEGRATION.md`, "Wiring the share
  sheet" — it resolves `objective_c`, whose build hook needs Xcode and broke
  `flutter test` in this package. The share sheet is reached through the
  `ShareCardSharer` interface, implemented in each app.

`ShareCardPreview` gives the on-screen preview plus loading and error states.
`assets/font/` holds Noto Naskh Arabic under the SIL OFL 1.1.

## Two things worth knowing about the design

**The planner cancels before it schedules.** `allNotificationIds()` covers the
whole reserved id space, and the scheduler clears all of it before arming the plan.
That means a prayer the user switched off in a previous session cannot survive as
an orphan, and the app never has to remember what it scheduled last time.

**Sound needs two Android channels.** Android bakes a channel's sound in at
creation, and it cannot be changed afterwards. One channel could therefore never
serve "azan sound on" and "silent reminder" at once — so there are two
(`prayer_azan_v1`, `prayer_silent_v1`) and each notification picks one.

