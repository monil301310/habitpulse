import '../../domain/entities/app_settings.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/entities/habit_reminder.dart';
import '../../domain/logic/reminder_logic.dart';
import '../../domain/logic/streak_logic.dart';
import '../../domain/models/local_day.dart';
import 'notification_content.dart';
import 'notification_service.dart';

/// Rebuilds the whole upcoming notification schedule from local data.
///
/// Called on start-up and whenever habits, reminders, logs or settings change.
/// Every rebuild cancels the previous schedule first, so reminders for already
/// completed days disappear.
class ReminderScheduler {
  ReminderScheduler(this._notifications);

  final NotificationService _notifications;

  static const int horizonDays = 7;
  static const int maxReminders = 180;

  Future<void> rebuild({
    required List<Habit> habits,
    required Map<String, List<HabitReminder>> remindersByHabit,
    required Map<String, Map<LocalDay, HabitLog>> logsByHabit,
    required AppSettings settings,
    required LocalDay today,
    required DateTime now,
    required int weekStart,
  }) async {
    await _notifications.cancelAll();

    final occurrences = upcomingReminderOccurrences(
      habits: habits,
      remindersByHabit: remindersByHabit,
      logsByHabit: logsByHabit,
      today: today,
      now: now,
      horizonDays: horizonDays,
      quietHours: settings.quietHours,
    );

    for (final occurrence in occurrences.take(maxReminders)) {
      final habitLogs =
          logsByHabit[occurrence.habit.id] ?? const <LocalDay, HabitLog>{};
      final streak = currentStreak(
        habit: occurrence.habit,
        logs: habitLogs,
        today: today,
        weekStart: weekStart,
      );

      await _notifications.schedule(
        NotificationRequest(
          id: notificationIdForOccurrence(occurrence),
          title: occurrence.habit.name,
          body: streak.length == 0
              ? 'Time to check in'
              : '${streak.label} streak · Tap to check in',
          when: occurrence.dateTime,
          payload: reminderPayload(
            habitId: occurrence.habit.id,
            date: occurrence.day.toIso(),
          ),
          actions: reminderActionsFor(occurrence.habit),
          playSound: settings.notificationSound,
        ),
      );
    }

    await _scheduleRechecks(
      habits: habits,
      logsByHabit: logsByHabit,
      settings: settings,
      today: today,
      now: now,
    );

    await _scheduleMorningRechecks(
      habits: habits,
      logsByHabit: logsByHabit,
      settings: settings,
      today: today,
      now: now,
    );
  }

  Future<void> _scheduleRechecks({
    required List<Habit> habits,
    required Map<String, Map<LocalDay, HabitLog>> logsByHabit,
    required AppSettings settings,
    required LocalDay today,
    required DateTime now,
  }) async {
    final DayTime time;
    try {
      time = DayTime.parse(settings.recheckTime);
    } on FormatException {
      return;
    }

    for (var offset = 0; offset < horizonDays; offset++) {
      final day = today.addDays(offset);
      final when = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (!when.isAfter(now)) continue;
      if (isWithinQuietHours(time, settings.quietHours)) continue;

      final open = openHabitsForRecheck(
        habits: habits,
        logsByHabit: logsByHabit,
        day: day,
      );
      if (open.isEmpty) continue;

      await _notifications.schedule(
        NotificationRequest(
          id: recheckNotificationId(day),
          title: 'Daily recheck',
          body: offset == 0
              ? recheckBody(open)
              : 'Time to review today’s habits.',
          when: when,
          payload: recheckPayload(date: day.toIso()),
          actions: const [
            NotificationActionSpec(id: actionOpen, title: 'Review'),
          ],
          playSound: settings.notificationSound,
        ),
      );
    }
  }

  Future<void> _scheduleMorningRechecks({
    required List<Habit> habits,
    required Map<String, Map<LocalDay, HabitLog>> logsByHabit,
    required AppSettings settings,
    required LocalDay today,
    required DateTime now,
  }) async {
    final morning = settings.morningRecheckTime;
    if (morning == null) return;

    final DayTime time;
    try {
      time = DayTime.parse(morning);
    } on FormatException {
      return;
    }

    for (var offset = 0; offset < horizonDays; offset++) {
      final day = today.addDays(offset);
      final when = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (!when.isAfter(now)) continue;
      if (isWithinQuietHours(time, settings.quietHours)) continue;

      final yesterday = day.addDays(-1);
      final open = openHabitsForRecheck(
        habits: habits,
        logsByHabit: logsByHabit,
        day: yesterday,
      );
      if (open.isEmpty) continue;

      await _notifications.schedule(
        NotificationRequest(
          id: recheckNotificationId(day, morning: true),
          title: 'Morning recheck',
          body: offset == 0
              ? recheckBody(open)
              : 'Yesterday still has open habits.',
          when: when,
          payload: recheckPayload(date: yesterday.toIso(), morning: true),
          actions: const [
            NotificationActionSpec(id: actionOpen, title: 'Open'),
          ],
          playSound: settings.notificationSound,
        ),
      );
    }
  }
}
