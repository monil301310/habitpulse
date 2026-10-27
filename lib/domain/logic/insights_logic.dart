import '../entities/habit.dart';
import '../entities/habit_log.dart';
import '../enums/log_status.dart';
import '../models/local_day.dart';
import 'completion_logic.dart';
import 'schedule_logic.dart';
import 'streak_logic.dart';

/// Per-weekday completion counts.
class WeekdayStat {
  const WeekdayStat({
    required this.weekday,
    required this.completed,
    required this.due,
  });

  /// ISO weekday, Monday = 1 … Sunday = 7.
  final int weekday;
  final int completed;
  final int due;

  double get rate => due == 0 ? 0 : completed / due;
  int get percent => (rate * 100).round();
}

/// One month of a habit's trend.
class MonthlyPoint {
  const MonthlyPoint({required this.monthStart, required this.stats});

  final LocalDay monthStart;
  final CompletionStats stats;

  double get rate => stats.rate;
}

/// Everything the habit-detail screen shows.
class HabitInsights {
  const HabitInsights({
    required this.last7,
    required this.last30,
    required this.last90,
    required this.allTime,
    required this.currentStreak,
    required this.longestStreak,
    required this.bestWeekday,
    required this.totalCompletions,
    required this.totalValue,
    required this.averageValue,
    required this.monthlyTrend,
  });

  final CompletionStats last7;
  final CompletionStats last30;
  final CompletionStats last90;
  final CompletionStats allTime;
  final StreakResult currentStreak;
  final StreakResult longestStreak;

  /// ISO weekday with the best completion rate, if there is any closed day.
  final int? bestWeekday;

  final int totalCompletions;

  /// Sum of logged values (count/timed habits); 0 for yes/no and negative.
  final double totalValue;

  /// Mean value over the days that recorded a value.
  final double averageValue;

  final List<MonthlyPoint> monthlyTrend;
}

/// App-wide insights for the Insights screen.
class OverallInsights {
  const OverallInsights({
    required this.habitCount,
    required this.thisWeek,
    required this.last30,
    required this.bestHabit,
    required this.bestRate,
    required this.worstHabit,
    required this.worstRate,
    required this.bestWeekday,
  });

  final int habitCount;
  final CompletionStats thisWeek;
  final CompletionStats last30;

  final Habit? bestHabit;
  final double bestRate;
  final Habit? worstHabit;
  final double worstRate;
  final int? bestWeekday;
}

/// Per-weekday counts across [from] … [today].
class _WeekdayCounts {
  final List<int> completed = List<int>.filled(8, 0);
  final List<int> due = List<int>.filled(8, 0);
}

_WeekdayCounts _collectWeekdays({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay from,
  required LocalDay today,
}) {
  final counts = _WeekdayCounts();
  var cursor = from;
  while (!cursor.isAfter(today)) {
    if (isHabitDueOn(habit, cursor)) {
      final log = logs[cursor];
      final done = log?.status == LogStatus.done;
      if (cursor.isBefore(today)) {
        counts.due[cursor.weekday]++;
        if (done) counts.completed[cursor.weekday]++;
      } else if (done) {
        counts.due[cursor.weekday]++;
        counts.completed[cursor.weekday]++;
      }
    }
    cursor = cursor.addDays(1);
  }
  return counts;
}

/// Completion statistics for each ISO weekday over the last [days] days.
List<WeekdayStat> weekdayStats({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay today,
  int days = 90,
}) {
  final counts = _collectWeekdays(
    habit: habit,
    logs: logs,
    from: today.addDays(-(days - 1)),
    today: today,
  );

  return [
    for (var weekday = 1; weekday <= 7; weekday++)
      WeekdayStat(
        weekday: weekday,
        completed: counts.completed[weekday],
        due: counts.due[weekday],
      ),
  ];
}

/// The weekday with the highest completion rate over the habit's history.
///
/// Ties go to the earliest weekday. Returns null when nothing has closed yet.
int? bestWeekday({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay today,
}) {
  final lower = earliestRelevantDay(habit, logs) ?? today;
  final counts = _collectWeekdays(
    habit: habit,
    logs: logs,
    from: lower,
    today: today,
  );

  int? best;
  var bestRate = -1.0;
  for (var weekday = 1; weekday <= 7; weekday++) {
    if (counts.due[weekday] == 0) continue;
    final rate = counts.completed[weekday] / counts.due[weekday];
    if (rate > bestRate) {
      bestRate = rate;
      best = weekday;
    }
  }
  return best;
}

/// Completion stats for the last [months] calendar months, oldest first.
List<MonthlyPoint> monthlyTrend({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay today,
  int months = 6,
}) {
  final currentMonth = LocalDay(today.year, today.month, 1);
  final points = <MonthlyPoint>[];

  for (var offset = months - 1; offset >= 0; offset--) {
    final start = _addMonths(currentMonth, -offset);
    points.add(
      MonthlyPoint(
        monthStart: start,
        stats: completionStats(
          habit: habit,
          logs: logs,
          from: start,
          to: _monthEnd(start, today),
          today: today,
        ),
      ),
    );
  }

  return points;
}

