/// A reminder attached to a habit.
///
/// Each habit can have several reminders, each with its own time and days.
class HabitReminder {
  const HabitReminder({
    required this.id,
    required this.habitId,
    required this.timeOfDay,
    this.daysOfWeek = const {},
    this.enabled = true,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String habitId;

  /// Time of day in local time, `HH:mm`.
  final String timeOfDay;

  /// ISO weekdays (Monday = 1 … Sunday = 7). Empty means "the habit's days".
  final Set<int> daysOfWeek;

  final bool enabled;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}
