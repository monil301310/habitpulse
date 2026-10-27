import '../entities/habit_log.dart';
import '../models/local_day.dart';

/// Read and write access to daily habit logs.
abstract interface class LogRepository {
  /// Every active log, oldest first. Small enough for V1; ranged queries can be
  /// added when the heatmap needs years of data (Phase 3).
  Stream<List<HabitLog>> watchAllLogs();

  /// One habit's logs indexed by local day, emitting on every change.
  Stream<Map<LocalDay, HabitLog>> watchLogsByDay(String habitId);

  /// The active log for a habit and day, if any.
  Future<HabitLog?> findLog(String habitId, LocalDay day);

  /// Inserts or updates a log (unique per habit and day while active).
  Future<void> saveLog(HabitLog log);

  /// Soft-deletes a log so the day becomes open again.
  Future<void> deleteLog(String id);
}
