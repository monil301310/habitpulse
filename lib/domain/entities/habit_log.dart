import '../enums/log_status.dart';
import '../models/local_day.dart';

/// One day's entry for one habit.
///
/// A log is keyed by habit and by *local calendar day* (no time-zone shifting),
/// matching the sync rules in the spec.
class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.date,
    this.value = 0,
    required this.status,
    this.note,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String habitId;

  /// The local calendar day this log belongs to.
  final LocalDay date;

  /// Numeric value for count and timed habits; 0 for yes/no and negative.
  final double value;

  final LogStatus status;

  /// Optional free-text note, e.g. why a day was missed.
  final String? note;

  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  HabitLog copyWith({
    double? value,
    LogStatus? status,
    String? note,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return HabitLog(
      id: id,
      habitId: habitId,
      date: date,
      value: value ?? this.value,
      status: status ?? this.status,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