LocalDay _addMonths(LocalDay monthStart, int delta) {
  final totalMonths = monthStart.year * 12 + (monthStart.month - 1) + delta;
  return LocalDay(totalMonths ~/ 12, totalMonths % 12 + 1, 1);
}

LocalDay _monthEnd(LocalDay monthStart, LocalDay today) {
  final end = _addMonths(monthStart, 1).addDays(-1);
  return end.isAfter(today) ? today : end;
}

/// Builds the full insight bundle for one habit.
HabitInsights buildHabitInsights({
  required Habit habit,
  required Map<LocalDay, HabitLog> logs,
  required LocalDay today,
  required int weekStart,
}) {
  var totalCompletions = 0;
  var valueTotal = 0.0;
  var valueDays = 0;

  for (final entry in logs.entries) {
    if (entry.key.isAfter(today)) continue;
    final log = entry.value;
    if (log.status == LogStatus.done) totalCompletions++;
    if (log.value > 0) {
      valueTotal += log.value;
      valueDays++;
    }
  }

  return HabitInsights(
    last7: completionStatsForLastDays(
      habit: habit,
      logs: logs,
      today: today,
      days: 7,
    ),
    last30: completionStatsForLastDays(
      habit: habit,
      logs: logs,
      today: today,
      days: 30,
    ),
    last90: completionStatsForLastDays(
      habit: habit,
      logs: logs,
      today: today,
      days: 90,
    ),
    allTime: allTimeCompletionStats(habit: habit, logs: logs, today: today),
    currentStreak: currentStreak(
      habit: habit,
      logs: logs,
      today: today,
      weekStart: weekStart,
    ),
    longestStreak: longestStreak(
      habit: habit,
      logs: logs,
      today: today,
      weekStart: weekStart,
    ),
    bestWeekday: bestWeekday(habit: habit, logs: logs, today: today),
    totalCompletions: totalCompletions,
    totalValue: valueTotal,
    averageValue: valueDays == 0 ? 0 : valueTotal / valueDays,
    monthlyTrend: monthlyTrend(habit: habit, logs: logs, today: today),
  );
}

/// Aggregates insights for the whole account.
OverallInsights buildOverallInsights({
  required List<Habit> habits,
  required Map<String, Map<LocalDay, HabitLog>> logsByHabit,
  required LocalDay today,
}) {
  final weekStartDay = today.startOfWeek(1);

  var weekCompleted = 0;
  var weekDue = 0;
  var monthCompleted = 0;
  var monthDue = 0;

  Habit? best;
  var bestRate = -1.0;
  Habit? worst;
  var worstRate = 2.0;

  final weekdayCompleted = List<int>.filled(8, 0);
  final weekdayDue = List<int>.filled(8, 0);

  for (final habit in habits) {
    final logs = logsByHabit[habit.id] ?? const <LocalDay, HabitLog>{};

    final week = completionStats(
      habit: habit,
      logs: logs,
      from: weekStartDay,
      to: today,
      today: today,
    );
    weekCompleted += week.completedDays;
    weekDue += week.dueDays;

    final month = completionStatsForLastDays(
      habit: habit,
      logs: logs,
      today: today,
      days: 30,
    );
    monthCompleted += month.completedDays;
    monthDue += month.dueDays;

    final allTime = allTimeCompletionStats(
      habit: habit,
      logs: logs,
      today: today,
    );
    if (allTime.dueDays >= 3) {
      final rate = allTime.rate;
      if (rate > bestRate) {
        bestRate = rate;
        best = habit;
      }
      if (rate < worstRate) {
        worstRate = rate;
        worst = habit;
      }
    }

    for (final stat in weekdayStats(
      habit: habit,
      logs: logs,
      today: today,
      days: 90,
    )) {
      weekdayDue[stat.weekday] += stat.due;
      weekdayCompleted[stat.weekday] += stat.completed;
    }
  }

  int? overallBestWeekday;
  var bestWeekdayRate = -1.0;
  for (var weekday = 1; weekday <= 7; weekday++) {
    if (weekdayDue[weekday] == 0) continue;
    final rate = weekdayCompleted[weekday] / weekdayDue[weekday];
    if (rate > bestWeekdayRate) {
      bestWeekdayRate = rate;
      overallBestWeekday = weekday;
    }
  }

  return OverallInsights(
    habitCount: habits.length,
    thisWeek: CompletionStats(
      completedDays: weekCompleted,
      dueDays: weekDue,
    ),
    last30: CompletionStats(
      completedDays: monthCompleted,
      dueDays: monthDue,
    ),
    bestHabit: best,
    bestRate: bestRate < 0 ? 0 : bestRate,
    worstHabit: worst,
    worstRate: worstRate > 2 ? 0 : worstRate,
    bestWeekday: overallBestWeekday,
  );
}
