import 'dart:convert';

import '../../domain/entities/habit.dart';
import '../../domain/enums/habit_type.dart';
import 'notification_service.dart';

const String actionDone = 'done';
const String actionSkip = 'skip';
const String actionSlip = 'slip';
const String actionIncrement = 'inc';
const String actionOpen = 'open';
const String actionSnooze10 = 'snooze10';
const String actionSnooze60 = 'snooze60';

/// The action buttons a reminder should show for a habit type.
List<NotificationActionSpec> reminderActionsFor(Habit habit) {
  const snooze10 = NotificationActionSpec(id: actionSnooze10, title: '10m');
  const snooze60 = NotificationActionSpec(id: actionSnooze60, title: '1h');

  return switch (habit.type) {
    HabitType.yesNo => const [
      NotificationActionSpec(id: actionDone, title: 'Done'),
      NotificationActionSpec(id: actionSkip, title: 'Skip'),
      snooze10,
      snooze60,
    ],
    HabitType.negative => const [
      NotificationActionSpec(id: actionDone, title: 'Avoided'),
      NotificationActionSpec(id: actionSlip, title: 'Slipped'),
      snooze10,
      snooze60,
    ],
    HabitType.count => const [
      NotificationActionSpec(id: actionIncrement, title: '+1'),
      NotificationActionSpec(id: actionDone, title: 'Done'),
      snooze10,
      snooze60,
    ],
    HabitType.timed => const [
      NotificationActionSpec(id: actionDone, title: 'Done'),
      NotificationActionSpec(id: actionOpen, title: 'Open'),
      snooze10,
      snooze60,
    ],
  };
}

String reminderPayload({required String habitId, required String date}) {
  return jsonEncode({'type': 'reminder', 'habitId': habitId, 'date': date});
}

String recheckPayload({required String date, bool morning = false}) {
  return jsonEncode({
    'type': 'recheck',
    'date': date,
    if (morning) 'morning': true,
  });
}
