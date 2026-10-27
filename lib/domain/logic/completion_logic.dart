import '../entities/habit.dart';
import '../entities/habit_log.dart';
import '../enums/log_status.dart';
import '../models/local_day.dart';
import 'schedule_logic.dart';

/// Completion statistics over a date range.
class CompletionStats {
  const CompletionStats({required this.completedDays, required this.dueDays});

  const CompletionStats.empty() : completedDays = 0, dueDays = 0;

  final int completedDays;

  /// Due days that have already closed (plus today when it is already done).
  /// Days that are not due, and today while it is still open, are excluded so
  /// an in-progress day never lowers the rate.
  final int dueDays;

  double get rate => dueDays == 0 ? 0 : completedDays / dueDays;

  /// 0–100, rounded, ready for display.
  int get percent => (rate * 100).round();

  @override
  String toString() => '$completedDays/$dueDays ($percent%)';
}

/// Completion stats for the inclusive range [from] … [to].
CompletionStats completionStats({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay from,
  required LocalDay to,
  required LocalDay today,
}) {
  var completed = 0;
  var due = 0;

  var cursor = from;
  while (!cursor.isAfter(to)) {
    if (isHabitDueOn(habit, cursor)) {
      final log = logs[cursor];
      final isToday = cursor == today;

      if (isToday) {
        // Only a completed today counts; an open day is excluded entirely.
        if (log?.status == LogStatus.done) {
          due++;
          completed++;
        }
      } else if (cursor.isBefore(today)) {
        due++;
        if (log?.status == LogStatus.done) completed++;
      }
      // Future days are ignored.
    }
    cursor = cursor.addDays(1);
  }

  return CompletionStats(completedDays: completed, dueDays: due);
}

/// Completion stats over the last [days] days, inclusive of today.
CompletionStats completionStatsForLastDays({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay today,
  required int days,
}) {
  return completionStats(
    habit: habit,
    logs: logs,
    from: today.addDays(-(days - 1)),
    to: today,
    today: today,
  );
}

/// Completion stats across the habit's whole history.
CompletionStats allTimeCompletionStats({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay today,
}) {
  final lower = habit.startDate ?? earliestRelevantDay(habit, logs) ?? today;
  return completionStats(
    habit: habit,
    logs: logs,
    from: lower,
    to: today,
    today: today,
  );
}
