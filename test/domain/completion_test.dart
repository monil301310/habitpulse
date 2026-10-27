import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/domain/enums/habit_type.dart';
import 'package:habitpulse/domain/enums/log_status.dart';
import 'package:habitpulse/domain/enums/schedule_type.dart';
import 'package:habitpulse/domain/logic/completion_logic.dart';
import 'package:habitpulse/domain/models/local_day.dart';

import '../support/fixtures.dart';

void main() {
  const today = LocalDay(2024, 1, 15);

  group('completion stats', () {
    test('counts done due days and ignores skips and misses', () {
      final habit = testHabit(startDate: LocalDay(2024, 1, 9));
      final logs = logsFrom({
        const LocalDay(2024, 1, 9): LogStatus.done,
        const LocalDay(2024, 1, 10): LogStatus.done,
        const LocalDay(2024, 1, 11): LogStatus.skipped,
        // 01-12 has no log
        const LocalDay(2024, 1, 13): LogStatus.done,
        const LocalDay(2024, 1, 14): LogStatus.done,
        today: LogStatus.done,
      });

      final stats = completionStatsForLastDays(
        habit: habit,
        logs: logs,
        today: today,
        days: 7,
      );

      expect(stats.completedDays, 5);
      expect(stats.dueDays, 7);
      expect(stats.percent, 71);
    });

    test('an open today is excluded instead of counting as missed', () {
      final habit = testHabit(startDate: LocalDay(2024, 1, 9));
      final logs = logsFrom({
        const LocalDay(2024, 1, 9): LogStatus.done,
        const LocalDay(2024, 1, 10): LogStatus.done,
        const LocalDay(2024, 1, 13): LogStatus.done,
        const LocalDay(2024, 1, 14): LogStatus.done,
        // today deliberately unmarked
      });

      final stats = completionStatsForLastDays(
        habit: habit,
        logs: logs,
        today: today,
        days: 7,
      );

      expect(stats.completedDays, 4);
      expect(stats.dueDays, 6); // today is excluded while open
      expect(stats.percent, 67);
    });

    test('not-due weekdays are excluded from the denominator', () {
      final habit = testHabit(
        scheduleType: ScheduleType.weekdays,
        scheduleDays: {1, 3, 5}, // Mon, Wed, Fri
        startDate: LocalDay(2024, 1, 1),
      );
      // Done on every Monday only.
      final logs = logsFrom({
        const LocalDay(2024, 1, 1): LogStatus.done,
        const LocalDay(2024, 1, 3): LogStatus.missed,
        const LocalDay(2024, 1, 5): LogStatus.done,
        const LocalDay(2024, 1, 8): LogStatus.done,
        const LocalDay(2024, 1, 10): LogStatus.done,
        const LocalDay(2024, 1, 12): LogStatus.missed,
      });

      final stats = completionStatsForLastDays(
        habit: habit,
        logs: logs,
        today: today,
        days: 15,
      );

      // Due days in the window: 01-01, 03, 05, 08, 10, 12 (six).
      expect(stats.dueDays, 6);
      expect(stats.completedDays, 4);
      expect(stats.percent, 67);
    });

    test('all-time stats start at the habit start date', () {
      final habit = testHabit(startDate: LocalDay(2024, 1, 1));
      final logs = logsFrom({
        const LocalDay(2024, 1, 1): LogStatus.done,
        const LocalDay(2024, 1, 2): LogStatus.done,
      });

      final stats = allTimeCompletionStats(
        habit: habit,
        logs: logs,
        today: today,
      );

      // 1–14 Jan are closed and due; today is open and excluded.
      expect(stats.dueDays, 14);
      expect(stats.completedDays, 2);
    });

    test('negative habits count unconfirmed past days as due-but-missed', () {
      final habit = testHabit(
        type: HabitType.negative,
        startDate: LocalDay(2024, 1, 11),
      );
      final logs = logsFrom({
        const LocalDay(2024, 1, 11): LogStatus.done,
        const LocalDay(2024, 1, 12): LogStatus.slipped,
        // 13 and 14 unconfirmed
      });

      final stats = completionStatsForLastDays(
        habit: habit,
        logs: logs,
        today: today,
        days: 5,
      );

      expect(stats.dueDays, 4); // 11–14, today excluded while unconfirmed
      expect(stats.completedDays, 1);
      expect(stats.percent, 25);
    });

    test('an empty range yields a zero rate instead of dividing by zero', () {
      final habit = testHabit(startDate: today.addDays(5));
      final stats = completionStatsForLastDays(
        habit: habit,
        logs: {},
        today: today,
        days: 7,
      );

      expect(stats.dueDays, 0);
      expect(stats.rate, 0);
      expect(stats.percent, 0);
    });

    test('a range in the future is empty', () {
      final stats = completionStats(
        habit: testHabit(),
        logs: {},
        from: today.addDays(5),
        to: today.addDays(10),
        today: today,
      );
      expect(stats.dueDays, 0);
    });
  });
}
