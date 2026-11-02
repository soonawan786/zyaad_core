## 1.0.4

* **The share flow.** `ShareCardSheet` + `ShareCardButton` + `showShareCardSheet` —
  the entry point the feature was missing. A modal sheet with the card preview, a
  Post/Story toggle, a template picker, and the share action.
  * A completed share closes the sheet. A **dismissal** does not: the user changed
    their mind about the destination, not about the card, so it stays open for
    another attempt.
  * A failure keeps the sheet open and shows the reason, so a retry is one tap.
  * The iPad origin is measured from the sheet's own share button — the button the
    user actually presses — so no call site has to remember it.
  * Switching to Story re-applies the dark treatment unless a template was pinned.
* 7 new tests (sheet open, format/template selection reaching the service, the
  origin being set, close on success, stay open on failure, stay open on dismissal).
* `flutter analyze` clean.

## 1.0.3

* Docs only: `INTEGRATION.md` gains "Wiring the share sheet" — the required
  `ShareCardSharer` adapter and DI registration in each app, and the reason
  `share_plus` is not a dependency here. `README.md` gains a share card section. No
  code change.

  Shipped as a tag rather than left on `main` because the share card's own code
  comments reference that section by name; a pinned copy without it would dangle.

## 1.0.2

* **Share card.** `lib/src/features/sharing/` — renders one ayah or hadith from
  `GET /api/v1/daily-content` as a 1080-wide PNG and hands it to the OS share
  sheet.
  * `ShareCardContent.fromApiItem` parses the API payload and **throws** when
    `arabic_text`, `reference` or `source.name` is missing, so a card without a
    citation cannot be constructed. Optional fields render only when the API sent
    them; nothing is defaulted to a placeholder.
  * `ShareCard` — three templates (classic / night / minimal), both formats
    (1080×1350 and 1080×1920, captured at 3x), RTL Arabic with per-line direction
    for mixed Urdu/English, and text that is **scaled down rather than truncated**.
  * `WidgetShareCardRenderer` — `RepaintBoundary` → `toImage()`. The card is wrapped
    in an `UnconstrainedBox`, because the overlay's constraints otherwise clamped it
    and a Story card silently exported at 960 px wide on a 320 dp device.
  * `ShareCardFileStore` — temp files via `dart:io`, unique names per share, stale
    files reaped. Never deletes a file it has just shared, because Android's
    receiving app may read it lazily.
  * `ShareCardPreview` — preview, loading and error states.
  * `NotoNaskhArabic` bundled under `assets/font/` (SIL OFL 1.1).
* **No new dependencies.** `share_plus` is deliberately *not* declared here: it
  resolves `objective_c` transitively, whose build hook requires a working Xcode
  native-assets toolchain, which made `flutter test` in this package fail before a
  single test ran. The share sheet is reached through the `ShareCardSharer`
  interface, implemented in the host apps (which already depend on `share_plus`).
* 37 new tests. `flutter analyze` clean.

## 1.0.1

* Docs only: `README.md` and `INTEGRATION.md` now describe the package as it is
  actually consumed — a public git dependency pinned to a tag — instead of the
  earlier path-dependency setup. No code change.

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
