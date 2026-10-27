import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/log_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/habit_log.dart';
import '../../../domain/enums/habit_type.dart';
import '../../../domain/enums/log_status.dart';
import '../../../domain/models/local_day.dart';

/// Shows the details of one day and lets the user edit it.
Future<void> showDayDetailSheet(
  BuildContext context, {
  required Habit habit,
  required LocalDay day,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DayDetailSheet(habit: habit, day: day),
  );
}

class _DayDetailSheet extends ConsumerStatefulWidget {
  const _DayDetailSheet({required this.habit, required this.day});

  final Habit habit;
  final LocalDay day;

  @override
  ConsumerState<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends ConsumerState<_DayDetailSheet> {
  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _months = [
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

  late final TextEditingController _valueController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final logs = ref.read(allLogsProvider).value ?? const <HabitLog>[];
    final log = _findLog(logs);
    _valueController = TextEditingController(
      text: log == null ? '' : _formatNumber(log.value),
    );
    _noteController = TextEditingController(text: log?.note ?? '');
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  HabitLog? _findLog(List<HabitLog> logs) {
    for (final log in logs) {
      if (log.habitId == widget.habit.id && log.date == widget.day) {
        return log;
      }
    }
    return null;
  }

  bool get _hasTarget =>
      widget.habit.type == HabitType.count ||
      widget.habit.type == HabitType.timed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logs = ref.watch(allLogsProvider).value ?? const <HabitLog>[];
    final log = _findLog(logs);
    final accent = AppColors.fromHex(widget.habit.colour);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatDay(), style: theme.textTheme.titleLarge),
            Text(
              widget.habit.name,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            _statusPill(log: log, accent: accent),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () =>
                      _run(() => ref.read(logServiceProvider).markDone(
                        widget.habit,
                        widget.day,
                      )),
                  child: const Text('Done'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      _run(() => ref.read(logServiceProvider).skip(
                        widget.habit,
                        widget.day,
                      )),
                  child: const Text('Skip'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      _run(() => ref.read(logServiceProvider).markMissed(
                        widget.habit,
                        widget.day,
                      )),
                  child: const Text('Missed'),
                ),
                if (widget.habit.type == HabitType.negative)
                  OutlinedButton(
                    onPressed: () =>
                        _run(() => ref.read(logServiceProvider).markSlipped(
                          widget.habit,
                          widget.day,
                        )),
                    child: const Text('Slipped'),
                  ),
                if (log != null)
                  TextButton(
                    onPressed: () =>
                        _run(() => ref.read(logServiceProvider).clear(
                          widget.habit,
                          widget.day,
                        )),
                    child: Text(
                      'Clear',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
            if (_hasTarget) ...[
              const SizedBox(height: 20),
              Text('Value', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _valueController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: widget.habit.type == HabitType.timed
                            ? 'Minutes'
                            : (widget.habit.unit ?? 'Amount'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _saveValue,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text('Note', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Why was today missed?',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (log == null)
                  Expanded(
                    child: Text(
                      'Mark the day first to add a note.',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                else
                  const Spacer(),
                TextButton(
                  onPressed: log == null ? null : _saveNote,
                  child: const Text('Save note'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill({required HabitLog? log, required Color accent}) {
    final theme = Theme.of(context);
    final status = log?.status;

    final (String label, Color colour, IconData icon) = switch (status) {
      LogStatus.done => ('Done', AppColors.green, Icons.check_circle_rounded),
      LogStatus.partial => (
        'Partial',
        AppColors.warning,
        Icons.timelapse_rounded,
      ),
      LogStatus.skipped => (
        'Skipped',
        theme.colorScheme.onSurfaceVariant,
        Icons.skip_next_rounded,
      ),
      LogStatus.missed => (
        'Missed',
        theme.colorScheme.error,
        Icons.cancel_outlined,
      ),
      LogStatus.slipped => (
        'Slipped',
        theme.colorScheme.error,
        Icons.report_gmailerrorred_rounded,
      ),
      null => (
        'Not logged yet',
        theme.colorScheme.onSurfaceVariant,
        Icons.radio_button_unchecked_rounded,
      ),
    };

    final detail = log != null && _hasTarget
        ? ' · ${_formatNumber(log.value)} / '
              '${_formatNumber(widget.habit.targetValue ?? 0)}'
              '${widget.habit.unit == null ? '' : ' ${widget.habit.unit}'}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colour),
          const SizedBox(width: 7),
          Text(
            '$label$detail',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colour,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveValue() async {
    final value = double.tryParse(_valueController.text.trim());
    if (value == null) {
      _showMessage('Enter a number.');
      return;
    }
    await _run(
      () => ref.read(logServiceProvider).setValue(
        widget.habit,
        widget.day,
        value,
      ),
    );
  }

  Future<void> _saveNote() async {
    await _run(
      () => ref.read(logServiceProvider).setNote(
        widget.habit,
        widget.day,
        _noteController.text,
      ),
    );
    if (mounted) _showMessage('Note saved.');
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      if (mounted) _showMessage('Could not update: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDay() {
    final day = widget.day;
    return '${_weekdays[day.weekday - 1]}, ${day.day} '
        '${_months[day.month - 1]} ${day.year}';
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}
