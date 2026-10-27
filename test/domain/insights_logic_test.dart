import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/domain/entities/habit_log.dart';
import 'package:habitpulse/domain/enums/habit_type.dart';
import 'package:habitpulse/domain/enums/log_status.dart';
import 'package:habitpulse/domain/enums/schedule_type.dart';
import 'package:habitpulse/domain/logic/insights_logic.dart';
import 'package:habitpulse/domain/models/local_day.dart';

import '../support/fixtures.dart';

void main() {
  group('weekday stats', () {
    test('bucket completions per weekday and ignore not-due days', () {
      final habit = testHabit(
        scheduleType: ScheduleType.weekdays,
        scheduleDays: {1, 3, 5},
        startDate: const LocalDay(2024, 1, 1),
      );
      final logs = logsFrom({
        const LocalDay(2024, 1, 1): LogStatus.done, // Mon
        const LocalDay(2024, 1, 3): LogStatus.done, // Wed
        const LocalDay(2024, 1, 5): LogStatus.missed, // Fri
        const LocalDay(2024, 1, 8): LogStatus.done, // Mon
        const LocalDay(2024, 1, 10): LogStatus.done, // Wed
        const LocalDay(2024, 1, 12): LogStatus.done, // Fri
      });

      final stats = weekdayStats(
        habit: habit,
        logs: logs,
        today: const LocalDay(2024, 1, 14),
        days: 14,
      );

      final byWeekday = {for (final s in stats) s.weekday: s};
      expect(byWeekday[1]!.completed, 2);
      expect(byWeekday[1]!.due, 2);
      expect(byWeekday[1]!.percent, 100);

      expect(byWeekday[3]!.completed, 2);
      expect(byWeekday[3]!.due, 2);

      expect(byWeekday[5]!.completed, 1);
      expect(byWeekday[5]!.due, 2);
      expect(byWeekday[5]!.percent, 50);

      expect(byWeekday[2]!.due, 0);
      expect(byWeekday[2]!.rate, 0);
    });
  });

  group('best weekday', () {
    test('picks the highest-rate weekday and breaks ties by earliest', () {
      final habit = testHabit(
        scheduleType: ScheduleType.weekdays,
        scheduleDays: {1, 3, 5},
        startDate: const LocalDay(2024, 1, 1),
      );
      final logs = logsFrom({
        const LocalDay(2024, 1, 1): LogStatus.done, // Mon
        const LocalDay(2024, 1, 3): LogStatus.done, // Wed
        const LocalDay(2024, 1, 5): LogStatus.missed, // Fri
      });

      expect(
        bestWeekday(
          habit: habit,
          logs: logs,
          today: const LocalDay(2024, 1, 8),
        ),
        1,
      );
    });

    test('returns null when nothing has closed', () {
      final habit = testHabit(startDate: const LocalDay(2024, 1, 15));
      expect(
        bestWeekday(
          habit: habit,
          logs: {},
          today: const LocalDay(2024, 1, 15),
        ),
        isNull,
      );
    });
  });

  group('monthly trend', () {
    test('returns one point per month, oldest first', () {
      final habit = testHabit(startDate: const LocalDay(2023, 11, 1));
      final logs = <LocalDay, HabitLog>{};

      // December 2023: every day done.
      for (var day = 1; day <= 31; day++) {
        final localDay = LocalDay(2023, 12, day);
        logs[localDay] = testLog(date: localDay);
      }
      // January 2024 up to the 14th done, the 15th open.
      for (var day = 1; day <= 14; day++) {
        final localDay = LocalDay(2024, 1, day);
        logs[localDay] = testLog(date: localDay);
      }

      final trend = monthlyTrend(
        habit: habit,
        logs: logs,
        today: const LocalDay(2024, 1, 15),
        months: 3,
      );

      expect(trend, hasLength(3));
      expect(trend[0].monthStart, const LocalDay(2023, 11, 1));
      expect(trend[0].stats.completedDays, 0);
      expect(trend[1].monthStart, const LocalDay(2023, 12, 1));
      expect(trend[1].stats.completedDays, 31);
      expect(trend[1].stats.dueDays, 31);
      expect(trend[2].monthStart, const LocalDay(2024, 1, 1));
      expect(trend[2].stats.completedDays, 14);
      expect(trend[2].stats.dueDays, 14); // open today excluded
    });
  });

  group('habit insights', () {
    test('totals completions and values', () {
      final habit = testHabit(
        type: HabitType.count,
        targetValue: 8,
        startDate: const LocalDay(2024, 1, 1),
      );
      final logs = {
        const LocalDay(2024, 1, 1): testLog(
          date: const LocalDay(2024, 1, 1),
          status: LogStatus.done,
          value: 8,
        ),
        const LocalDay(2024, 1, 2): testLog(
          date: const LocalDay(2024, 1, 2),
          status: LogStatus.done,
          value: 8,
        ),
        const LocalDay(2024, 1, 3): testLog(
          date: const LocalDay(2024, 1, 3),
          status: LogStatus.partial,
          value: 5,
        ),
        const LocalDay(2024, 1, 4): testLog(
          date: const LocalDay(2024, 1, 4),
          status: LogStatus.skipped,
        ),
      };

      final insights = buildHabitInsights(
        habit: habit,
        logs: logs,
        today: const LocalDay(2024, 1, 15),
        weekStart: 1,
      );

      expect(insights.totalCompletions, 2);
      expect(insights.totalValue, 21);
      expect(insights.averageValue, closeTo(7, 0.001));
      expect(insights.monthlyTrend, hasLength(6));
    });
  });

  group('overall insights', () {
    test('aggregates the week, month, best and worst habits', () {
      final good = testHabit(id: 'good', startDate: const LocalDay(2024, 1, 1));
      final bad = testHabit(id: 'bad', startDate: const LocalDay(2024, 1, 1));

      final goodLogs = <LocalDay, HabitLog>{};
      for (var d = 1; d <= 16; d++) {
        goodLogs[LocalDay(2024, 1, d)] = testLog(
          habitId: 'good',
          date: LocalDay(2024, 1, d),
        );
      }

      final overall = buildOverallInsights(
        habits: [good, bad],
        logsByHabit: {'good': goodLogs, 'bad': const {}},
        today: const LocalDay(2024, 1, 17),
      );

      expect(overall.habitCount, 2);
      expect(overall.bestHabit?.id, 'good');
      expect(overall.worstHabit?.id, 'bad');
      expect(overall.bestRate, 1.0);
      expect(overall.worstRate, 0.0);

      // Week of 15–17 Jan: good is done on 15 and 16; "bad" has no logs on
      // those closed days, so both count as due for the aggregate.
      expect(overall.thisWeek.completedDays, 2);
      expect(overall.thisWeek.dueDays, 4);
    });
  });
}
