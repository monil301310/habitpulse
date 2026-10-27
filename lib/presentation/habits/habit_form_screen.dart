import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers/clock_providers.dart';
import '../../app/providers/habit_providers.dart';
import '../../app/providers/reminder_providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/habit_icons.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_reminder.dart';
import '../../domain/enums/habit_type.dart';
import '../../domain/enums/schedule_type.dart';
import '../../domain/models/local_day.dart';

/// Create or edit a habit.
class HabitFormScreen extends ConsumerStatefulWidget {
  const HabitFormScreen({super.key, this.existing});

  /// Null when creating a new habit.
  final Habit? existing;

  @override
  ConsumerState<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends ConsumerState<HabitFormScreen> {
  static const List<String> _weekdayLabels = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];
  static const List<String> _weekdayNames = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _monthNames = <String>[
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

  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _unitController;

  late String _icon;
  late String _colour;
  late HabitType _type;
  late ScheduleType _scheduleType;
  late Set<int> _days;
  late int _timesPerWeek;
  late LocalDay _startDate;
  late List<_ReminderDraft> _reminders;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _nameController = TextEditingController(text: existing?.name ?? '');

    final target = existing?.targetValue;
    _targetController = TextEditingController(
      text: target == null ? '' : _formatNumber(target),
    );
    _unitController = TextEditingController(text: existing?.unit ?? '');

    _icon = existing?.icon ?? 'bolt';
    _colour = existing?.colour ?? AppColors.toHex(AppColors.green);
    _type = existing?.type ?? HabitType.yesNo;
    _scheduleType = existing?.scheduleType ?? ScheduleType.daily;

    final existingDays = existing?.scheduleDays ?? const <int>{};
    _days = existingDays.isEmpty
        ? <int>{1, 2, 3, 4, 5}
        : {...existingDays};
    _timesPerWeek = existing?.timesPerWeek ?? 3;
    _startDate = existing?.startDate ?? ref.read(effectiveTodayProvider);

    if (existing != null) {
      final allReminders =
          ref.read(remindersProvider).value ?? const <HabitReminder>[];
      _reminders = [
        for (final reminder in allReminders)
          if (reminder.habitId == existing.id)
            _ReminderDraft(
              id: reminder.id,
              time: _timeFromStorage(reminder.timeOfDay),
              days: {...reminder.daysOfWeek},
            ),
      ];
    } else {
      _reminders = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Color get _accent => AppColors.fromHex(_colour);

  bool get _isEditing => widget.existing != null;

  bool get _needsTarget =>
      _type == HabitType.count || _type == HabitType.timed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit habit' : 'New habit')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _FormSection(
              title: 'Name',
              child: TextField(
                controller: _nameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'e.g. Read 20 pages',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _FormSection(
              title: 'Type',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in HabitType.values)
                        ChoiceChip(
                          label: Text(type.label),
                          selected: _type == type,
                          onSelected: (_) => _onTypeChanged(type),
                        ),
                    ],
                  ),
                  if (_type == HabitType.negative) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Stays blank until you confirm it each evening. '
                      'Unconfirmed days count as missed once the day closes.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (_needsTarget) ...[
              const SizedBox(height: 16),
              _FormSection(
                title: 'Daily target',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _targetController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: InputDecoration(
                          labelText: _type == HabitType.timed
                              ? 'Minutes per day'
                              : 'Amount per day',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _unitController,
                        decoration: const InputDecoration(labelText: 'Unit'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _FormSection(
              title: 'Schedule',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in ScheduleType.values)
                        ChoiceChip(
                          label: Text(type.label),
                          selected: _scheduleType == type,
                          onSelected: (_) => _onScheduleChanged(type),
                        ),
                    ],
                  ),
                  if (_scheduleType == ScheduleType.weekdays) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < 7; i++)
                          FilterChip(
                            label: Text(_weekdayLabels[i]),
                            selected: _days.contains(i + 1),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _days.add(i + 1);
                                } else {
                                  _days.remove(i + 1);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                  if (_scheduleType == ScheduleType.timesPerWeek) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Completions needed',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Fewer',
                          onPressed: _timesPerWeek > 1
                              ? () => setState(() => _timesPerWeek--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Text(
                          '$_timesPerWeek',
                          style: theme.textTheme.titleLarge,
                        ),
                        IconButton(
                          tooltip: 'More',
                          onPressed: _timesPerWeek < 7
                              ? () => setState(() => _timesPerWeek++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _FormSection(
              title: 'Start date',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(_formatDay(_startDate)),
                subtitle: const Text('Days before this are never due'),
                trailing: TextButton(
                  onPressed: _pickStartDate,
                  child: const Text('Change'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _FormSection(
              title: 'Icon',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in HabitIcons.all.entries)
                    _ChoiceSquare(
                      selected: _icon == entry.key,
                      accent: _accent,
                      onTap: () => setState(() => _icon = entry.key),
                      child: Icon(
                        entry.value,
                        size: 22,
                        color: _icon == entry.key
                            ? _accent
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _FormSection(
              title: 'Colour',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final colour in AppColors.accents)
                    _ColourDot(
                      colour: colour,
                      selected: _colour == AppColors.toHex(colour),
                      onTap: () => setState(
                        () => _colour = AppColors.toHex(colour),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _FormSection(
              title: 'Reminders',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_reminders.isEmpty)
                    Text(
                      'No reminders yet. Each one fires only on days the habit '
                      'is due and not already done.',
                      style: theme.textTheme.bodySmall,
                    ),
                  for (var i = 0; i < _reminders.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alarm_rounded),
                      title: Text(_reminders[i].time.format(context)),
                      subtitle: Text(_reminderDaysLabel(_reminders[i].days)),
                      trailing: IconButton(
                        tooltip: 'Remove reminder',
                        onPressed: () =>
                            setState(() => _reminders.removeAt(i)),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      onTap: () => _editReminder(i),
                    ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _editReminder(null),
                      icon: const Icon(Icons.add_alarm_rounded),
                      label: const Text('Add reminder'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Save changes' : 'Create habit'),
          ),
        ),
      ),
    );
  }

  void _onTypeChanged(HabitType type) {
    setState(() {
      _type = type;
      switch (type) {
        case HabitType.yesNo:
        case HabitType.negative:
          _targetController.clear();
          _unitController.clear();
        case HabitType.count:
          if (_targetController.text.isEmpty) _targetController.text = '8';
          if (_unitController.text.isEmpty) _unitController.text = 'times';
        case HabitType.timed:
          if (_targetController.text.isEmpty) _targetController.text = '30';
          if (_unitController.text.isEmpty) _unitController.text = 'min';
      }
    });
  }

  void _onScheduleChanged(ScheduleType type) {
    setState(() {
      _scheduleType = type;
      if (type == ScheduleType.weekdays && _days.isEmpty) {
        _days = {1, 2, 3, 4, 5};
      }
    });
  }

  Future<void> _editReminder(int? index) async {
    final initial = index == null
        ? const _ReminderDraft(
            time: TimeOfDay(hour: 9, minute: 0),
            days: <int>{},
          )
        : _reminders[index];

    final result = await showDialog<_ReminderDraft>(
      context: context,
      builder: (_) => _ReminderDialog(initial: initial),
    );
    if (result == null) return;

    setState(() {
      if (index == null) {
        _reminders.add(result);
      } else {
        _reminders[index] = result;
      }
    });
  }

  String _reminderDaysLabel(Set<int> days) {
    if (days.isEmpty) return 'Habit schedule days';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = days.toList()..sort();
    return sorted.map((day) => names[day - 1]).join(', ');
  }

  static TimeOfDay _timeFromStorage(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  static String _timeToStorage(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = LocalDay.fromDateTime(picked));
    }
  }

  String? _validationMessage() {
    if (_nameController.text.trim().isEmpty) {
      return 'Give your habit a name.';
    }
    if (_needsTarget) {
      final target = double.tryParse(_targetController.text.trim());
      if (target == null || target <= 0) {
        return 'Enter a daily target greater than zero.';
      }
    }
    if (_scheduleType == ScheduleType.weekdays && _days.isEmpty) {
      return 'Choose at least one weekday.';
    }
    return null;
  }

  Future<void> _save() async {
    final message = _validationMessage();
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    setState(() => _saving = true);

    final now = DateTime.now().toUtc();
    final existing = widget.existing;
    final targetText = _targetController.text.trim();
    final unitText = _unitController.text.trim();

    final habit = Habit(
      id: existing?.id ?? const Uuid().v4(),
      userId: existing?.userId ?? 'local',
      name: _nameController.text.trim(),
      icon: _icon,
      colour: _colour,
      type: _type,
      targetValue: _needsTarget ? double.parse(targetText) : null,
      unit: _needsTarget && unitText.isNotEmpty ? unitText : null,
      scheduleType: _scheduleType,
      scheduleDays: _scheduleType == ScheduleType.weekdays
          ? _days
          : const <int>{},
      timesPerWeek: _scheduleType == ScheduleType.timesPerWeek
          ? _timesPerWeek
          : null,
      startDate: _startDate,
      archivedAt: existing?.archivedAt,
      sortOrder: existing?.sortOrder ?? 0,
      source: existing?.source ?? 'manual',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await ref.read(habitRepositoryProvider).saveHabit(habit);
      await ref
          .read(reminderRepositoryProvider)
          .replaceForHabit(habit.id, [
            for (final draft in _reminders)
              HabitReminder(
                id: draft.id ?? const Uuid().v4(),
                habitId: habit.id,
                timeOfDay: _timeToStorage(draft.time),
                daysOfWeek: draft.days,
                enabled: true,
                updatedAt: now,
              ),
          ]);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save habit: $error')),
      );
    }
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  String _formatDay(LocalDay day) {
    return '${_weekdayNames[day.weekday - 1]}, ${day.day} '
        '${_monthNames[day.month - 1]} ${day.year}';
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChoiceSquare extends StatelessWidget {
  const _ChoiceSquare({
    required this.selected,
    required this.accent,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ColourDot extends StatelessWidget {
  const _ColourDot({
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  final Color colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colour,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colour.withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 20, color: Colors.black)
            : null,
      ),
    );
  }
}

class _ReminderDraft {
  const _ReminderDraft({required this.time, required this.days, this.id});

  final String? id;
  final TimeOfDay time;
  final Set<int> days;
}

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({required this.initial});

  final _ReminderDraft initial;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  static const List<String> _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  late TimeOfDay _time;
  late Set<int> _days;

  @override
  void initState() {
    super.initState();
    _time = widget.initial.time;
    _days = {...widget.initial.days};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.alarm_rounded),
              label: Text(_time.format(context)),
            ),
            const SizedBox(height: 16),
            Text('Days', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(_labels[i]),
                    selected: _days.contains(i + 1),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _days.add(i + 1);
                        } else {
                          _days.remove(i + 1);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'No days selected means it follows the habit’s schedule.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _ReminderDraft(
              id: widget.initial.id,
              time: _time,
              days: {..._days},
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }
}
