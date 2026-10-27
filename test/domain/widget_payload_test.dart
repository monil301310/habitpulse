import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/domain/entities/habit_log.dart';
import 'package:habitpulse/domain/enums/schedule_type.dart';
import 'package:habitpulse/domain/models/local_day.dart';
import 'package:habitpulse/domain/widgets/widget_payload.dart';

import '../support/fixtures.dart';

void main() {
  const today = LocalDay(2024, 1, 15); // Monday

  test('includes only due habits and flags done days', () {
    final daily = testHabit(id: 'daily', startDate: const LocalDay(2024, 1, 1));
    final weekdays = testHabit(
      id: 'weekdays',
      scheduleType: ScheduleType.weekdays,
      scheduleDays: {1, 3, 5},
      startDate: const LocalDay(2024, 1, 1),
    );
    final notDue = testHabit(
      id: 'notDue',
      scheduleType: ScheduleType.weekdays,
      scheduleDays: {2},
      startDate: const LocalDay(2024, 1, 1),
    );

    final payload = buildWidgetChecklistPayload(
      habits: [daily, weekdays, notDue],
      logsByHabit: {
        'daily': {today: testLog(date: today)},
      },
      today: today,
    );

    expect(payload.total, 2);
    expect(payload.done, 1);
    expect(payload.rows.map((r) => r.id), ['daily', 'weekdays']);
    expect(payload.rows.first.done, isTrue);
    expect(payload.rows.last.done, isFalse);
    expect(payload.more, 0);
  });

  test('caps rows and reports the remainder', () {
    final habits = [
      for (var i = 0; i < 8; i++)
        testHabit(id: 'h$i', startDate: const LocalDay(2024, 1, 1)),
    ];

    final payload = buildWidgetChecklistPayload(
      habits: habits,
      logsByHabit: const <String, Map<LocalDay, HabitLog>>{},
      today: today,
      maxRows: 3,
    );

    expect(payload.rows, hasLength(3));
    expect(payload.total, 8);
    expect(payload.more, 5);
    expect(payload.done, 0);
  });

  test('handles an empty day', () {
    final payload = buildWidgetChecklistPayload(
      habits: const [],
      logsByHabit: const {},
      today: today,
    );
    expect(payload.total, 0);
    expect(payload.rows, isEmpty);
    expect(payload.toJson()['date'], '2024-01-15');
  });
}
