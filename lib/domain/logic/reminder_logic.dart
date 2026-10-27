import '../entities/habit.dart';
import '../entities/habit_log.dart';
import '../entities/habit_reminder.dart';
import '../enums/log_status.dart';
import '../models/local_day.dart';
import 'schedule_logic.dart';

/// One upcoming reminder for one habit on one day.
class ReminderOccurrence {
  const ReminderOccurrence({
    required this.habit,
    required this.reminder,
    required this.day,
    required this.time,
  });

  final Habit habit;
  final HabitReminder reminder;
  final LocalDay day;
  final DayTime time;

  DateTime get dateTime =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// Whether [time] falls inside a quiet-hours window such as `23:00-07:00`.
///
/// Windows may wrap past midnight. An empty or invalid window means no quiet
/// hours, and identical start/end times are treated as "no window".
bool isWithinQuietHours(DayTime time, String quietHours) {
  final separator = quietHours.indexOf('-');
  if (separator <= 0) return false;

  final DayTime start;
  final DayTime end;
  try {
    start = DayTime.parse(quietHours.substring(0, separator).trim());
    end = DayTime.parse(quietHours.substring(separator + 1).trim());
  } on FormatException {
    return false;
  }

  final value = time.minutesSinceMidnight;
  final startMinutes = start.minutesSinceMidnight;
  final endMinutes = end.minutesSinceMidnight;

  if (startMinutes == endMinutes) return false;
  if (startMinutes < endMinutes) {
    return value >= startMinutes && value < endMinutes;
  }
  return value >= startMinutes || value < endMinutes;
}

/// Whether a reminder should fire on [day] for [habit].
///
/// An empty reminder weekday set means "follow the habit's schedule".
bool reminderAppliesOn({
  required Habit habit,
  required HabitReminder reminder,
  required LocalDay day,
}) {
  if (!reminder.enabled || reminder.isDeleted) return false;
  if (!isHabitDueOn(habit, day)) return false;
  if (reminder.daysOfWeek.isNotEmpty &&
      !reminder.daysOfWeek.contains(day.weekday)) {
    return false;
  }
  return true;
}

/// Builds every reminder that should still fire in the next [horizonDays].
///
/// Completed days and times inside quiet hours are excluded, and times in the
/// past are dropped.
List<ReminderOccurrence> upcomingReminderOccurrences({
  required List<Habit> habits,
  required Map<String, List<HabitReminder>> remindersByHabit,
  required Map<String, Map<LocalDay, HabitLog>> logsByHabit,
  required LocalDay today,
  required DateTime now,
  required int horizonDays,
  required String quietHours,
}) {
  final occurrences = <ReminderOccurrence>[];

  for (var offset = 0; offset < horizonDays; offset++) {
    final day = today.addDays(offset);

    for (final habit in habits) {
      if (!isHabitDueOn(habit, day)) continue;

      final log = (logsByHabit[habit.id] ?? const <LocalDay, HabitLog>{})[day];
      if (log?.status == LogStatus.done) continue;

      for (final reminder
          in remindersByHabit[habit.id] ?? const <HabitReminder>[]) {
        if (!reminderAppliesOn(habit: habit, reminder: reminder, day: day)) {
          continue;
        }

        final DayTime time;
        try {
          time = DayTime.parse(reminder.timeOfDay);
        } on FormatException {
          continue;
        }

        if (isWithinQuietHours(time, quietHours)) continue;

        final occurrence = ReminderOccurrence(
          habit: habit,
          reminder: reminder,
          day: day,
          time: time,
        );
        if (!occurrence.dateTime.isAfter(now)) continue;

        occurrences.add(occurrence);
      }
    }
  }

  occurrences.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return occurrences;
}

/// Habits that are due on [day] and still need a decision.
///
/// Done, skipped, missed and slipped days are considered already marked; an
/// unlogged day or a partial count/timed day is still open. Negative habits are
/// included until confirmed because they never complete automatically.
List<Habit> openHabitsForRecheck({
  required List<Habit> habits,
  required Map<String, Map<LocalDay, HabitLog>> logsByHabit,
  required LocalDay day,
}) {
  final open = <Habit>[];

  for (final habit in habits) {
    if (!isHabitDueOn(habit, day)) continue;

    final log = (logsByHabit[habit.id] ?? const <LocalDay, HabitLog>{})[day];
    if (log == null || log.status == LogStatus.partial) {
      open.add(habit);
    }
  }

  return open;
}

/// The recheck body, e.g. `3 habits still open: Read, Gym, Anki`.
String recheckBody(List<Habit> openHabits) {
  if (openHabits.isEmpty) return '';

  final names = openHabits.map((habit) => habit.name).toList();
  final shown = names.take(3).join(', ');
  final extra = names.length > 3 ? ' and ${names.length - 3} more' : '';
  final count = openHabits.length;
  final noun = count == 1 ? 'habit' : 'habits';
  return '$count $noun still open: $shown$extra';
}

/// A stable 31-bit id for a reminder notification.
int notificationIdForOccurrence(ReminderOccurrence occurrence) {
  final key =
      '${occurrence.habit.id}|${occurrence.reminder.id}|'
      '${occurrence.day.toIso()}|${occurrence.time.toStorageString()}';

  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  return hash;
}

/// A stable notification id for a daily recheck (or morning recheck).
int recheckNotificationId(LocalDay day, {bool morning = false}) {
  final base = morning ? 1500000000 : 1400000000;
  return base + (day.differenceInDays(const LocalDay(2020, 1, 1)) & 0xFFFFFF);
}
