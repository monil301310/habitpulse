import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/domain/enums/habit_type.dart';
import 'package:habitpulse/domain/enums/log_status.dart';
import 'package:habitpulse/domain/enums/schedule_type.dart';
import 'package:habitpulse/domain/logic/streak_logic.dart';
import 'package:habitpulse/domain/models/local_day.dart';

import '../support/fixtures.dart';

void main() {
  // Anchor around Monday 2024-01-15.
  const mon = LocalDay(2024, 1, 15); // today
  const sun = LocalDay(2024, 1, 14);
  const sat = LocalDay(2024, 1, 13);
  const fri = LocalDay(2024, 1, 12);
  const thu = LocalDay(2024, 1, 11);

  group('daily streaks', () {
    test('today being open does not break a run ending yesterday', () {
      final habit = testHabit(startDate: thu);
      final logs = logsFrom({
        thu: LogStatus.done,
        fri: LogStatus.done,
        sat: LogStatus.done,
        sun: LogStatus.done,
      });

      final result = currentStreak(
        habit: habit,
        logs: logs,
        today: mon,
        weekStart: 1,
      );

      expect(result.length, 4);
      expect(result.unit, StreakUnit.days);
      expect(result.label, '4d');
    });

    test('today being done extends the streak', () {
      final habit = testHabit(startDate: thu);
      final logs = logsFrom({
        thu: LogStatus.done,
        fri: LogStatus.done,
        sat: LogStatus.done,
        sun: LogStatus.done,
        mon: LogStatus.done,
      });

      expect(
        currentStreak(habit: habit, logs: logs, today: mon, weekStart: 1).length,
        5,
      );
    });

    test('a missed day breaks the streak', () {
      final habit = testHabit(startDate: thu);
      final logs = logsFrom({
        thu: LogStatus.done,
        fri: LogStatus.done,
        sat: LogStatus.missed,
        sun: LogStatus.done,
      });

      expect(
        currentStreak(habit: habit, logs: logs, today: mon, weekStart: 1).length,
        1,
      );
    });

    test('a skipped day neither extends nor breaks the streak', () {
      final habit = testHabit(startDate: thu);
      final logs = logsFrom({
        thu: LogStatus.done,
        fri: LogStatus.skipped,
        sat: LogStatus.done,
        sun: LogStatus.done,
      });

      // Three completed due days with a deliberate skip between them.
      expect(
        currentStreak(habit: habit, logs: logs, today: mon, weekStart: 1).length,
        3,
      );
    });

    test('a partial past day counts as not completed and breaks it', () {
      final habit = testHabit(
        type: HabitType.count,
        targetValue: 8,
        startDate: sat,
      );
      final logs = {
        sat: testLog(date: sat, status: LogStatus.done, value: 8),
        sun: testLog(date: sun, status: LogStatus.partial, value: 3),
      };

      expect(
        currentStreak(habit: habit, logs: logs, today: mon, weekStart: 1).length,
        0,
      );
    });

    test('a partial today stays open and does not break it', () {
      final habit = testHabit(
        type: HabitType.count,
        targetValue: 8,
        startDate: sun,
      );
      final logs = {
        sun: testLog(date: sun, status: LogStatus.done, value: 8),
        mon: testLog(date: mon, status: LogStatus.partial, value: 5),
      };

      expect(
        currentStreak(habit: habit, logs: logs, today: mon, weekStart: 1).length,
        1,
      );
    });

    test('no logs and no start date gives a zero streak', () {
      final result = currentStreak(
        habit: testHabit(),
        logs: {},
        today: mon,
        weekStart: 1,
      );
      expect(result.length, 0);
      expect(result.unit, StreakUnit.days);
    });

    test('a habit that starts in the future has no streak', () {
      final habit = testHabit(startDate: LocalDay(2024, 2, 1));
      expect(
        currentStreak(habit: habit, logs: {}, today: mon, weekStart: 1).length,
        0,
      );
    });
  });

  group('negative habits', () {
    test('an unconfirmed today does not break or extend the streak', () {
      final habit = testHabit(
        type: HabitType.negative,
        startDate: sun,
      );
      final logs = logsFrom({sun: LogStatus.done});

      expect(
        currentStreak(habit: habit, logs: logs, today: mon, weekStart: 1).length,
        1,
      );
    });

    test('a past unconfirmed day counts as missed and breaks it', () {
      final habit = testHabit(
        type: HabitType.negative,
        startDate: sat,
      );
      final logs = logsFrom({sat: LogStatus.done});

      expect(
        currentStreak(habit: habit, logs: logs, today: mon, weekStart: 1).length,
        0,
      );
    });

    test('a slip breaks the streak and only later days count', () {
      final habit = testHabit(
        type: HabitType.negative,
        startDate: thu,
      );
      final logs = logsFrom({
        thu: LogStatus.done,
        fri: LogStatus.done,
        sat: LogStatus.slipped,
        sun: LogStatus.done,
      });

      // The two days before the slip no longer count; Sunday starts a new run.
      expect(
        currentStreak(habit: habit, logs: logs, today: mon, weekStart: 1).length,
        1,
      );
    });

    test('an explicit miss today breaks it immediately', () {
      final habit = testHabit(
        type: HabitType.negative,
        startDate: sun,
      );
      final logs = logsFrom({
        sun: LogStatus.done,
        mon: LogStatus.missed,
      });

      expect(
        currentStreak(habit: habit, logs: logs, today: mon, weekStart: 1).length,
        0,
      );
    });
  });

  group('weekday-only streaks', () {
    // Mon/Wed/Fri habit starting Monday 2024-01-01.
    const week1Mon = LocalDay(2024, 1, 1);
    const week1Wed = LocalDay(2024, 1, 3);
    const week1Fri = LocalDay(2024, 1, 5);
    const week2Mon = LocalDay(2024, 1, 8);
    const week2Wed = LocalDay(2024, 1, 10);
    const week2Fri = LocalDay(2024, 1, 12);
    const sundayAfter = LocalDay(2024, 1, 14);

    test('days that are not due are neutral and do not break the streak', () {
      final habit = testHabit(
        scheduleType: ScheduleType.weekdays,
        scheduleDays: {1, 3, 5},
        startDate: week1Mon,
      );
      final logs = logsFrom({
        week1Mon: LogStatus.done,
        week1Wed: LogStatus.done,
        week1Fri: LogStatus.done,
        week2Mon: LogStatus.done,
        week2Wed: LogStatus.done,
        week2Fri: LogStatus.done,
      });

      final result = currentStreak(
        habit: habit,
        logs: logs,
        today: sundayAfter,
        weekStart: 1,
      );

      // Tue/Thu/Sat/Sun are not due and are skipped over.
      expect(result.length, 6);
      expect(result.unit, StreakUnit.days);
    });

    test('a missed due day breaks it even with neutral days around', () {
      final habit = testHabit(
        scheduleType: ScheduleType.weekdays,
        scheduleDays: {1, 3, 5},
        startDate: week1Mon,
      );
      final logs = logsFrom({
        week1Mon: LogStatus.done,
        week1Wed: LogStatus.done,
        week1Fri: LogStatus.done,
        week2Mon: LogStatus.done,
        week2Wed: LogStatus.done,
        // week2Fri deliberately missing
      });

      expect(
        currentStreak(
          habit: habit,
          logs: logs,
          today: sundayAfter,
          weekStart: 1,
        ).length,
        0,
      );
    });
  });

  group('times-per-week streaks', () {
    const week1 = LocalDay(2024, 1, 1);
    const week2 = LocalDay(2024, 1, 8);
    const week3 = LocalDay(2024, 1, 15);
    const today = LocalDay(2024, 1, 17); // Wednesday of week 3

    test('counts consecutive satisfied weeks, ignoring the in-progress week', () {
      final habit = testHabit(
        scheduleType: ScheduleType.timesPerWeek,
        timesPerWeek: 3,
        startDate: week1,
      );
      final logs = logsFrom({
        week1: LogStatus.done,
        week1.addDays(2): LogStatus.done,
        week1.addDays(4): LogStatus.done,
        week2.addDays(1): LogStatus.done,
        week2.addDays(3): LogStatus.done,
        week2.addDays(5): LogStatus.done,
        week3: LogStatus.done, // only one so far this week
      });

      final result = currentStreak(
        habit: habit,
        logs: logs,
        today: today,
        weekStart: 1,
      );

      expect(result.length, 2);
      expect(result.unit, StreakUnit.weeks);
      expect(result.label, '2w');
    });

    test('an already-satisfied current week is included', () {
      final habit = testHabit(
        scheduleType: ScheduleType.timesPerWeek,
        timesPerWeek: 3,
        startDate: week1,
      );
      final logs = logsFrom({
        week1: LogStatus.done,
        week1.addDays(2): LogStatus.done,
        week1.addDays(4): LogStatus.done,
        week2.addDays(1): LogStatus.done,
        week2.addDays(3): LogStatus.done,
        week2.addDays(5): LogStatus.done,
        week3: LogStatus.done,
        week3.addDays(1): LogStatus.done,
        week3.addDays(2): LogStatus.done,
      });

      expect(
        currentStreak(
          habit: habit,
          logs: logs,
          today: today,
          weekStart: 1,
        ).length,
        3,
      );
    });

    test('a failed previous week resets the streak to zero', () {
      final habit = testHabit(
        scheduleType: ScheduleType.timesPerWeek,
        timesPerWeek: 3,
        startDate: week1,
      );
      final logs = logsFrom({
        week1: LogStatus.done,
        week1.addDays(2): LogStatus.done,
        week1.addDays(4): LogStatus.done,
        // week 2 only reaches two completions
        week2.addDays(1): LogStatus.done,
        week2.addDays(3): LogStatus.done,
        week3: LogStatus.done,
      });

      expect(
        currentStreak(
          habit: habit,
          logs: logs,
          today: today,
          weekStart: 1,
        ).length,
        0,
      );
    });

    test('a custom week start changes which days belong together', () {
      // Sunday-start weeks: 2024-01-07 and 2024-01-14.
      const sundayWeek1 = LocalDay(2024, 1, 7);
      const sundayWeek2 = LocalDay(2024, 1, 14);
      final habit = testHabit(
        scheduleType: ScheduleType.timesPerWeek,
        timesPerWeek: 2,
        startDate: sundayWeek1,
      );
      final logs = logsFrom({
        sundayWeek1: LogStatus.done,
        sundayWeek1.addDays(3): LogStatus.done,
        sundayWeek2: LogStatus.done,
        sundayWeek2.addDays(2): LogStatus.done,
      });

      expect(
        currentStreak(
          habit: habit,
          logs: logs,
          today: LocalDay(2024, 1, 17),
          weekStart: 7,
        ).length,
        2,
      );
    });
  });

  group('longest streak', () {
    test('finds the best daily run in history', () {
      final habit = testHabit(startDate: thu);
      final logs = logsFrom({
        thu: LogStatus.done,
        fri: LogStatus.done,
        sat: LogStatus.missed,
        sun: LogStatus.done,
        mon: LogStatus.done,
      });

      expect(
        longestStreak(habit: habit, logs: logs, today: mon, weekStart: 1).length,
        2,
      );
    });

    test('a skip does not break the longest run', () {
      final habit = testHabit(startDate: thu);
      final logs = logsFrom({
        thu: LogStatus.done,
        fri: LogStatus.skipped,
        sat: LogStatus.done,
        sun: LogStatus.done,
      });

      expect(
        longestStreak(habit: habit, logs: logs, today: mon, weekStart: 1).length,
        3,
      );
    });

    test('finds the best weekly run', () {
      const week1 = LocalDay(2024, 1, 1);
      final habit = testHabit(
        scheduleType: ScheduleType.timesPerWeek,
        timesPerWeek: 2,
        startDate: week1,
      );

      // Weeks 1 and 2 succeeded, week 3 failed, week 4 succeeded.
      final logs = logsFrom({
        week1: LogStatus.done,
        week1.addDays(1): LogStatus.done,
        week1.addDays(7): LogStatus.done,
        week1.addDays(8): LogStatus.done,
        week1.addDays(21): LogStatus.done,
        week1.addDays(22): LogStatus.done,
      });

      // "Today" sits in the following week so weeks 1–4 are all closed.
      final result = longestStreak(
        habit: habit,
        logs: logs,
        today: LocalDay(2024, 2, 1),
        weekStart: 1,
      );

      expect(result.length, 2);
      expect(result.unit, StreakUnit.weeks);
    });
  });
}
