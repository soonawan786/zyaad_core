## 1.0.0

First release.

* Prayer-time models: `Prayer`, `PrayerTime`, `PrayerDay`, `NextPrayer`,
  `RamadanWindow`. Absolute instants plus the city's wall clock, so a user in a
  different timezone is still reminded at the right moment.
* `IslamicFeatureSettings`: the user's switches, including the two device-only
  azan-sound flags that are deliberately never sent to the server.
* `PrayerNotificationPlanner`: turns a window of prayer days into the exact list of
  local notifications to hold, with a deterministic id space so a switched-off
  prayer is always cancelled rather than orphaned.
* `PrayerNotificationChannel` / `PrayerNotificationScheduler`: the
  `flutter_local_notifications` implementation, with two Android channels (azan and
  silent) and an exact-alarm fallback.
* `Qibla`: great-circle bearing and distance to the Kaaba, and the relative
  bearing for the needle.
* `HeadingCalculator`: tilt-compensated heading from magnetometer + accelerometer,
  with a calibration verdict and angular smoothing.
* `MotionGate`: the "stop to use the compass" speed gate, with hysteresis.
* `PrayerBreak` / `PrayerBreakAllowance`: the driver's break countdown, progress
  and daily allowance.
