# Arabic font for the share card

The share card asks for **Noto Naskh Arabic** as its Arabic face. The `.ttf` is not
committed to this repository, so you have to add it once. Until you do, the card
falls back to the platform's own Arabic face (see `arabicFontFallback` in
`lib/src/features/sharing/widgets/share_card.dart`) — text still shapes and joins
correctly, it is simply a different typeface.

## Why this is a manual step

A `.ttf` is a binary file. It cannot be added through a code change, and shipping a
*font you did not verify* would be worse than shipping none: a substituted or
subsetted Arabic face can render a verse with the wrong glyphs, and a wrong glyph in
scripture is not a cosmetic problem.

## Enable it

```bash
cd zyaad_core
mkdir -p assets/font
cd assets/font

# Noto Naskh Arabic — Regular and Bold
curl -LO https://github.com/notofonts/naskh-arabic/raw/main/fonts/NotoNaskhArabic/hinted/ttf/NotoNaskhArabic-Regular.ttf
curl -LO https://github.com/notofonts/naskh-arabic/raw/main/fonts/NotoNaskhArabic/hinted/ttf/NotoNaskhArabic-Bold.ttf

# Keep the licence beside the font, as the OFL requires.
curl -LO https://github.com/notofonts/naskh-arabic/raw/main/OFL.txt
```

Then uncomment the `fonts:` block at the bottom of `zyaad_core/pubspec.yaml`.

Verify:

```bash
flutter pub get
flutter test test/share_card_test.dart
```

## Licence

**Noto Naskh Arabic** is licensed under the **SIL Open Font License, Version 1.1**.

The OFL permits bundling the font in a commercial application, embedding it, and
redistributing it unmodified. It requires that:

- the font is **not sold on its own**;
- the copyright notice and the licence travel with it — which is why `OFL.txt` is
  downloaded next to the `.ttf` and must stay there;
- a **modified** version does not use the reserved font name.

The licence text is deliberately **not transcribed into this repository.** The
authoritative copy ships with the font (`OFL.txt`, fetched above) and is also at
<https://openfontlicense.org/>. A hand-copied licence is a liability, not a
safeguard — take it from the source.

## Why Naskh, and not the default

Naskh is the face Quranic text is set in and the one readers expect. Android's
default Arabic fallback is closer to Kufic, and iOS falls back to Geeza Pro (also
Naskh, which is why the fallback chain in `arabicFontFallback` prefers it). The
card sets a generous line height because Naskh diacritics sit both high and low and
collide at normal leading.

## Fonts in the host apps

`zyaad-user` and `zyaad-driver` bundle `SFProText` and Roboto. Neither contains
Arabic glyphs, which is why the Arabic in those apps is currently drawn by the
system fallback. Bundling this face in `zyaad_core` fixes the share card
specifically; the same font can be reused for in-app Arabic later by adding it to
each app's `pubspec.yaml`.
