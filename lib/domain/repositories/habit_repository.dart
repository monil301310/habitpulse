import '../entities/habit.dart';

/// Read and write access to habits for the presentation layer.
///
/// The UI never talks to the database directly; it depends on this interface so
/// screens stay testable and a sync-backed implementation can be swapped in
/// later without touching widgets.
abstract interface class HabitRepository {
  /// Emits the current habits whenever the underlying table changes.
  Stream<List<Habit>> watchHabits({bool includeArchived = false});

  /// A single habit by id, including archived habits but not deleted ones.
  Future<Habit?> getHabit(String id);

  /// Inserts a new habit or replaces the existing row with the same id.
  Future<void> saveHabit(Habit habit);

  /// Hides (or restores) a habit while keeping its history.
  Future<void> setArchived(String id, {required bool archived});

  /// Soft-deletes a habit together with its reminders and logs.
  Future<void> deleteHabit(String id);
}
