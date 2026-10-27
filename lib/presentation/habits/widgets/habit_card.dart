import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/habit_providers.dart';
import '../../../app/providers/log_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/habit_icons.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/habit_log.dart';
import '../../../domain/enums/habit_type.dart';
import '../../../domain/enums/log_status.dart';
import '../../../domain/enums/schedule_type.dart';
import '../../../domain/logic/streak_logic.dart';
import '../../../domain/models/local_day.dart';
import 'day_detail_sheet.dart';
import 'heatmap.dart';

enum _CardAction { edit, skip, missed, slipped, archive, delete }

/// A home-screen card: identity, streak, today's state and a one-tap log.
class HabitCard extends ConsumerWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.logs,
    required this.today,
    required this.weekStart,
    required this.onEdit,
    required this.onOpen,
    this.selected = false,
  });

  final Habit habit;
  final Map<LocalDay, HabitLog> logs;
  final LocalDay today;
  final int weekStart;
  final VoidCallback onEdit;
  final VoidCallback onOpen;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final log = logs[today];
    final accent = AppColors.fromHex(habit.colour);
    final streak = currentStreak(
      habit: habit,
      logs: logs,
      today: today,
      weekStart: weekStart,
    );

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: selected
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onOpen,
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(HabitIcons.resolve(habit.icon), color: accent),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                _StreakPill(streak: streak, accent: accent),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(_scheduleSummary()),
            ),
            trailing: PopupMenuButton<_CardAction>(
              tooltip: 'More actions',
              onSelected: (action) => _onAction(context, ref, action),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _CardAction.edit,
                  child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit'),
                ),
                const PopupMenuItem(
                  value: _CardAction.skip,
                  child: _MenuRow(
                    icon: Icons.skip_next_rounded,
                    label: 'Skip today',
                  ),
                ),
                const PopupMenuItem(
                  value: _CardAction.missed,
                  child: _MenuRow(
                    icon: Icons.close_rounded,
                    label: 'Mark missed',
                  ),
                ),
                if (habit.type == HabitType.negative)
                  const PopupMenuItem(
                    value: _CardAction.slipped,
                    child: _MenuRow(
                      icon: Icons.report_gmailerrorred_rounded,
                      label: 'Slipped',
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: _CardAction.archive,
                  child: _MenuRow(
                    icon: Icons.archive_outlined,
                    label: 'Archive',
                  ),
                ),
                PopupMenuItem(
                  value: _CardAction.delete,
                  child: _MenuRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 16, 2),
            child: HabitHeatmap(
              habit: habit,
              logs: logs,
              today: today,
              cellSize: 11,
              gap: 3,
              maxWeeks: 30,
              onDayTap: (day) =>
                  showDayDetailSheet(context, habit: habit, day: day),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Local · ${_updatedLabel(context)}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
            child: Row(
              children: [
                Expanded(child: _statusLine(context, ref, log, accent)),
                const SizedBox(width: 8),
                _actions(context, ref, log),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(
    BuildContext context,
    WidgetRef ref,
    HabitLog? log,
    Color accent,
  ) {
    final theme = Theme.of(context);
    final (icon, text, color) = _statusFor(context, log);

    Widget content = Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    if (habit.type == HabitType.count || habit.type == HabitType.timed) {
      content = InkWell(
        onTap: () => _openValueDialog(context, ref),
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    return content;
  }

  (IconData, String, Color) _statusFor(BuildContext context, HabitLog? log) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final status = log?.status;

    switch (status) {
      case LogStatus.done:
        return (
          Icons.check_circle_rounded,
          _hasTarget ? _valueLabel(log!) : 'Done today',
          AppColors.green,
        );
      case LogStatus.partial:
        return (
          Icons.timelapse_rounded,
          _valueLabel(log!),
          AppColors.warning,
        );
      case LogStatus.skipped:
        return (Icons.skip_next_rounded, 'Skipped', muted);
      case LogStatus.missed:
        return (
          Icons.cancel_outlined,
          'Missed',
          theme.colorScheme.error,
        );
      case LogStatus.slipped:
        return (
          Icons.report_gmailerrorred_rounded,
          'Slipped',
          theme.colorScheme.error,
        );
      case null:
        return (
          Icons.radio_button_unchecked_rounded,
          'Not logged yet',
          muted,
        );
    }
  }

  bool get _hasTarget => habit.targetValue != null;

  String _valueLabel(HabitLog log) {
    final target = habit.targetValue ?? 0;
    final unit = habit.unit == null ? '' : ' ${habit.unit}';
    return '${_formatNumber(log.value)} / ${_formatNumber(target)}$unit';
  }

  Widget _actions(BuildContext context, WidgetRef ref, HabitLog? log) {
    final done = log?.status == LogStatus.done;

    switch (habit.type) {
      case HabitType.yesNo:
        return done
            ? OutlinedButton.icon(
                onPressed: () => _run(
                  context,
                  () => ref.read(logServiceProvider).clear(habit, today),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Done'),
              )
            : FilledButton.icon(
                onPressed: () => _run(
                  context,
                  () => ref.read(logServiceProvider).markDone(habit, today),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Done'),
              );

      case HabitType.negative:
        if (done) {
          return OutlinedButton.icon(
            onPressed: () => _run(
              context,
              () => ref.read(logServiceProvider).clear(habit, today),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Avoided'),
          );
        }
        if (log?.status == LogStatus.slipped) {
          return OutlinedButton.icon(
            onPressed: () => _run(
              context,
              () => ref.read(logServiceProvider).clear(habit, today),
            ),
            icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18),
            label: const Text('Slipped'),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _run(
                context,
                () => ref.read(logServiceProvider).markSlipped(habit, today),
              ),
              child: const Text('Slipped'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () => _run(
                context,
                () =>
                    ref.read(logServiceProvider).confirmAvoided(habit, today),
              ),
              child: const Text('Avoided'),
            ),
          ],
        );

      case HabitType.count:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              tooltip: 'Add one',
              onPressed: () => _run(
                context,
                () => ref.read(logServiceProvider).addValue(habit, today, 1),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: () => _run(
                context,
                () => ref.read(logServiceProvider).markDone(habit, today),
              ),
              child: const Text('Done'),
            ),
          ],
        );

      case HabitType.timed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _openValueDialog(context, ref),
              child: const Text('Log'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () => _run(
                context,
                () => ref.read(logServiceProvider).markDone(habit, today),
              ),
              child: const Text('Done'),
            ),
          ],
        );
    }
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _CardAction action,
  ) async {
    switch (action) {
      case _CardAction.edit:
        onEdit();
      case _CardAction.skip:
        await _run(
          context,
          () => ref.read(logServiceProvider).skip(habit, today),
        );
      case _CardAction.missed:
        await _run(
          context,
          () => ref.read(logServiceProvider).markMissed(habit, today),
        );
      case _CardAction.slipped:
        await _run(
          context,
          () => ref.read(logServiceProvider).markSlipped(habit, today),
        );
      case _CardAction.archive:
        await _run(
          context,
          () => ref
              .read(habitRepositoryProvider)
              .setArchived(habit.id, archived: true),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${habit.name} archived')),
          );
        }
      case _CardAction.delete:
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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

    if (confirmed == true && context.mounted) {
      await _run(
        context,
        () => ref.read(habitRepositoryProvider).deleteHabit(habit.id),
      );
    }
  }

  Future<void> _openValueDialog(BuildContext context, WidgetRef ref) async {
    final isTimed = habit.type == HabitType.timed;
    final controller = TextEditingController(
      text: _formatNumber(logs[today]?.value ?? 0),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isTimed ? 'Log minutes' : 'Set value'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: isTimed ? 'Minutes' : (habit.unit ?? 'Value'),
          ),
          onSubmitted: (raw) {
            final parsed = double.tryParse(raw.trim());
            if (parsed != null) Navigator.of(dialogContext).pop(parsed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (value != null && context.mounted) {
      await _run(
        context,
        () => ref.read(logServiceProvider).setValue(habit, today, value),
      );
    }
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: $error')),
      );
    }
  }

  String _scheduleSummary() {
    final target = habit.targetValue;
    final targetPart = target == null
        ? ''
        : ' · ${_formatNumber(target)} ${habit.unit ?? ''}'.trimRight();

    final schedule = switch (habit.scheduleType) {
      ScheduleType.daily => 'Every day',
      ScheduleType.weekdays =>
        (habit.scheduleDays.toList()..sort())
            .map(_shortWeekday)
            .join(', '),
      ScheduleType.timesPerWeek => '${habit.timesPerWeek ?? 1}× per week',
    };

    return '$schedule$targetPart';
  }

  String _shortWeekday(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1).clamp(0, 6)];
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  /// Until cloud sync lands in Phase 5, the footer reports the last local write.
  String _updatedLabel(BuildContext context) {
    final log = logs[today];
    var stamp = habit.updatedAt;
    if (log != null && log.updatedAt.isAfter(stamp)) {
      stamp = log.updatedAt;
    }
    return TimeOfDay.fromDateTime(stamp.toLocal()).format(context);
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak, required this.accent});

  final StreakResult streak;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        streak.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}
