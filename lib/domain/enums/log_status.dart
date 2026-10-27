/// The state of a habit's log for a single day.
enum LogStatus {
  /// The habit met its target (or was confirmed for a negative habit).
  done,

  /// A count or timed habit that is below its daily target.
  partial,

  /// The day closed without the habit being completed.
  missed,

  /// The user deliberately skipped the day. Does not break a streak.
  skipped,

  /// A negative habit that the user reported slipping on.
  slipped;

  /// Stable string used by the database and sync layer.
  String get storageKey => switch (this) {
    LogStatus.done => 'done',
    LogStatus.partial => 'partial',
    LogStatus.missed => 'missed',
    LogStatus.skipped => 'skipped',
    LogStatus.slipped => 'slipped',
  };

  static LogStatus fromStorageKey(String? value) {
    return switch (value) {
      'partial' => LogStatus.partial,
      'missed' => LogStatus.missed,
      'skipped' => LogStatus.skipped,
      'slipped' => LogStatus.slipped,
      _ => LogStatus.done,
    };
  }
}
