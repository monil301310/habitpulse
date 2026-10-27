import '../entities/habit.dart';
import '../entities/habit_log.dart';
import '../enums/log_status.dart';
import '../enums/schedule_type.dart';
import '../models/local_day.dart';

/// Whether [habit] is due on [day].
///
/// Days before the habit's start date are never due. Times-per-week habits are
/// "due" on any day because the week is satisfied by any X completions.
bool isHabitDueOn(Habit habit, LocalDay day) {
  final start = habit.startDate;
  if (start != null && day.isBefore(start)) return false;

  return switch (habit.scheduleType) {
    ScheduleType.daily => true,
    ScheduleType.weekdays => habit.scheduleDays.contains(day.weekday),
    ScheduleType.timesPerWeek => true,
  };
}

/// Indexes logs by their local day for fast lookups.
Map<LocalDay, HabitLog> logsByDay(Iterable<HabitLog> logs) {
  final byDay = <LocalDay, HabitLog>{};
  for (final log in logs) {
    if (log.isDeleted) continue;
    byDay[log.date] = log;
  }
  return byDay;
}

/// The number of daily targets reached in the week starting [weekStart].
int completionsInWeek(Map<LocalDay, HabitLog> logs, LocalDay weekStart) {
  var count = 0;
  for (var i = 0; i < 7; i++) {
    if (logs[weekStart.addDays(i)]?.status == LogStatus.done) {
      count++;
    }
  }
  return count;
}

/// The number of completions a times-per-week habit needs per week.
int effectiveWeeklyTarget(Habit habit) {
  final target = habit.timesPerWeek ?? 0;
  return target < 1 ? 1 : target;
}

/// Whether the week starting [weekStart] has satisfied a times-per-week habit.
bool isWeekSatisfied(Habit habit, Map<LocalDay, HabitLog> logs, LocalDay weekStart) {
  return completionsInWeek(logs, weekStart) >= effectiveWeeklyTarget(habit);
}

/// The earliest day any streak or statistic can start from: the habit's start
/// date if set, otherwise the earliest day with a log.
LocalDay? earliestRelevantDay(Habit habit, Map<LocalDay, HabitLog> logs) {
  LocalDay? earliest;
  for (final day in logs.keys) {
    if (earliest == null || day.isBefore(earliest)) earliest = day;
  }
  final start = habit.startDate;
  if (start != null && (earliest == null || start.isBefore(earliest))) {
    return start;
  }
  return earliest;
}
