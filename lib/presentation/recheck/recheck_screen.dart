import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/habit_providers.dart';
import '../../app/providers/log_providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/habit_icons.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/enums/habit_type.dart';
import '../../domain/enums/log_status.dart';
import '../../domain/logic/reminder_logic.dart';
import '../../domain/logic/schedule_logic.dart';
import '../../domain/models/local_day.dart';

/// Quick checklist opened from the daily (or morning) recheck notification.
class RecheckScreen extends ConsumerWidget {
  const RecheckScreen({super.key, required this.day, this.morning = false});

  final LocalDay day;
  final bool morning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider).value;
    final logs = ref.watch(allLogsProvider).value;
    final theme = Theme.of(context);

    if (habits == null || logs == null) {
      return Scaffold(
        appBar: AppBar(title: Text(morning ? 'Morning recheck' : 'Recheck')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final logsByHabit = <String, Map<LocalDay, HabitLog>>{};
    for (final log in logs) {
      (logsByHabit[log.habitId] ??= <LocalDay, HabitLog>{})[log.date] = log;
    }

    final dueHabits = [
      for (final habit in habits)
        if (isHabitDueOn(habit, day)) habit,
    ];
    final open = openHabitsForRecheck(
      habits: habits,
      logsByHabit: logsByHabit,
      day: day,
    );

    return Scaffold(
      appBar: AppBar(title: Text(morning ? 'Morning recheck' : 'Recheck')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(_formatDay(day), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              open.isEmpty
                  ? 'Everything is marked. Nice work.'
                  : '${open.length} of ${dueHabits.length} still open',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (open.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 48,
                        color: AppColors.green,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'All caught up',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Every habit due on this day is marked.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final habit in open)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RecheckCard(
                    habit: habit,
                    day: day,
                    log: logsByHabit[habit.id]?[day],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String _formatDay(LocalDay day) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[day.weekday - 1]}, ${day.day} '
        '${months[day.month - 1]} ${day.year}';
  }
}

class _RecheckCard extends ConsumerWidget {
  const _RecheckCard({
    required this.habit,
    required this.day,
    required this.log,
  });

  final Habit habit;
  final LocalDay day;
  final HabitLog? log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = AppColors.fromHex(habit.colour);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    HabitIcons.resolve(habit.icon),
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(habit.name, style: theme.textTheme.titleMedium),
                ),
                if (log?.status == LogStatus.partial)
                  Text(
                    'partial',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () =>
                      ref.read(logServiceProvider).markDone(habit, day),
                  child: const Text('Done'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(logServiceProvider).skip(habit, day),
                  child: const Text('Skip'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(logServiceProvider).markMissed(habit, day),
                  child: const Text('Missed'),
                ),
                if (habit.type == HabitType.negative)
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(logServiceProvider).markSlipped(habit, day),
                    child: const Text('Slipped'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
