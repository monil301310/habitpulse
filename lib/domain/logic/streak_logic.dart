import '../entities/habit.dart';
import '../entities/habit_log.dart';
import '../enums/log_status.dart';
import '../enums/schedule_type.dart';
import '../models/local_day.dart';
import 'schedule_logic.dart';

/// Whether a streak is counted in days or weeks.
enum StreakUnit { days, weeks }

/// The result of a streak calculation, with the label the UI should show.
class StreakResult {
  const StreakResult({required this.length, required this.unit});

  const StreakResult.empty() : length = 0, unit = StreakUnit.days;

  final int length;
  final StreakUnit unit;

  /// e.g. `18d` or `3w`, matching the spec's streak pill.
  String get label => unit == StreakUnit.weeks ? '${length}w' : '${length}d';
}

/// The current streak, per section 4 of the spec.
///
/// * Consecutive due days completed, ending today or yesterday.
/// * Today does not break the streak until the day closes.
/// * Skipped and not-due days do not break it.
/// * Times-per-week habits count consecutive successful weeks instead.
StreakResult currentStreak({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay today,
  required int weekStart,
}) {
  if (habit.scheduleType == ScheduleType.timesPerWeek) {
    return _currentWeeklyStreak(
      habit: habit,
      logs: logs,
      today: today,
      weekStart: weekStart,
    );
  }

  final lower = earliestRelevantDay(habit, logs);
  if (lower == null) return const StreakResult.empty();

  var cursor = today;
  var streak = 0;

  while (!cursor.isBefore(lower)) {
    if (isHabitDueOn(habit, cursor)) {
      final log = logs[cursor];

      if (log?.status == LogStatus.done) {
        streak++;
      } else if (log?.status == LogStatus.skipped) {
        // An intentional skip neither extends nor breaks the streak.
      } else if (log != null &&
          (log.status == LogStatus.missed || log.status == LogStatus.slipped)) {
        break;
      } else if (cursor == today) {
        // Today's square is still open: it must not break the streak yet.
        // This also covers an open negative habit and a partial count/timed day.
      } else {
        // A past due day with no log (or a partial value) counts as missed.
        break;
      }
    }
    cursor = cursor.addDays(-1);
  }

  return StreakResult(length: streak, unit: StreakUnit.days);
}

StreakResult _currentWeeklyStreak({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay today,
  required int weekStart,
}) {
  final target = effectiveWeeklyTarget(habit);
  final lowerDay = earliestRelevantDay(habit, logs);
  final currentWeek = today.startOfWeek(weekStart);

  var week = currentWeek;
  var streak = 0;

  while (lowerDay == null
      ? week == currentWeek
      : !week.isBefore(lowerDay.startOfWeek(weekStart))) {
    if (completionsInWeek(logs, week) >= target) {
      streak++;
    } else if (week == currentWeek) {
      // The current week is still in progress; it cannot break the streak.
    } else {
      break;
    }
    week = week.addDays(-7);
    if (week.isBefore(currentWeek.addDays(-7 * 5200))) break; // ~100 years guard
  }

  return StreakResult(length: streak, unit: StreakUnit.weeks);
}

/// The longest run of completed due days (or successful weeks) in the history.
StreakResult longestStreak({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay today,
  required int weekStart,
}) {
  if (habit.scheduleType == ScheduleType.timesPerWeek) {
    return _longestWeeklyStreak(
      habit: habit,
      logs: logs,
      today: today,
      weekStart: weekStart,
    );
  }

  final lower = earliestRelevantDay(habit, logs);
  if (lower == null || lower.isAfter(today)) {
    return const StreakResult.empty();
  }

  var current = 0;
  var best = 0;
  var cursor = lower;

  while (!cursor.isAfter(today)) {
    if (isHabitDueOn(habit, cursor)) {
      final log = logs[cursor];

      if (log?.status == LogStatus.done) {
        current++;
        if (current > best) best = current;
      } else if (log?.status == LogStatus.skipped) {
        // neutral
      } else if (cursor == today) {
        // still open
      } else {
        current = 0;
      }
    }
    cursor = cursor.addDays(1);
  }

  return StreakResult(length: best, unit: StreakUnit.days);
}

StreakResult _longestWeeklyStreak({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay today,
  required int weekStart,
}) {
  final lowerDay = earliestRelevantDay(habit, logs);
  if (lowerDay == null) return const StreakResult.empty();

  final target = effectiveWeeklyTarget(habit);
  final currentWeek = today.startOfWeek(weekStart);

  var week = lowerDay.startOfWeek(weekStart);
  var current = 0;
  var best = 0;

  while (!week.isAfter(currentWeek)) {
    if (completionsInWeek(logs, week) >= target) {
      current++;
      if (current > best) best = current;
    } else if (week == currentWeek) {
      // in progress
    } else {
      current = 0;
    }
    week = week.addDays(7);
  }

  return StreakResult(length: best, unit: StreakUnit.weeks);
}
