import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers/clock_providers.dart';
import '../app/providers/habit_providers.dart';
import '../app/providers/log_providers.dart';
import '../app/providers/notification_providers.dart';
import '../app/providers/reminder_providers.dart';
import '../app/providers/settings_providers.dart';
import '../domain/entities/habit_log.dart';
import '../domain/models/local_day.dart';

/// Rebuilds the local notification schedule whenever habits, reminders, logs or
/// settings change. Sits near the app root and does not affect layout.
class NotificationSync extends ConsumerStatefulWidget {
  const NotificationSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends ConsumerState<NotificationSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(habitsProvider, (_, _) => _schedule());
    ref.listen(remindersProvider, (_, _) => _schedule());
    ref.listen(allLogsProvider, (_, _) => _schedule());
    ref.listen(appSettingsProvider, (_, _) => _schedule());
    return widget.child;
  }

  void _schedule() {
    ref.read(notificationCoordinatorProvider).schedule(_rebuild);
  }

  Future<void> _rebuild() async {
    final habits = ref.read(habitsProvider).value;
    final logs = ref.read(allLogsProvider).value;
    final settings = ref.read(appSettingsProvider).value;
    if (habits == null || logs == null || settings == null) return;

    final logsByHabit = <String, Map<LocalDay, HabitLog>>{};
    for (final log in logs) {
      (logsByHabit[log.habitId] ??= <LocalDay, HabitLog>{})[log.date] = log;
    }

    await ref
        .read(reminderSchedulerProvider)
        .rebuild(
          habits: habits,
          remindersByHabit: ref.read(remindersByHabitProvider),
          logsByHabit: logsByHabit,
          settings: settings,
          today: ref.read(effectiveTodayProvider),
          now: DateTime.now(),
          weekStart: ref.read(weekStartProvider),
        );
  }
}
