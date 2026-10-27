import '../entities/habit.dart';
import '../entities/habit_log.dart';
import '../enums/log_status.dart';
import '../enums/schedule_type.dart';
import '../models/local_day.dart';
import 'schedule_logic.dart';

/// The visual intensity of one heatmap square.
enum HeatmapIntensity {
  /// Not due, before the start date, in the future, or an open today.
  empty,

  /// A closed due day with no log.
  missed,

  /// A day the user deliberately skipped.
  skipped,

  /// A count/timed habit below its target.
  partial,

  /// Fully completed.
  done,
}

/// Maps a habit, its log and a day to a heatmap square intensity.
HeatmapIntensity heatmapIntensityFor({
  required Habit habit,
  required HabitLog? log,
  required LocalDay day,
  required LocalDay today,
}) {
  if (day.isAfter(today)) return HeatmapIntensity.empty;

  final start = habit.startDate;
  if (start != null && day.isBefore(start)) return HeatmapIntensity.empty;
  if (!isHabitDueOn(habit, day)) return HeatmapIntensity.empty;

  if (log == null) {
    if (day == today) return HeatmapIntensity.empty;
    // X-per-week habits only need some days; an unlogged day is neutral, not a
    // failure.
    if (habit.scheduleType == ScheduleType.timesPerWeek) {
      return HeatmapIntensity.empty;
    }
    return HeatmapIntensity.missed;
  }

  return switch (log.status) {
    LogStatus.done => HeatmapIntensity.done,
    LogStatus.partial => HeatmapIntensity.partial,
    LogStatus.skipped => HeatmapIntensity.skipped,
    LogStatus.missed => HeatmapIntensity.missed,
    LogStatus.slipped => HeatmapIntensity.missed,
  };
}
