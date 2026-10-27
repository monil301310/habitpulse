# Supabase setup (Phase 5)

HabitPulse works fully offline without Supabase. Cloud accounts and sync turn on
when you add your own project keys. This takes about 15 minutes.

## 1. Create the project

1. Go to <https://supabase.com> and sign in.
2. **New project** → pick an organisation, name it `habitpulse`, choose a region
   near you, and set a database password (save it).
3. Wait for the project to finish provisioning.

## 2. Create the tables

1. Open **SQL Editor → New query**.
2. Paste the whole of [`supabase/schema.sql`](schema.sql) and click **Run**.
3. You should see all four tables under **Table Editor**: `habits`,
   `reminders`, `logs`, `settings`, each with RLS enabled.

The SQL also adds the tables to Supabase Realtime, which is what makes a change
appear on another device within a few seconds.

## 3. Enable sign-in methods

### Email + password and magic link

**Authentication → Providers → Email** is enabled by default. Keep
**Confirm email** on (recommended).

### Google

1. In **Google Cloud Console → APIs & Services → Credentials**, create an
   **OAuth client ID** of type **Web application**.
2. Add this **Authorised redirect URI**:
   `https://<your-project-ref>.supabase.co/auth/v1/callback`
3. In Supabase: **Authentication → Providers → Google** → enable it and paste the
   client ID and client secret.

## 4. Allow the app's redirect URL

**Authentication → URL Configuration**:

- **Site URL**: `http://localhost:3000` (unused, but required)
- **Redirect URLs** → add:
  - `io.supabase.habitpulse://login-callback`

The Android app already declares this deep link, so a magic link or Google
sign-in returns to HabitPulse.

> Windows: magic links open in the browser and cannot hand the session back to
> the desktop app yet. Use **email + password** on Windows.

## 5. Put the keys in `.env`

1. In Supabase: **Project Settings → API**.
2. Copy **Project URL** and the **anon / publishable** key.
3. In the project folder, open `.env` (created from `.env.example`) and fill in:

```dotenv
SUPABASE_URL=https://abcdefghijkl.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

`.env` is gitignored; `.env.example` is the committed template. The anon key is
safe to ship in an app because Row Level Security restricts every row to its
owner.

4. Stop and restart the app (`flutter run`). `flutter run` rebuilds the assets,
   which is required for `.env` changes.

## 6. Verify

1. Open **Settings → Account**. It should now say **Sign in to sync**.
2. Create an account (or sign in with Google / a magic link).
3. The first sync downloads everything already in your account and uploads the
   habits you created locally.
4. Mark a habit done on device A. On device B (same account), it should update
   within a few seconds once Realtime connects.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "Cloud sync not set up" | `.env` empty or not rebuilt — stop and rerun `flutter run`. |
| `Invalid API key` | Wrong key copied; use the **anon/publishable** key, not `service_role`. |
| Magic link opens the browser, not the app | Redirect URL missing in Supabase, or the app was not reinstalled after the manifest change. |
| No realtime updates | Re-run the realtime block at the bottom of `schema.sql`. |
| RLS error on insert | `user_id` must equal `auth.uid()`; the sync layer sets it automatically. |

## Security notes

- Never put the **service_role** key in the app or in `.env`.
- Row Level Security is required; without it any signed-in user could read
  another user's rows.
- Signing out clears the local database after confirmation; cloud data remains.
