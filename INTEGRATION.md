# Putting `zyaad_core` into your live apps

This is the answer to "how do I work with this folder in my live app, and do I need
to put it on GitHub?"

## The problem with how it is wired right now

Both apps currently depend on it like this:

```yaml
zyaad_core:
  path: ../zyaad_core
```

That works on your machine and nowhere else. It breaks the moment:

* CI checks out only `zyaad-user` or `zyaad-driver` — the folder is not there, so
  `flutter pub get` fails;
* a teammate clones one app repo on its own — same failure;
* you build a release from a tag or a shallow clone of a single repo.

A path dependency is a **development-time convenience, not a deployment strategy**.
Pick one of the three options below.

---

## Option A — a git dependency (this is what you now have)

`zyaad_core` lives at **https://github.com/soonawan786/zyaad_core** and both apps
depend on a **tag**:

```yaml
# in zyaad-user/pubspec.yaml and zyaad-driver/pubspec.yaml
dependencies:
  zyaad_core:
    git:
      url: https://github.com/soonawan786/zyaad_core.git
      ref: v1.0.0        # a tag, never a branch
```

Verified: `flutter pub get` resolves it in both apps and `pubspec.lock` pins the
commit:

```
zyaad_core:
  dependency: "direct main"
  description:
    ref: "v1.0.0"
    resolved-ref: "76edfa606993bb814b3a9624848945432810227f"
    url: "https://github.com/soonawan786/zyaad_core.git"
  source: git
  version: "1.0.0"
```

### Why a tag and not `main`

`ref: main` would mean the next push to `zyaad_core` silently changes what your apps
build. A tag makes a core change a deliberate decision: bump the tag, run
`flutter pub get`, commit the new lock. The lock file then makes two builds of the
same app tag byte-identical.

### The repository is public, so no CI credentials are needed

HTTPS works for anonymous clones, so there is **no deploy key and no token** to
manage. If you ever make it private again you would need a read-only deploy key in
each app's CI:

```yaml
- uses: webfactory/ssh-agent@v0.9.0
  with:
    ssh-private-key: ${{ secrets.ZYAAD_CORE_DEPLOY_KEY }}
```

…and the `url:` would have to become SSH (`git@github.com:...`), because pub cannot
prompt for an HTTPS password in CI.

### The cost of public

Anyone can read the code and open issues. That is acceptable here — there is nothing
secret in it — but it does mean:

* **Do not add a merchant API key, a signing secret or a service credential** to this
  package. It would be public within a second of the next push.
* The `topics:` and `repository:` metadata in `pubspec.yaml` are what make it
  discoverable; that is intended.
* If you later want it private, note that the git history is already public and
  cannot be un-published. A secret committed by accident would have to be rotated,
  not deleted.

---

## Option B — keep it in a monorepo (also fine)

Put all three packages in one repository:

```
zyaad/
├── zyaad_core/
├── zyaad-user/
└── zyaad-driver/
```

Then the `path: ../zyaad_core` dependency is correct and CI just checks out the one
repo. This is the least work and is what a small team usually wants — the only cost is
that a core change and an app change land in the same commit, so you cannot version
them independently.

If you choose this, ignore the rest of Option A and keep the pubspecs as they are.

---

## Option C — publish to pub.dev (not recommended yet)

`pubspec.yaml` has `publish_to: 'none'`. Removing that would let you
`dart pub publish`, and then apps could depend on `zyaad_core: ^1.0.0` like any other
package. Reasons not to, for now:

* pub.dev publishing is **irreversible** — a version can never be deleted;
* a public package means the Qibla/notification code is public;
* you lose the ability to iterate with a branch ref.

Revisit it if a second product ever needs this code.

---

## Day-to-day development

The annoying part of a git dependency is that every core change needs a commit, a push
and a version bump. Do not work that way locally — override it:

```yaml
# in zyaad-user/pubspec.yaml, at the bottom
dependency_overrides:
  zyaad_core:
    path: ../zyaad_core
```

`dependency_overrides` wins over the git dependency, so:

* **locally** you edit `zyaad_core` and hot-reload — no commits;
* **CI and release builds** use the pinned tag, because the override is not present
  there.

Never leave a path override in a release branch.

### Releasing a core change

```bash
cd zyaad_core
flutter test && flutter analyze   # must be green

# bump `version:` in pubspec.yaml (e.g. 1.0.1) and add a CHANGELOG entry
git commit -am "Fix ..."
git tag v1.0.1
git push origin main --tags
```

Then in each app change `ref: v1.0.0` → `ref: v1.0.1` and run `flutter pub get`. The
lock file pins the exact commit, so two builds of the same app tag are identical.

---

## Things that will bite you (all of these were hit while building this)

