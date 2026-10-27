import 'package:uuid/uuid.dart';

import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/enums/habit_type.dart';
import '../../domain/enums/log_status.dart';
import '../../domain/models/local_day.dart';
import '../../domain/repositories/log_repository.dart';

/// The single place that writes habit logs.
///
/// Keeping every write here means a new source (notification action, Android
/// widget, NFC tag, integration) only has to call one of these methods, and the
/// status rules stay consistent. See section 10 of the spec.
class HabitLogService {
  HabitLogService(this._repository, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final LogRepository _repository;
  final Uuid _uuid;

  Future<HabitLog?> logFor(Habit habit, LocalDay day) {
    return _repository.findLog(habit.id, day);
  }

  /// Marks the day complete. Count and timed habits jump to their daily target.
  Future<void> markDone(Habit habit, LocalDay day) async {
    final existing = await _repository.findLog(habit.id, day);
    final value = switch (habit.type) {
      HabitType.count || HabitType.timed => habit.targetValue ?? 0,
      _ => existing?.value ?? 0,
    };
    await _write(
      habit,
      day,
      value: value,
      status: LogStatus.done,
      existing: existing,
    );
  }

  /// Adds [delta] to a count or timed habit, completing it once it reaches the
  /// target.
  Future<void> addValue(Habit habit, LocalDay day, double delta) async {
    final existing = await _repository.findLog(habit.id, day);
    final next = (existing?.value ?? 0) + delta;
    await _writeValue(
      habit,
      day,
      next < 0 ? 0 : next,
      existing: existing,
    );
  }

  /// Sets an exact value for a count or timed habit.
  Future<void> setValue(Habit habit, LocalDay day, double value) async {
    final existing = await _repository.findLog(habit.id, day);
    await _writeValue(habit, day, value < 0 ? 0 : value, existing: existing);
  }

  Future<void> _writeValue(
    Habit habit,
    LocalDay day,
    double value, {
    HabitLog? existing,
  }) async {
    final target = habit.targetValue ?? 0;
    final status = value >= target ? LogStatus.done : LogStatus.partial;
    await _write(
      habit,
      day,
      value: value,
      status: status,
      existing: existing,
    );
  }

  /// Deliberately skips the day; does not break the streak.
  Future<void> skip(Habit habit, LocalDay day) {
    return _writeStatus(habit, day, LogStatus.skipped);
  }

  /// Marks the day missed.
  Future<void> markMissed(Habit habit, LocalDay day) {
    return _writeStatus(habit, day, LogStatus.missed);
  }

  /// Confirms a negative habit was avoided today.
  Future<void> confirmAvoided(Habit habit, LocalDay day) {
    return _writeStatus(habit, day, LogStatus.done);
  }

  /// Records a slip for a negative habit.
  Future<void> markSlipped(Habit habit, LocalDay day) {
    return _writeStatus(habit, day, LogStatus.slipped);
  }

  /// Removes the log for a day, returning it to the open state.
  Future<void> clear(Habit habit, LocalDay day) async {
    final existing = await _repository.findLog(habit.id, day);
    if (existing != null) await _repository.deleteLog(existing.id);
  }

  /// Saves (or clears) the free-text note on an existing log.
  ///
  /// A note belongs to a log, so nothing happens when the day has not been
  /// logged yet.
  Future<void> setNote(Habit habit, LocalDay day, String? note) async {
    final existing = await _repository.findLog(habit.id, day);
    if (existing == null) return;

    final trimmed = (note ?? '').trim();
    await _repository.saveLog(
      HabitLog(
        id: existing.id,
        habitId: existing.habitId,
        date: existing.date,
        value: existing.value,
        status: existing.status,
        note: trimmed.isEmpty ? null : trimmed,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _writeStatus(
    Habit habit,
    LocalDay day,
    LogStatus status,
  ) async {
    final existing = await _repository.findLog(habit.id, day);
    await _write(
      habit,
      day,
      value: existing?.value ?? 0,
      status: status,
      existing: existing,
    );
  }

  Future<void> _write(
    Habit habit,
    LocalDay day, {
    required double value,
    required LogStatus status,
    HabitLog? existing,
  }) {
    final log = HabitLog(
      id: existing?.id ?? _uuid.v4(),
      habitId: habit.id,
      date: day,
      value: value,
      status: status,
      note: existing?.note,
      updatedAt: DateTime.now().toUtc(),
    );
    return _repository.saveLog(log);
  }
}
