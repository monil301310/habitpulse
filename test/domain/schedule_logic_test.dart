import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/domain/enums/log_status.dart';
import 'package:habitpulse/domain/enums/schedule_type.dart';
import 'package:habitpulse/domain/logic/schedule_logic.dart';
import 'package:habitpulse/domain/models/local_day.dart';

import '../support/fixtures.dart';

void main() {
  // 2024-01-01 is a Monday.
  const monday = LocalDay(2024, 1, 1);
  const tuesday = LocalDay(2024, 1, 2);
  const wednesday = LocalDay(2024, 1, 3);
  const thursday = LocalDay(2024, 1, 4);
  const friday = LocalDay(2024, 1, 5);
  const saturday = LocalDay(2024, 1, 6);
  const sunday = LocalDay(2024, 1, 7);

  group('isHabitDueOn', () {
    test('daily habits are due every day', () {
      final habit = testHabit();
      for (final day in [monday, tuesday, wednesday, sunday]) {
        expect(isHabitDueOn(habit, day), isTrue);
      }
    });

    test('weekday habits are only due on the chosen days', () {
      final habit = testHabit(
        scheduleType: ScheduleType.weekdays,
        scheduleDays: {1, 3, 5}, // Mon, Wed, Fri
      );

      expect(isHabitDueOn(habit, monday), isTrue);
      expect(isHabitDueOn(habit, tuesday), isFalse);
      expect(isHabitDueOn(habit, wednesday), isTrue);
      expect(isHabitDueOn(habit, thursday), isFalse);
      expect(isHabitDueOn(habit, friday), isTrue);
      expect(isHabitDueOn(habit, saturday), isFalse);
      expect(isHabitDueOn(habit, sunday), isFalse);
    });

    test('times-per-week habits are due on any day', () {
      final habit = testHabit(
        scheduleType: ScheduleType.timesPerWeek,
        timesPerWeek: 3,
      );
      for (final day in [monday, thursday, sunday]) {
        expect(isHabitDueOn(habit, day), isTrue);
      }
    });

    test('days before the start date are never due', () {
      final habit = testHabit(startDate: wednesday);
      expect(isHabitDueOn(habit, tuesday), isFalse);
      expect(isHabitDueOn(habit, wednesday), isTrue);
      expect(isHabitDueOn(habit, friday), isTrue);
    });
  });

  group('logsByDay', () {
    test('indexes logs by day and skips soft-deleted rows', () {
      final logs = [
        testLog(date: monday),
        testLog(date: tuesday, deletedAt: DateTime.utc(2024, 1, 2)),
      ];

      final byDay = logsByDay(logs);
      expect(byDay.keys, contains(monday));
      expect(byDay.keys, isNot(contains(tuesday)));
    });
  });

  group('weekly completion counting', () {
    test('counts only done days in the seven-day span', () {
      final logs = logsFrom({
        monday: LogStatus.done,
        tuesday: LogStatus.skipped,
        wednesday: LogStatus.done,
        thursday: LogStatus.partial,
        friday: LogStatus.missed,
        saturday: LogStatus.done,
      });

      expect(completionsInWeek(logs, monday), 3);
    });

    test('does not count days from the next week', () {
      final logs = logsFrom({
        sunday: LogStatus.done,
        const LocalDay(2024, 1, 8): LogStatus.done, // next Monday
      });
      expect(completionsInWeek(logs, monday), 1);
    });

    test('is satisfied once the weekly target is reached', () {
      final habit = testHabit(
        scheduleType: ScheduleType.timesPerWeek,
        timesPerWeek: 3,
      );
      final two = logsFrom({
        monday: LogStatus.done,
        wednesday: LogStatus.done,
      });
      final three = logsFrom({
        monday: LogStatus.done,
        wednesday: LogStatus.done,
        friday: LogStatus.done,
      });

      expect(isWeekSatisfied(habit, two, monday), isFalse);
      expect(isWeekSatisfied(habit, three, monday), isTrue);
    });

    test('defaults a missing weekly target to one', () {
      final habit = testHabit(scheduleType: ScheduleType.timesPerWeek);
      expect(effectiveWeeklyTarget(habit), 1);
    });
  });

  group('earliestRelevantDay', () {
    test('prefers an earlier start date over later logs', () {
      final habit = testHabit(startDate: monday);
      final logs = logsFrom({friday: LogStatus.done});
      expect(earliestRelevantDay(habit, logs), monday);
    });

    test('falls back to the earliest log when there is no start date', () {
      final habit = testHabit();
      final logs = logsFrom({
        wednesday: LogStatus.done,
        monday: LogStatus.done,
      });
      expect(earliestRelevantDay(habit, logs), monday);
    });

    test('returns null when there is neither a start date nor a log', () {
      expect(earliestRelevantDay(testHabit(), {}), isNull);
    });
  });
}
