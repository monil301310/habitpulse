import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/domain/entities/habit_log.dart';
import 'package:habitpulse/domain/entities/habit_reminder.dart';
import 'package:habitpulse/domain/enums/log_status.dart';
import 'package:habitpulse/domain/enums/schedule_type.dart';
import 'package:habitpulse/domain/logic/reminder_logic.dart';
import 'package:habitpulse/domain/models/local_day.dart';

import '../support/fixtures.dart';

void main() {
  const today = LocalDay(2024, 1, 15); // Monday

  group('quiet hours', () {
    test('handles a window that wraps past midnight', () {
      const quiet = '23:00-07:00';
      expect(isWithinQuietHours(const DayTime(23, 30), quiet), isTrue);
      expect(isWithinQuietHours(const DayTime(0, 30), quiet), isTrue);
      expect(isWithinQuietHours(const DayTime(6, 59), quiet), isTrue);
      expect(isWithinQuietHours(const DayTime(7, 0), quiet), isFalse);
      expect(isWithinQuietHours(const DayTime(22, 59), quiet), isFalse);
      expect(isWithinQuietHours(const DayTime(12, 0), quiet), isFalse);
    });

    test('handles a same-day window', () {
      const quiet = '09:00-17:00';
      expect(isWithinQuietHours(const DayTime(9, 0), quiet), isTrue);
      expect(isWithinQuietHours(const DayTime(12, 0), quiet), isTrue);
      expect(isWithinQuietHours(const DayTime(17, 0), quiet), isFalse);
      expect(isWithinQuietHours(const DayTime(8, 59), quiet), isFalse);
    });

    test('treats empty or malformed windows as disabled', () {
      expect(isWithinQuietHours(const DayTime(12, 0), ''), isFalse);
      expect(isWithinQuietHours(const DayTime(12, 0), 'nonsense'), isFalse);
      expect(isWithinQuietHours(const DayTime(12, 0), '10:00-10:00'), isFalse);
    });
  });

  group('reminder applicability', () {
    test('follows the habit schedule when no days are set', () {
      final habit = testHabit(
        scheduleType: ScheduleType.weekdays,
        scheduleDays: {1, 3, 5},
        startDate: const LocalDay(2024, 1, 1),
      );
      final reminder = testReminder(timeOfDay: '09:00');

      expect(
        reminderAppliesOn(
          habit: habit,
          reminder: reminder,
          day: const LocalDay(2024, 1, 15), // Monday
        ),
        isTrue,
      );
      expect(
        reminderAppliesOn(
          habit: habit,
          reminder: reminder,
          day: const LocalDay(2024, 1, 16), // Tuesday, not due
        ),
        isFalse,
      );
    });

    test('restricts to the reminder’s own weekdays', () {
      final habit = testHabit(startDate: const LocalDay(2024, 1, 1));
      final reminder = testReminder(daysOfWeek: {3});

      expect(
        reminderAppliesOn(
          habit: habit,
          reminder: reminder,
          day: const LocalDay(2024, 1, 17), // Wednesday
        ),
        isTrue,
      );
      expect(
        reminderAppliesOn(
          habit: habit,
          reminder: reminder,
          day: const LocalDay(2024, 1, 15), // Monday
        ),
        isFalse,
      );
    });

    test('disabled reminders never apply', () {
      final habit = testHabit(startDate: const LocalDay(2024, 1, 1));
      expect(
        reminderAppliesOn(
          habit: habit,
          reminder: testReminder(enabled: false),
          day: today,
        ),
        isFalse,
      );
    });
  });

  group('upcoming occurrences', () {
    final habit = testHabit(startDate: const LocalDay(2024, 1, 1));

    List<ReminderOccurrence> occurrences({
      required Map<String, List<HabitReminder>> reminders,
      Map<String, Map<LocalDay, HabitLog>> logs = const {},
      String quietHours = '',
      int horizonDays = 2,
      DateTime? now,
    }) {
      return upcomingReminderOccurrences(
        habits: [habit],
        remindersByHabit: reminders,
        logsByHabit: logs,
        today: today,
        now: now ?? DateTime(2024, 1, 15, 9, 0),
        horizonDays: horizonDays,
        quietHours: quietHours,
      );
    }

    test('drops past times and keeps future days', () {
      final result = occurrences(
        reminders: {
          'h1': [
            testReminder(id: 'r1', timeOfDay: '08:00'),
            testReminder(id: 'r2', timeOfDay: '20:00'),
          ],
        },
      );

      // 08:00 has already passed; today 20:00 and tomorrow's two remain.
      expect(result, hasLength(3));
      expect(result.first.day, today);
      expect(result.first.time, const DayTime(20, 0));
      expect(result.last.day, today.addDays(1));
    });

    test('skips a day that is already completed', () {
      final result = occurrences(
        reminders: {
          'h1': [testReminder(id: 'r1', timeOfDay: '20:00')],
        },
        logs: {
          'h1': logsFrom({today: LogStatus.done}),
        },
      );

      expect(result.map((o) => o.day), [today.addDays(1)]);
    });

    test('skips times inside quiet hours', () {
      final result = occurrences(
        reminders: {
          'h1': [
            testReminder(id: 'r1', timeOfDay: '08:00'),
            testReminder(id: 'r2', timeOfDay: '20:00'),
          ],
        },
        quietHours: '19:00-22:00',
      );

      expect(result.map((o) => o.time), [const DayTime(8, 0)]);
    });

    test('honours the reminder’s weekday restriction', () {
      final result = occurrences(
        reminders: {
          'h1': [
            testReminder(id: 'r1', timeOfDay: '20:00', daysOfWeek: {1}),
          ],
        },
        horizonDays: 8,
      );

      // Mondays only: today (15 Jan) and next Monday (22 Jan).
      expect(result, hasLength(2));
      expect(result.every((o) => o.day.weekday == 1), isTrue);
    });
  });

  group('recheck selection', () {
    test('includes open and partial days, excludes marked days', () {
      final open = testHabit(id: 'open', startDate: const LocalDay(2024, 1, 1));
      final done = testHabit(id: 'done', startDate: const LocalDay(2024, 1, 1));
      final skipped = testHabit(
        id: 'skipped',
        startDate: const LocalDay(2024, 1, 1),
      );
      final missed = testHabit(
        id: 'missed',
        startDate: const LocalDay(2024, 1, 1),
      );
      final partial = testHabit(
        id: 'partial',
        startDate: const LocalDay(2024, 1, 1),
      );

      final result = openHabitsForRecheck(
        habits: [open, done, skipped, missed, partial],
        logsByHabit: {
          'done': logsFrom({today: LogStatus.done}, habitId: 'done'),
          'skipped': logsFrom({today: LogStatus.skipped}, habitId: 'skipped'),
          'missed': logsFrom({today: LogStatus.missed}, habitId: 'missed'),
          'partial': logsFrom({today: LogStatus.partial}, habitId: 'partial'),
        },
        day: today,
      );

      expect(result.map((h) => h.id), containsAll(['open', 'partial']));
      expect(result.map((h) => h.id), isNot(contains('done')));
      expect(result.map((h) => h.id), isNot(contains('skipped')));
      expect(result.map((h) => h.id), isNot(contains('missed')));
    });
  });

  group('recheck body', () {
    test('summarises up to three names', () {
      final habits = [
        testHabit(id: 'a'),
        testHabit(id: 'b'),
        testHabit(id: 'c'),
        testHabit(id: 'd'),
      ].map((h) => h.copyWith(name: 'Habit ${h.id}')).toList();

      expect(recheckBody(habits.take(1).toList()), contains('1 habit still open'));
      expect(
        recheckBody(habits),
        '4 habits still open: Habit a, Habit b, Habit c and 1 more',
      );
      expect(recheckBody(const []), '');
    });
  });

  group('notification ids', () {
    test('are stable and distinct per day', () {
      final habit = testHabit();
      final reminder = testReminder(id: 'r1');
      final first = ReminderOccurrence(
        habit: habit,
        reminder: reminder,
        day: today,
        time: const DayTime(9, 0),
      );
      final second = ReminderOccurrence(
        habit: habit,
        reminder: reminder,
        day: today.addDays(1),
        time: const DayTime(9, 0),
      );

      expect(notificationIdForOccurrence(first), notificationIdForOccurrence(first));
      expect(notificationIdForOccurrence(first), isNot(notificationIdForOccurrence(second)));
      expect(notificationIdForOccurrence(first), lessThan(0x80000000));
      expect(recheckNotificationId(today), isNot(recheckNotificationId(today, morning: true)));
    });
  });
}
