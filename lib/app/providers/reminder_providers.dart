import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_reminder_repository.dart';
import '../../domain/entities/habit_reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import 'database_provider.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return DriftReminderRepository(ref.watch(appDatabaseProvider));
});

final remindersProvider = StreamProvider<List<HabitReminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchAll();
});

/// Reminders grouped by habit id.
final remindersByHabitProvider = Provider<Map<String, List<HabitReminder>>>((
  ref,
) {
  final reminders = ref.watch(remindersProvider).value ?? const [];
  final byHabit = <String, List<HabitReminder>>{};
  for (final reminder in reminders) {
    (byHabit[reminder.habitId] ??= <HabitReminder>[]).add(reminder);
  }
  return byHabit;
});
