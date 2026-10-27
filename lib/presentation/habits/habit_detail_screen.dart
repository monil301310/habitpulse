import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/clock_providers.dart';
import '../../app/providers/habit_providers.dart';
import '../../app/providers/log_providers.dart';
import '../../app/theme/app_colors.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/enums/habit_type.dart';
import '../../domain/enums/log_status.dart';
import '../../domain/enums/schedule_type.dart';
import '../../domain/logic/completion_logic.dart';
import '../../domain/logic/insights_logic.dart';
import '../../domain/models/local_day.dart';
import 'habit_form_screen.dart';
import 'widgets/day_detail_sheet.dart';
import 'widgets/heatmap.dart';

/// The full picture for one habit: big heatmap, streaks, rates and history.
class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({
    super.key,
    required this.habitId,
    this.embedded = false,
    this.onClose,
  });

  final String habitId;

  /// Shown in the tablet/desktop side pane instead of a pushed route.
  final bool embedded;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider).value;
    final allLogs = ref.watch(allLogsProvider).value;
    final today = ref.watch(effectiveTodayProvider);
    final weekStart = ref.watch(weekStartProvider);

    if (habits == null || allLogs == null) {
      return embedded
          ? const Center(child: CircularProgressIndicator())
          : const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Habit? found;
    for (final candidate in habits) {
      if (candidate.id == habitId) {
        found = candidate;
        break;
      }
    }

    if (found == null) {
      const missing = Center(child: Text('This habit no longer exists.'));
      if (embedded) return missing;
      return Scaffold(
        appBar: AppBar(title: const Text('Habit')),
        body: missing,
      );
    }

    final habit = found;

    final logs = <LocalDay, HabitLog>{};
    for (final log in allLogs) {
      if (log.habitId == habit.id) logs[log.date] = log;
    }

    final insights = buildHabitInsights(
      habit: habit,
      logs: logs,
      today: today,
      weekStart: weekStart,
    );
    final accent = AppColors.fromHex(habit.colour);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text(habit.name),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HabitFormScreen(existing: habit),
              ),
            ),
            icon: const Icon(Icons.edit_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (value) => _onMenu(context, ref, habit, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Archive'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (embedded && onClose != null)
            IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.bolt_rounded,
                              color: accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _scheduleLabel(habit),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          _StreakPill(
                            label: insights.currentStreak.label,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    HabitHeatmap(
                      habit: habit,
                      logs: logs,
                      today: today,
                      cellSize: 14,
                      gap: 4,
                      onDayTap: (day) => showDayDetailSheet(
                        context,
                        habit: habit,
                        day: day,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: HeatmapLegend(accent: accent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Current streak',
                    value: insights.currentStreak.label,
                    accent: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Longest streak',
                    value: insights.longestStreak.label,
                    accent: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Completion rate'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _RateTile(
                            label: '7 days',
                            stats: insights.last7,
                            accent: accent,
                          ),
                        ),
                        Expanded(
                          child: _RateTile(
                            label: '30 days',
                            stats: insights.last30,
                            accent: accent,
                          ),
                        ),
                        Expanded(
                          child: _RateTile(
                            label: '90 days',
                            stats: insights.last90,
                            accent: accent,
                          ),
                        ),
                        Expanded(
                          child: _RateTile(
                            label: 'All time',
                            stats: insights.allTime,
                            accent: accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Insights'),
                    const SizedBox(height: 4),
                    _DetailRow(
                      icon: Icons.event_available_rounded,
                      label: 'Best weekday',
                      value: _weekdayName(insights.bestWeekday),
                    ),
                    _DetailRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Total completions',
                      value: '${insights.totalCompletions}',
                    ),
                    if (habit.type == HabitType.count ||
                        habit.type == HabitType.timed) ...[
                      _DetailRow(
                        icon: Icons.summarize_rounded,
                        label: 'Total value',
                        value:
                            '${_formatNumber(insights.totalValue)} '
                            '${habit.unit ?? ''}'.trim(),
                      ),
                      _DetailRow(
                        icon: Icons.analytics_outlined,
                        label: 'Daily average',
                        value:
                            '${_formatNumber(insights.averageValue)} '
                            '${habit.unit ?? ''}'.trim(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Monthly trend'),
                    const SizedBox(height: 12),
                    MonthlyTrendChart(
                      points: insights.monthlyTrend,
                      accent: accent,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final point in insights.monthlyTrend)
                          Expanded(
                            child: Text(
                              _monthInitial(point.monthStart),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel('History'),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No days logged yet. Tap a square above or use the card on '
                  'the Today screen.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              _HistoryList(
                logs: logs,
                habit: habit,
                today: today,
                accent: accent,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    String action,
  ) async {
    if (action == 'archive') {
      await ref
          .read(habitRepositoryProvider)
          .setArchived(habit.id, archived: true);
      if (context.mounted) Navigator.of(context).pop();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text(
          '“${habit.name}” and its history will be removed. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(habitRepositoryProvider).deleteHabit(habit.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.logs,
    required this.habit,
    required this.today,
    required this.accent,
  });

  final Map<LocalDay, HabitLog> logs;
  final Habit habit;
  final LocalDay today;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = logs.keys.toList()..sort((a, b) => b.compareTo(a));
    final visible = days.take(30).toList();

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Builder(
              builder: (context) {
                final day = visible[i];
                final log = logs[day]!;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  leading: Icon(
                    _statusIcon(log.status),
                    color: _statusColor(theme, log.status, accent),
                  ),
                  title: Text(_formatDay(day)),
                  subtitle: log.note == null || log.note!.isEmpty
                      ? Text(_statusLabel(log.status))
                      : Text(
                          log.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: habit.targetValue == null
                      ? null
                      : Text(
                          '${_formatNumber(log.value)}'
                          '${habit.unit == null ? '' : ' ${habit.unit}'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                  onTap: () => showDayDetailSheet(
                    context,
                    habit: habit,
                    day: day,
                  ),
                );
              },
            ),
          ],
          if (days.length > visible.length)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Showing the 30 most recent days.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.label,
    required this.stats,
    required this.accent,
  });

  final String label;
  final CompletionStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '${stats.percent}%',
          style: theme.textTheme.titleMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// A small line chart of monthly completion rates.
class MonthlyTrendChart extends StatelessWidget {
  const MonthlyTrendChart({
    super.key,
    required this.points,
    required this.accent,
  });

  final List<MonthlyPoint> points;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendPainter(
          points: points,
          accent: accent,
          gridColor: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.accent,
    required this.gridColor,
  });

  final List<MonthlyPoint> points;
  final Color accent;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const padding = 6.0;
    final chartHeight = size.height - padding * 2;
    final baselineY = size.height - padding;

    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );

    final dx = points.length == 1
        ? size.width / 2
        : size.width / (points.length - 1);

    final path = Path();
    final dotPaint = Paint()..color = accent;
    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < points.length; i++) {
      final value = points[i].stats.dueDays == 0 ? 0.0 : points[i].rate;
      final offset = Offset(i * dx, baselineY - value * chartHeight);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawCircle(offset, 3, dotPaint);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.accent != accent;
  }
}

String _scheduleLabel(Habit habit) {
  return switch (habit.scheduleType) {
    ScheduleType.daily => 'Every day',
    ScheduleType.weekdays => 'Selected weekdays',
    ScheduleType.timesPerWeek => '${habit.timesPerWeek ?? 1}× per week',
  };
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

String _monthInitial(LocalDay monthStart) {
  const names = [
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D',
  ];
  return names[(monthStart.month - 1).clamp(0, 11)];
}

String _formatDay(LocalDay day) {
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

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

String _statusLabel(LogStatus status) {
  return switch (status) {
    LogStatus.done => 'Done',
    LogStatus.partial => 'Partial',
    LogStatus.missed => 'Missed',
    LogStatus.skipped => 'Skipped',
    LogStatus.slipped => 'Slipped',
  };
}

IconData _statusIcon(LogStatus status) {
  return switch (status) {
    LogStatus.done => Icons.check_circle_rounded,
    LogStatus.partial => Icons.timelapse_rounded,
    LogStatus.missed => Icons.cancel_outlined,
    LogStatus.skipped => Icons.skip_next_rounded,
    LogStatus.slipped => Icons.report_gmailerrorred_rounded,
  };
}

Color _statusColor(ThemeData theme, LogStatus status, Color accent) {
  return switch (status) {
    LogStatus.done => accent,
    LogStatus.partial => AppColors.warning,
    LogStatus.missed || LogStatus.slipped => theme.colorScheme.error,
    LogStatus.skipped => theme.colorScheme.onSurfaceVariant,
  };
}
