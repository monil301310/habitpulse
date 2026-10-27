import 'package:habitpulse/domain/entities/habit.dart';
import 'package:habitpulse/domain/entities/habit_log.dart';
import 'package:habitpulse/domain/entities/habit_reminder.dart';
import 'package:habitpulse/domain/enums/habit_type.dart';
import 'package:habitpulse/domain/enums/log_status.dart';
import 'package:habitpulse/domain/enums/schedule_type.dart';
import 'package:habitpulse/domain/models/local_day.dart';

final DateTime _epoch = DateTime.utc(2026, 1, 1);

Habit testHabit({
  String id = 'h1',
  HabitType type = HabitType.yesNo,
  ScheduleType scheduleType = ScheduleType.daily,
  Set<int> scheduleDays = const {1, 2, 3, 4, 5, 6, 7},
  int? timesPerWeek,
  double? targetValue,
  LocalDay? startDate,
  DateTime? createdAt,
}) {
  final now = createdAt ?? _epoch;
  return Habit(
    id: id,
    userId: 'local',
    name: 'Test habit',
    icon: 'bolt',
    colour: '#4ADE80',
    type: type,
    targetValue: targetValue,
    scheduleType: scheduleType,
    scheduleDays: scheduleDays,
    timesPerWeek: timesPerWeek,
    startDate: startDate,
    createdAt: now,
    updatedAt: now,
  );
}

HabitLog testLog({
  String habitId = 'h1',
  required LocalDay date,
  LogStatus status = LogStatus.done,
  double value = 0,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  return HabitLog(
    id: 'log-$habitId-${date.toIso()}-${status.name}',
    habitId: habitId,
    date: date,
    status: status,
    value: value,
    updatedAt: updatedAt ?? _epoch,
    deletedAt: deletedAt,
  );
}

/// Builds a `LocalDay -> HabitLog` map from `day -> status` pairs.
Map<LocalDay, HabitLog> logsFrom(
  Map<LocalDay, LogStatus> entries, {
  String habitId = 'h1',
}) {
  return {
    for (final entry in entries.entries)
      entry.key: testLog(
        habitId: habitId,
        date: entry.key,
        status: entry.value,
      ),
  };
}

HabitReminder testReminder({
  String id = 'r1',
  String habitId = 'h1',
  String timeOfDay = '09:00',
  Set<int> daysOfWeek = const <int>{},
  bool enabled = true,
}) {
  return HabitReminder(
    id: id,
    habitId: habitId,
    timeOfDay: timeOfDay,
    daysOfWeek: daysOfWeek,
    enabled: enabled,
    updatedAt: _epoch,
  );
}
