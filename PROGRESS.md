# PROGRESS

**Project:** HabitPulse
**Phases complete:** 1 · 2 · 3 · 4 · 5 · 6 · 7 · 8 (Final QA & packaging)
**Date:** 27 Oct 2026
**Status:** All planned phases are implemented. Release APK, AAB, Windows build
and MSIX are produced. A short list of device-level manual checks remains (below).

---

## 1. Phase 8 — Final QA, packaging and docs (this phase)

From section 9:

> **8. Tests, polish and packaging** — Full test pass, release builds, privacy
> policy and README, data export, final QA checklist. **Done when:** all tests
> pass; release APK/AAB and Windows installer build; README explains install and
> usage.

### What is done

**Data export**
- [x] **Settings → Data → Export as JSON** writes habits, reminders, logs and
      settings, with counts, timestamps and a schema version.
- [x] **Export as CSV** writes one row per logged day (`habit,date,status,value,
      unit,note`), with proper quote/comma/newline escaping.
- [x] Windows saves to Downloads and opens Explorer; Android uses the share
      sheet.
- [x] JSON/CSV builders are pure and covered by tests.

**Docs**
- [x] `README.md` rewritten: features, install/run, widgets, desktop shortcuts,
      cloud setup, export, release commands, layout and privacy link.
- [x] `PRIVACY.md`: local-first storage, optional Supabase, Google sign-in, no
      analytics, retention and deletion.
- [x] `docs/QA.md`: automated and manual checklist with current results.

**Release builds**
- [x] Android release keystore generated **outside the repository**
      (`C:\Users\monil\habitpulse-keys`), with `android/key.properties`
      gitignored and a debug-signing fallback.
- [x] Signed **AAB** (`app-release.aab`, 67.8 MB) and **APK**
      (`app-release.apk`, 71.0 MB); certificate `CN=HabitPulse`.
- [x] Windows **release** build (`habitpulse.exe`) launches and responds.
- [x] **MSIX** installer (`habitpulse.msix`, 17.3 MB) created with the `msix`
      package. It is signed with a **self-signed test certificate**, so Windows
      will warn until a trusted code-signing certificate is used.

### Verification for Phase 8

| Check | Result |
| --- | --- |
| `flutter analyze` | ✅ No issues |
| `flutter test` | ✅ **116 tests pass** |
| Android AAB (release, signed) | ✅ 67.8 MB |
| Android APK (release, signed) | ✅ 71.0 MB |
| Windows release exe | ✅ launched, window “HabitPulse”, responding |
| Windows MSIX | ✅ 17.3 MB, self-signed test cert |
| JSON/CSV export | ✅ builders tested; device share/save needs one manual tap |
| Privacy policy + README + QA | ✅ present |
| Release APK on a phone | ⏳ install and smoke-test |
| MSIX install | ⏳ trust the test cert or use a real code-signing cert |
| Tray / start-with-Windows | ⏳ quick desktop check |
| Cross-device sync | ⏳ needs your Supabase project |

> **Build-environment note:** Gradle could not download the release engine
> artifacts through Java on this machine even though `curl` reached them. The
> exact artifacts were seeded into the local Maven repo and
> `mavenLocal()` was added to `android/build.gradle.kts`; the release build then
> succeeded. Nothing device-specific is committed, and normal machines still
> resolve from Google/Maven Central.

---

## 2. Remaining manual checks

1. `adb install -r build\app\outputs\flutter-apk\app-release.apk` and repeat the
   quick Android smoke test (habits, notification Done, widgets).
2. Double-click `build\windows\x64\runner\Release\habitpulse.exe`; check the tray,
   close-to-tray, Start with Windows and Settings → Data export.
3. Install `build\windows\x64\runner\Release\habitpulse.msix` only after trusting
   its test certificate (or rebuild with a real certificate).
4. Follow [SETUP_SUPABASE.md](SETUP_SUPABASE.md) for cross-device sync.

---

## 3. Previous phases — complete

- **Phase 1:** Flutter project, themes, Drift, Riverpod.
- **Phase 2:** four habit types, schedules, logging, notes, streaks.
- **Phase 3:** heatmap, detail insights, day editing, seeder.
- **Phase 4:** reminders, notification actions, rechecks, quiet hours.
- **Phase 5:** Supabase accounts + sync.
- **Phase 6:** Android checklist + heatmap widgets.
- **Phase 7:** adaptive shell, two-pane, Windows rail/tray/startup, shortcuts.
- **Phase 8:** export, privacy, README, QA, release packaging.

---

## 4. How to run and test

```powershell
flutter pub get
flutter analyze
flutter test          # 116 tests

flutter emulators --launch medium_phone
flutter run -d emulator-5554
flutter run -d windows
```

### Release
```powershell
flutter build appbundle --release
flutter build apk --release
flutter build windows --release
dart run msix:create
```

### After changing database tables
```powershell
dart run build_runner build
```
Bump `AppConstants.schemaVersion` and add an `if (from < N)` step in
`AppDatabase.migration` (v4 is current).

---

## 5. Repository

The project is ready to publish. `.env`, `android/key.properties`, keystores,
builds and installers are gitignored. GitHub upload is handled after Phase 8
(see the hand-off notes).
