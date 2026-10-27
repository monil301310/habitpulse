import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/clock_providers.dart';
import '../../app/providers/habit_providers.dart';
import '../../app/providers/log_providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/habit_icons.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/logic/completion_logic.dart';
import '../../domain/logic/insights_logic.dart';
import '../../domain/logic/streak_logic.dart';
import '../../domain/models/local_day.dart';

/// Account-wide insights: weekly progress, best/worst habits and per-habit rates.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: const Text('Insights'),
      ),
      body: SafeArea(top: false, child: _buildBody(context, ref)),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider).value;
    final logs = ref.watch(allLogsProvider).value;
    final today = ref.watch(effectiveTodayProvider);
    final weekStart = ref.watch(weekStartProvider);

    if (habits == null || logs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    if (habits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insights_rounded,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No insights yet',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Add a habit and log a few days to see completion rates, '
                'your best weekday and a monthly trend.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final logsByHabit = <String, Map<LocalDay, HabitLog>>{};
    for (final log in logs) {
      (logsByHabit[log.habitId] ??= <LocalDay, HabitLog>{})[log.date] = log;
    }

    final insights = buildOverallInsights(
      habits: habits,
      logsByHabit: logsByHabit,
      today: today,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _BigCard(
          title: 'This week',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${insights.thisWeek.percent}%',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${insights.thisWeek.completedDays} of '
                '${insights.thisWeek.dueDays} due days complete',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: insights.thisWeek.rate,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SmallCard(
                icon: Icons.calendar_month_rounded,
                label: 'Last 30 days',
                value: '${insights.last30.percent}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallCard(
                icon: Icons.event_available_rounded,
                label: 'Best weekday',
                value: _weekdayName(insights.bestWeekday),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (insights.bestHabit != null) ...[
          _HabitRankCard(
            title: 'Top habit',
            habit: insights.bestHabit!,
            rate: insights.bestRate,
            icon: Icons.workspace_premium_rounded,
            positive: true,
          ),
          const SizedBox(height: 12),
        ],
        if (insights.worstHabit != null &&
            insights.worstHabit!.id != insights.bestHabit?.id) ...[
          _HabitRankCard(
            title: 'Needs attention',
            habit: insights.worstHabit!,
            rate: insights.worstRate,
            icon: Icons.trending_down_rounded,
            positive: false,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        Text(
          'PER HABIT · LAST 30 DAYS',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < habits.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _HabitRateRow(
                  habit: habits[i],
                  logs: logsByHabit[habits[i].id] ?? const {},
                  today: today,
                  weekStart: weekStart,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BigCard extends StatelessWidget {
  const _BigCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  const _SmallCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _HabitRankCard extends StatelessWidget {
  const _HabitRankCard({
    required this.title,
    required this.habit,
    required this.rate,
    required this.icon,
    required this.positive,
  });

  final String title;
  final Habit habit;
  final double rate;
  final IconData icon;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.fromHex(habit.colour);
    final colour = positive ? accent : theme.colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colour),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    habit.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '${(rate * 100).round()}%',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colour,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitRateRow extends StatelessWidget {
  const _HabitRateRow({
    required this.habit,
    required this.logs,
    required this.today,
    required this.weekStart,
  });

  final Habit habit;
  final Map<LocalDay, HabitLog> logs;
  final LocalDay today;
  final int weekStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.fromHex(habit.colour);
    final stats = completionStatsForLastDays(
      habit: habit,
      logs: logs,
      today: today,
      days: 30,
    );
    final streak = currentStreak(
      habit: habit,
      logs: logs,
      today: today,
      weekStart: weekStart,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(HabitIcons.resolve(habit.icon), color: accent, size: 20),
      ),
      title: Text(
        habit.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('${streak.label} streak'),
      trailing: Text(
        '${stats.percent}%',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

String _weekdayName(int? weekday) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  if (weekday == null) return '—';
  return names[(weekday - 1).clamp(0, 6)];
}
