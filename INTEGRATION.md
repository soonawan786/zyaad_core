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

## Option A — a git dependency (recommended)

`zyaad_core` becomes its own repository, and the apps point at a **tag**:

```yaml
# in zyaad-user/pubspec.yaml and zyaad-driver/pubspec.yaml
dependencies:
  zyaad_core:
    git:
      url: git@github.com:<org>/zyaad_core.git
      ref: v1.0.0        # a tag, never a branch
```

### Create and push the repository

The folder is already set up for it: `LICENSE`, `CHANGELOG.md`, `.gitignore` and a
CI workflow are in place.

```bash
cd zyaad_core

git init
git add .
git commit -m "zyaad_core 1.0.0: prayer times, notifications, Qibla, prayer break"

# create the repo (choose one)
gh repo create <org>/zyaad_core --private --source=. --push
# or, if it already exists:
git remote add origin git@github.com:<org>/zyaad_core.git
git branch -M main
git push -u origin main

git tag v1.0.0
git push origin v1.0.0
```

### Public or private?

**Private.** It contains no secrets, but it is not a general-purpose library, and a
public repo means the world can file issues against it and read your release history.
Keep it private unless you deliberately want it public.

If it is **private**, CI needs read access. In each app repository add a read-only
deploy key:

```yaml
# .github/workflows/build.yml in the app repo
- uses: webfactory/ssh-agent@v0.9.0
  with:
    ssh-private-key: ${{ secrets.ZYAAD_CORE_DEPLOY_KEY }}
```

Add the public half to the `zyaad_core` repository's deploy keys with read access.
Never put a personal access token in the pubspec — it ends up in the lock file.

For a **private** repo the `url:` must be SSH (`git@github.com:...`), because pub
cannot prompt for an HTTPS password in CI. On your own machine either add your SSH
key or run:

```bash
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

### If you do make it public

Then HTTPS works everywhere and no key is needed:

```yaml
zyaad_core:
  git:
    url: https://github.com/<org>/zyaad_core.git
    ref: v1.0.0
```

Also fill in `homepage`, `repository` and `issue_tracker` in `pubspec.yaml` (they are
commented placeholders) — pub warns about them, and they are what makes a package
discoverable.

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


