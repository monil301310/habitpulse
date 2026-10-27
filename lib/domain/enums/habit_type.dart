/// The four ways a habit can be logged, per the product spec.
enum HabitType {
  /// One tap to mark done.
  yesNo,

  /// Numeric value (e.g. 8 glasses) that must reach a daily target.
  count,

  /// Minutes tracked, either typed in or via a start/stop timer.
  timed,

  /// A habit to avoid. It stays blank until the user confirms it, and never
  /// counts as done automatically.
  negative;

  /// Stable string used by the database and sync layer.
  String get storageKey => switch (this) {
    HabitType.yesNo => 'yes_no',
    HabitType.count => 'count',
    HabitType.timed => 'timed',
    HabitType.negative => 'negative',
  };

  /// Human-readable label.
  String get label => switch (this) {
    HabitType.yesNo => 'Yes / No',
    HabitType.count => 'Count',
    HabitType.timed => 'Timed',
    HabitType.negative => 'Negative',
  };

  static HabitType fromStorageKey(String? value) {
    return switch (value) {
      'count' => HabitType.count,
      'timed' => HabitType.timed,
      'negative' => HabitType.negative,
      _ => HabitType.yesNo,
    };
  }
}
