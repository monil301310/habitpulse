import 'dart:convert';

import '../entities/app_settings.dart';
import '../entities/habit.dart';
import '../entities/habit_log.dart';
import '../entities/habit_reminder.dart';

/// Builds the downloadable JSON and CSV representations of the user's data.
class ExportBuilder {
  ExportBuilder._();

  static Map<String, Object?> toMap({
    required List<Habit> habits,
    required List<HabitReminder> reminders,
    required List<HabitLog> logs,
    required AppSettings settings,
    required DateTime exportedAt,
  }) {
    final activeHabits =
        habits.where((habit) => !habit.isDeleted).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final activeLogs =
        logs.where((log) => !log.isDeleted).toList()
          ..sort((a, b) {
            final byDate = a.date.toIso().compareTo(b.date.toIso());
            if (byDate != 0) return byDate;
            return a.habitId.compareTo(b.habitId);
          });
    final activeReminders =
        reminders.where((reminder) => !reminder.isDeleted).toList()
          ..sort((a, b) => a.timeOfDay.compareTo(b.timeOfDay));

    return {
      'app': 'HabitPulse',
      'schemaVersion': 1,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'counts': {
        'habits': activeHabits.length,
        'reminders': activeReminders.length,
        'logs': activeLogs.length,
      },
      'settings': _settings(settings),
      'habits': [for (final habit in activeHabits) _habit(habit)],
      'reminders': [
        for (final reminder in activeReminders) _reminder(reminder),
      ],
      'logs': [for (final log in activeLogs) _log(log)],
    };
  }

  static String toJson({
    required List<Habit> habits,
    required List<HabitReminder> reminders,
    required List<HabitLog> logs,
    required AppSettings settings,
    required DateTime exportedAt,
  }) {
    return const JsonEncoder.withIndent('  ').convert(
      toMap(
        habits: habits,
        reminders: reminders,
        logs: logs,
        settings: settings,
        exportedAt: exportedAt,
      ),
    );
  }

  /// One row per logged day, with the habit name resolved for readability.
  static String toCsv({
    required List<Habit> habits,
    required List<HabitLog> logs,
  }) {
    final byId = {for (final habit in habits) habit.id: habit};
    final sorted = logs.where((log) => !log.isDeleted).toList()
      ..sort((a, b) {
        final byDate = a.date.toIso().compareTo(b.date.toIso());
        if (byDate != 0) return byDate;
        return a.habitId.compareTo(b.habitId);
      });

    final buffer = StringBuffer('habit,date,status,value,unit,note\r\n');
    for (final log in sorted) {
      final habit = byId[log.habitId];
      buffer.write(
        [
          habit?.name ?? log.habitId,
          log.date.toIso(),
          log.status.name,
          _number(log.value),
          habit?.unit ?? '',
          log.note ?? '',
        ].map(_escape).join(','),
      );
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  static Map<String, Object?> _habit(Habit habit) => {
    'id': habit.id,
    'name': habit.name,
    'icon': habit.icon,
    'colour': habit.colour,
    'type': habit.type.name,
    'targetValue': habit.targetValue,
    'unit': habit.unit,
    'scheduleType': habit.scheduleType.name,
    'scheduleDays': habit.scheduleDays.toList()..sort(),
    'timesPerWeek': habit.timesPerWeek,
    'startDate': habit.startDate?.toIso(),
    'archivedAt': habit.archivedAt?.toUtc().toIso8601String(),
    'sortOrder': habit.sortOrder,
    'source': habit.source,
    'createdAt': habit.createdAt.toUtc().toIso8601String(),
    'updatedAt': habit.updatedAt.toUtc().toIso8601String(),
  };

  static Map<String, Object?> _reminder(HabitReminder reminder) => {
    'id': reminder.id,
    'habitId': reminder.habitId,
    'timeOfDay': reminder.timeOfDay,
    'daysOfWeek': reminder.daysOfWeek.toList()..sort(),
    'enabled': reminder.enabled,
    'updatedAt': reminder.updatedAt.toUtc().toIso8601String(),
  };

  static Map<String, Object?> _log(HabitLog log) => {
    'id': log.id,
    'habitId': log.habitId,
    'date': log.date.toIso(),
    'value': log.value,
    'status': log.status.name,
    'note': log.note,
    'updatedAt': log.updatedAt.toUtc().toIso8601String(),
  };

  static Map<String, Object?> _settings(AppSettings settings) => {
    'theme': settings.theme,
    'weekStart': settings.weekStart,
    'dayRolloverTime': settings.dayRolloverTime,
    'quietHours': settings.quietHours,
    'recheckTime': settings.recheckTime,
    'morningRecheckTime': settings.morningRecheckTime,
    'notificationSound': settings.notificationSound,
    'updatedAt': settings.updatedAt.toUtc().toIso8601String(),
  };

  static String _number(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  static String _escape(String value) {
    if (value.contains(RegExp(r'[",\r\n]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
