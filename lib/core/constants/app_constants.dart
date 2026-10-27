/// Global, non-visual constants for the app.
///
/// Phase 1 (Foundation) keeps these values here so later phases can read them
/// from one place instead of scattering literals through the codebase.
abstract final class AppConstants {
  /// Product name shown in the UI and used as the app/window title.
  static const String appName = 'HabitPulse';

  /// One-line description used on the empty home screen.
  static const String tagline = 'Build habits that stick, one day at a time.';

  /// File name used by the local Drift database (`$databaseName.sqlite`).
  static const String databaseName = 'habitpulse';

  /// Current schema version of the local database.
  ///
  /// Bump this whenever a table changes and add a matching branch in
  /// [AppDatabase.migration].
  ///
  /// v1: initial tables.
  /// v2: one active log per habit per day, plus a date lookup index.
  /// v3: notification sound preference on the settings row.
  /// v4: sync-state high-water marks for cloud sync.
  static const int schemaVersion = 4;

  /// Monday, matching the confirmed decision in the spec.
  static const int defaultWeekStart = 1;

  /// The "day rollover" time, as `HH:mm`. A log after midnight still counts
  /// for the previous day until this time.
  static const String defaultDayRolloverTime = '03:00';

  /// Default time for the daily recheck notification.
  static const String defaultRecheckTime = '21:30';

  /// Default quiet hours (no reminders inside this window).
  static const String defaultQuietHours = '23:00-07:00';
}
