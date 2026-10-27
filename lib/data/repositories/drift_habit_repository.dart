import 'package:drift/drift.dart';

import '../../domain/entities/habit.dart';
import '../../domain/enums/habit_type.dart';
import '../../domain/enums/schedule_type.dart';
import '../../domain/models/local_day.dart';
import '../../domain/repositories/habit_repository.dart';
import '../database/app_database.dart';

/// Drift-backed implementation of [HabitRepository].
class DriftHabitRepository implements HabitRepository {
  DriftHabitRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Habit>> watchHabits({bool includeArchived = false}) {
    final query = _db.select(_db.habits)
      ..where((t) {
        var predicate = t.deletedAt.isNull();
        if (!includeArchived) {
          predicate = predicate & t.archivedAt.isNull();
        }
        return predicate;
      })
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.createdAt),
      ]);

    return query.watch().map(
      (rows) => rows.map(_toEntity).toList(growable: false),
    );
  }

  @override
  Future<Habit?> getHabit(String id) async {
    final query = _db.select(_db.habits)
      ..where((t) => t.id.equals(id) & t.deletedAt.isNull())
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> saveHabit(Habit habit) {
    return _db.into(_db.habits).insertOnConflictUpdate(_toCompanion(habit));
  }

  @override
  Future<void> setArchived(String id, {required bool archived}) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.habits)..where((t) => t.id.equals(id))).write(
      HabitsCompanion(
        archivedAt: Value(archived ? now : null),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> deleteHabit(String id) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.habits)..where((t) => t.id.equals(id))).write(
        HabitsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (_db.update(_db.logs)..where((t) => t.habitId.equals(id))).write(
        LogsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (_db.update(_db.reminders)..where((t) => t.habitId.equals(id)))
          .write(
            RemindersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
          );
    });
  }

  Habit _toEntity(HabitRow row) {
    return Habit(
      id: row.id,
      userId: row.userId,
      name: row.name,
      icon: row.icon,
      colour: row.colour,
      type: HabitType.fromStorageKey(row.type),
      targetValue: row.targetValue,
      unit: row.unit,
      scheduleType: ScheduleType.fromStorageKey(row.scheduleType),
      scheduleDays: _parseDays(row.scheduleDays),
      timesPerWeek: row.timesPerWeek,
      startDate: LocalDay.tryParse(row.startDate),
      archivedAt: row.archivedAt,
      sortOrder: row.sortOrder,
      source: row.source,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  HabitsCompanion _toCompanion(Habit habit) {
    final sortedDays = habit.scheduleDays.toList()..sort();
    return HabitsCompanion(
      id: Value(habit.id),
      userId: Value(habit.userId),
      name: Value(habit.name),
      icon: Value(habit.icon),
      colour: Value(habit.colour),
      type: Value(habit.type.storageKey),
      targetValue: Value(habit.targetValue),
      unit: Value(habit.unit),
      scheduleType: Value(habit.scheduleType.storageKey),
      scheduleDays: Value(sortedDays.join(',')),
      timesPerWeek: Value(habit.timesPerWeek),
      startDate: Value(habit.startDate?.toIso()),
      archivedAt: Value(habit.archivedAt),
      sortOrder: Value(habit.sortOrder),
      source: Value(habit.source),
      createdAt: Value(habit.createdAt),
      updatedAt: Value(habit.updatedAt),
      deletedAt: Value(habit.deletedAt),
    );
  }

  Set<int> _parseDays(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const <int>{};
    return trimmed
        .split(',')
        .map((part) => int.tryParse(part.trim()))
        .whereType<int>()
        .toSet();
  }
}
