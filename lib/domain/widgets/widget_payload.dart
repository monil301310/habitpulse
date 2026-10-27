import '../entities/habit.dart';
import '../entities/habit_log.dart';
import '../enums/log_status.dart';
import '../logic/schedule_logic.dart';
import '../models/local_day.dart';

/// One row in the today-checklist widget.
class WidgetChecklistRow {
  const WidgetChecklistRow({
    required this.id,
    required this.name,
    required this.done,
  });

  final String id;
  final String name;
  final bool done;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'done': done,
  };
}

/// The data pushed to the Android checklist widget.
class WidgetChecklistPayload {
  const WidgetChecklistPayload({
    required this.date,
    required this.done,
    required this.total,
    required this.more,
    required this.rows,
  });

  final String date;
  final int done;
  final int total;

  /// How many due habits did not fit in [rows].
  final int more;
  final List<WidgetChecklistRow> rows;

  Map<String, Object?> toJson() => {
    'date': date,
    'done': done,
    'total': total,
    'more': more,
    'habits': rows.map((row) => row.toJson()).toList(growable: false),
  };
}

/// Builds the checklist widget payload for [today].
///
/// Only habits due today are included; [maxRows] keeps the widget compact.
WidgetChecklistPayload buildWidgetChecklistPayload({
  required List<Habit> habits,
  required Map<String, Map<LocalDay, HabitLog>> logsByHabit,
  required LocalDay today,
  int maxRows = 6,
}) {
  final due = [
    for (final habit in habits)
      if (isHabitDueOn(habit, today)) habit,
  ];

  final visible = due.take(maxRows).toList(growable: false);
  final rows = [
    for (final habit in visible)
      WidgetChecklistRow(
        id: habit.id,
        name: habit.name,
        done:
            (logsByHabit[habit.id] ?? const <LocalDay, HabitLog>{})[today]
                ?.status ==
            LogStatus.done,
      ),
  ];

  return WidgetChecklistPayload(
    date: today.toIso(),
    done: rows.where((row) => row.done).length,
    total: due.length,
    more: due.length - rows.length,
    rows: rows,
  );
}
