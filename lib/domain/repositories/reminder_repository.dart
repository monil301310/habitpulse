import '../entities/habit_reminder.dart';

/// Reminder CRUD for habits.
abstract interface class ReminderRepository {
  /// Every active reminder, ordered by time of day.
  Stream<List<HabitReminder>> watchAll();

  /// The active reminders for one habit.
  Future<List<HabitReminder>> listForHabit(String habitId);

  /// Makes [reminders] the complete set for a habit, soft-deleting removed ones.
  Future<void> replaceForHabit(String habitId, List<HabitReminder> reminders);
}
