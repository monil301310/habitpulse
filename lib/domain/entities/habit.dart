import '../enums/habit_type.dart';
import '../enums/schedule_type.dart';
import '../models/local_day.dart';

/// A single habit, as the user understands it.
///
/// This is a pure-domain model: it imports no Flutter or database code, so the
/// schedule and streak rules built on top of it in Phase 2 stay unit-testable.
class Habit {
  const Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.colour,
    required this.type,
    this.targetValue,
    this.unit,
    this.scheduleType = ScheduleType.daily,
    this.scheduleDays = const {},
    this.timesPerWeek,
    this.startDate,
    this.archivedAt,
    this.sortOrder = 0,
    this.source = 'manual',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// UUID generated on the device so offline creation never collides.
  final String id;
  final String userId;

  final String name;

  /// Key of an icon from the built-in icon set.
  final String icon;

  /// Accent colour (hex string) used to tint the heatmap.
  final String colour;

  final HabitType type;

  /// Daily target for count (e.g. 8) and timed (e.g. 30 minutes) habits.
  final double? targetValue;

  /// Unit label for count/timed habits (e.g. "glasses", "min").
  final String? unit;

  final ScheduleType scheduleType;

  /// ISO weekdays (Monday = 1 … Sunday = 7) the habit is due on.
  final Set<int> scheduleDays;

  /// Number of completions required per week for [ScheduleType.timesPerWeek].
  final int? timesPerWeek;

  /// Optional local calendar day the habit starts on.
  final LocalDay? startDate;

  final DateTime? archivedAt;

  /// Manual ordering on the home screen.
  final int sortOrder;

  /// Where the habit came from: manual, notification, widget, nfc, integration.
  final String source;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Soft delete marker so deletions can sync.
  final DateTime? deletedAt;

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;

  /// Whether this habit is due on [weekday] (ISO, Monday = 1).
  bool isDueOnWeekday(int weekday) {
    return switch (scheduleType) {
      ScheduleType.daily => true,
      ScheduleType.weekdays => scheduleDays.contains(weekday),
      // X-per-week habits are "due" any day, the week is satisfied once the
      // target number of completions is reached.
      ScheduleType.timesPerWeek => true,
    };
  }

  Habit copyWith({
    String? name,
    String? icon,
    String? colour,
    HabitType? type,
    double? targetValue,
    String? unit,
    ScheduleType? scheduleType,
    Set<int>? scheduleDays,
    int? timesPerWeek,
    LocalDay? startDate,
    DateTime? archivedAt,
    int? sortOrder,
    String? source,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Habit(
      id: id,
      userId: userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colour: colour ?? this.colour,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      scheduleType: scheduleType ?? this.scheduleType,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      timesPerWeek: timesPerWeek ?? this.timesPerWeek,
      startDate: startDate ?? this.startDate,
      archivedAt: archivedAt ?? this.archivedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      source: source ?? this.source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
