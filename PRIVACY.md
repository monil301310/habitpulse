# HabitPulse privacy policy

**Effective date:** 27 October 2026

HabitPulse is an offline-first habit tracker. This policy explains what the app
stores, where it goes and how to remove it.

## The short version

- Your habits, reminders, logs and settings live in a local SQLite database on
  your device.
- Cloud sync is **off by default**. It only works if you add your own Supabase
  project keys and sign in.
- There are no ads, analytics, trackers or crash-reporting SDKs.
- You can export your data at any time from **Settings → Data**.

## What is stored on your device

| Data | Why |
| --- | --- |
| Habit names, icons, colours, schedules, targets | Show and schedule your habits |
| Daily logs, values, statuses and notes | Streaks, heatmaps and insights |
| Reminders (times, days, enabled) | Local notifications |
| Settings (theme, week start, rollover, quiet hours, rechecks) | Behaviour of the app |
| Supabase session (only if you sign in) | Stay signed in between launches |

The session is kept in the operating system's secure store (Android Keystore /
Windows Credential Manager), not in plain preferences.

## Optional cloud sync

If you configure and sign in to your own Supabase project, the app sends the
following to **your** Supabase project:

- your email address and authentication data (handled by Supabase Auth);
- your habits, reminders, logs and settings, tagged with your user id.

Google sign-in, if you choose it, is handled by Google and Supabase; HabitPulse
receives only the account email needed to identify your rows. The app does not
receive your Google password.

Every row is protected by Supabase Row Level Security, so one account cannot
read another account's data. The app never uses a service-role key. Your Supabase
URL and anon/publishable key are stored in the local `.env` file used to build
the app; they are not sent anywhere else.

If you never configure Supabase, no habit data leaves your device.

## Notifications

Reminders are scheduled locally with Android's notification APIs or Windows
toasts. No push-notification service is involved.

## Exports

**Settings → Data** writes a JSON or CSV file to your device (Downloads on
Windows, app documents plus the share sheet on Android). You choose where to send
it; the app does not upload it.

## Retention and deletion

- **Local data:** delete individual habits in the app, or uninstall the app /
  clear its storage to remove everything.
- **Sign out:** HabitPulse clears the local database after confirmation. Cloud
  rows remain in your Supabase project.
- **Cloud data:** delete rows in your Supabase project, or delete the project
  itself. Deleting your Supabase auth user removes the account; you may also need
  to delete any remaining rows.
- **Exports:** delete the exported files from your device.

## Children

HabitPulse is not directed at children under 13 and does not knowingly collect
personal information from them.

## Changes

If this policy changes, the effective date above will be updated and the new
version committed with the app.

## Contact

For privacy questions, open an issue in the project's GitHub repository (linked
from the README). Do not include personal data in a public issue.
