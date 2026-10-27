# HabitPulse QA checklist

Phase 8 final pass. Re-run the automated commands after any change.

## Automated

| Check | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | ✅ No issues |
| Unit + widget tests | `flutter test` | ✅ 116 passing |
| Android App Bundle | `flutter build appbundle --release` | ✅ signed with the local release key |
| Android APK | `flutter build apk --release` | ✅ signed |
| Windows release | `flutter build windows --release` | ✅ built |
| Windows MSIX | `dart run msix:create` | see PROGRESS |
| Web build | not a target | — |

## Manual — Android

- [x] Fresh install opens the empty Today screen.
- [x] Create one of each habit type; schedules and counts render.
- [x] Log done / partial / missed / skipped; undo and notes.
- [x] Heatmap, detail stats and insights show the same data.
- [x] Reminder fires; notification **Done** updates the habit (background).
- [x] Snooze, quiet hours, daily and morning recheck.
- [x] Home-screen checklist widget logs a habit; heatmap widget renders.
- [x] Bottom navigation on phone; two-pane on a tablet-width window.
- [x] Light/dark and system theme.
- [x] Settings → Data exports JSON and CSV; share sheet opens.
- [ ] Install the **release** APK and repeat a quick smoke test.
- [ ] Add the widgets from the release build.

## Manual — Windows

- [x] `habitpulse.exe` launches at 1120×780 and restores geometry.
- [x] Navigation rail; two-pane Today at wide widths.
- [x] `Ctrl+N`, `Ctrl+1/2/3`, `Ctrl+,`, `Esc`.
- [ ] Tray icon → Show/Hide/Quit; close-to-tray.
- [ ] Start with Windows toggle survives sign-out/in.
- [ ] Export opens Explorer with the file selected.
- [ ] Release build (not debug) launch and smoke test.
- [ ] MSIX installs and launches.

## Manual — Cloud

- [x] Supabase schema + RLS applied.
- [x] Android release APK has the `INTERNET` permission (verified with `aapt2`).
- [x] Sign-up passes the deep-link `emailRedirectTo` instead of the Site URL.
- [ ] Email/password, magic link and Google sign-in on the rebuilt APK.
- [ ] Confirmation email opens `io.supabase.habitpulse://login-callback`.
- [ ] Offline edit syncs on reconnect.
- [ ] Sign-out clears local data and notifications.
- [ ] Conflict rule: Done beats Missed within a few seconds.

## Release hygiene

- [x] `.env` is gitignored; `.env.example` is committed.
- [x] `android/key.properties`, `*.jks` and installers are gitignored.
- [x] No service-role key in the app or repo.
- [x] Privacy policy present (`PRIVACY.md`).
- [x] README covers install, usage, build and cloud setup.
- [ ] Release artifacts checksummed (optional).
- [x] Repository pushed to GitHub (private): <https://github.com/monil301310/habitpulse>.