1. **Exactly one notifications plugin instance.** Both apps already created a
   `FlutterLocalNotificationsPlugin` in `main.dart` and initialized it in
   `NotificationHelper`. The shared channel deliberately **does not call
   `initialize()` again** — a second call replaces the app's existing tap handler and
   breaks every existing notification route. It only registers the two channels and
   loads the timezone database. Prayer reminders are routed from their payload
   (`prayer:<name>:<date>`), so add that case to `NotificationHelper` if you want a tap
   to open the Qibla screen.

2. **The manifest entries are per app, not per package.** A package cannot add
   `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM` or the two
   `flutter_local_notifications` receivers to the app's manifest. They are already in
   both apps' `AndroidManifest.xml`; a new app that depends on `zyaad_core` must add
   them too or reminders will never fire.

3. **`flutter test` needs a working toolchain.** In `zyaad_core` it runs fine. In
   `zyaad-driver` it currently fails in this environment because a *different*
   dependency (`objective_c`, pulled in by `local_auth`/`flutter_secure_storage`)
   builds native assets through Xcode and the Xcode licence is not accepted here. That
   is exactly why the break-timer tests live in `zyaad_core`, where they run.

4. **`publish_to: 'none'`** must stay while the package is consumed by `path:` or
   `git:`. It does not block those; it only prevents an accidental `dart pub publish`.

5. **The apps' own `AppConstants` prayer storage keys are now dead.** Storage keys
   moved to `PrayerStorageKeys` in the package so both apps read the same cache. If you
   already shipped a build with the old keys, users re-download one prayer window on
   upgrade — harmless, but worth knowing.

6. **`GetxController.refresh()` is taken.** GetX uses it as an alias for `update()`.
   The driver's break controller therefore exposes `loadStatus()`, not `refresh()`,
   and the rider app's cache/load entry point is `load()`.

7. **The two sound preferences never leave the device.** `azanSoundEnabled` and
   `azanSoundDuringRide` are excluded from `toApiJson()` on purpose: the server has no
   opinion about whether this handset makes a noise. They persist locally, so they do
   not follow a user to a new phone — which is the behaviour you want.

---

## Wiring the share sheet (required — sharing does nothing without it)

`zyaad_core` renders the card and produces the PNG, but it deliberately does **not**
depend on `share_plus`:

> `share_plus` resolves `objective_c` transitively, whose build hook requires a
> working Xcode native-assets toolchain. Declaring it in this package made
> `flutter test` fail here **before a single test ran**. It would also stay green on
> the `ubuntu-latest` CI while blocking every macOS developer without full Xcode —
> the worst kind of failure, because CI would not catch it.

So the package defines `ShareCardSharer` and the host app supplies the
implementation. Each app has one adapter file:

```
zyaad-user/lib/features/prayer/share_card_sharer.dart
zyaad-driver/lib/features/prayer/share_card_sharer.dart
```

and one pair of registrations in `lib/helper/di_container.dart`:

```dart
Get.lazyPut<ShareCardSharer>(() => const SharePlusShareCardSharer());
Get.lazyPut(() => ShareCardService(sharer: Get.find<ShareCardSharer>()));
```

`ShareCardService`'s `sharer` is a **required** argument with no default. A default
would have to be a no-op, and a no-op default turns a forgotten wiring into a button
that appears to work and shares nothing. A third app will not compile until it
supplies a sharer, which is the point.

### Using it

```dart
final content = ShareCardContent.fromApiItem(item); // one element of data.items[]
final service = Get.find<ShareCardService>();

final result = await service.share(
  context: context,
  content: content,
  format: ShareCardFormat.story,
  template: ShareCardTemplates.defaultFor(ShareCardFormat.story),
  origin: shareOriginOf(buttonContext), // required on iPad
);

if (result.isFailure) {
  showError(result.message!);
}
```

`origin` is not optional in practice: on iPad the sheet is a popover and iOS needs a
rectangle to anchor it to. `shareOriginOf` is exported for exactly this and returns
null safely on phones.

**Nothing can be fabricated.** `ShareCardContent.fromApiItem` throws
`ShareCardContentException` when `arabic_text`, `reference` or `source.name` is
missing, so a card without a citation cannot be constructed and therefore cannot be
shared. Fields the API did not send stay null and are simply not rendered — never
defaulted to a placeholder.

`ShareCardService.cleanUp()` reaps stale rendered cards. Safe to call on app start.

### The Arabic font

`NotoNaskhArabic` is bundled in `assets/font/` with its OFL licence beside it. It is
declared in `pubspec.yaml`, so the card asks for it by name and falls back to the
platform's Arabic face only if the asset is missing. See
`assets/font/README.md`.


