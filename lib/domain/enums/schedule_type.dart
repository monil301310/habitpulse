/// How a habit is scheduled.
enum ScheduleType {
  /// Due every calendar day.
  daily,

  /// Due only on chosen weekdays (e.g. Mon/Wed/Fri).
  weekdays,

  /// Any X days in a calendar week (week starts Monday by default).
  timesPerWeek;

  /// Stable string used by the database and sync layer.
  String get storageKey => switch (this) {
    ScheduleType.daily => 'daily',
    ScheduleType.weekdays => 'weekdays',
    ScheduleType.timesPerWeek => 'times_per_week',
  };

  /// Human-readable label.
  String get label => switch (this) {
    ScheduleType.daily => 'Every day',
    ScheduleType.weekdays => 'Specific weekdays',
    ScheduleType.timesPerWeek => 'Times per week',
  };

  static ScheduleType fromStorageKey(String? value) {
    return switch (value) {
      'weekdays' => ScheduleType.weekdays,
      'times_per_week' => ScheduleType.timesPerWeek,
      _ => ScheduleType.daily,
    };
  }
}
