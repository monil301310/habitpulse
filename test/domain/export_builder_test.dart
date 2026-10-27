import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/domain/entities/app_settings.dart';
import 'package:habitpulse/domain/entities/habit_log.dart';
import 'package:habitpulse/domain/entities/habit_reminder.dart';
import 'package:habitpulse/domain/enums/log_status.dart';
import 'package:habitpulse/domain/export/export_builder.dart';
import 'package:habitpulse/domain/models/local_day.dart';

import '../support/fixtures.dart';

void main() {
  final stamp = DateTime.utc(2026, 10, 27, 12);
  final habit = testHabit(
    id: 'h1',
    startDate: const LocalDay(2026, 1, 1),
  ).copyWith(name: 'Read');

  final log = HabitLog(
    id: 'l1',
    habitId: 'h1',
    date: const LocalDay(2026, 10, 26),
    value: 20,
    status: LogStatus.done,
    note: 'Chapter 3, "The beginning"',
    updatedAt: stamp,
  );

  final reminder = HabitReminder(
    id: 'r1',
    habitId: 'h1',
    timeOfDay: '08:30',
    daysOfWeek: const {1, 3, 5},
    updatedAt: stamp,
  );

  final settings = AppSettings.defaults(now: stamp);

  test('JSON includes habits, reminders, logs, settings and counts', () {
    final map = ExportBuilder.toMap(
      habits: [habit],
      reminders: [reminder],
      logs: [log],
      settings: settings,
      exportedAt: stamp,
    );

    expect(map['app'], 'HabitPulse');
    expect(map['counts'], {'habits': 1, 'reminders': 1, 'logs': 1});
    expect((map['habits'] as List).single['name'], 'Read');
    expect((map['reminders'] as List).single['daysOfWeek'], [1, 3, 5]);
    expect((map['logs'] as List).single['date'], '2026-10-26');
    expect((map['settings'] as Map)['theme'], 'dark');
  });

  test('JSON string is pretty-printed and parses', () {
    final json = ExportBuilder.toJson(
      habits: [habit],
      reminders: const [],
      logs: [log],
      settings: settings,
      exportedAt: stamp,
    );
    expect(json, contains('\n  "habits"'));
    expect(json, contains('"exportedAt": "2026-10-27T12:00:00.000Z"'));
  });

  test('CSV escapes commas and quotes, and resolves habit names', () {
    final csv = ExportBuilder.toCsv(habits: [habit], logs: [log]);
    final lines = csv.trim().split('\r\n');

    expect(lines.first, 'habit,date,status,value,unit,note');
    expect(lines[1], startsWith('Read,2026-10-26,done,20,'));
    expect(lines[1], contains('"Chapter 3, ""The beginning"""'));
  });

  test('CSV keeps unknown habit ids and sorts by date', () {
    final later = HabitLog(
      id: 'l2',
      habitId: 'missing',
      date: const LocalDay(2026, 10, 27),
      status: LogStatus.missed,
      updatedAt: stamp,
    );
    final csv = ExportBuilder.toCsv(habits: [habit], logs: [later, log]);
    final lines = csv.trim().split('\r\n');

    expect(lines[1], startsWith('Read,'));
    expect(lines[2], startsWith('missing,2026-10-27,missed,0'));
  });
}
