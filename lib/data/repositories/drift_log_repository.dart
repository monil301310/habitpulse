import 'package:drift/drift.dart';

import '../../domain/entities/habit_log.dart';
import '../../domain/enums/log_status.dart';
import '../../domain/models/local_day.dart';
import '../../domain/repositories/log_repository.dart';
import '../database/app_database.dart';

/// Drift-backed implementation of [LogRepository].
class DriftLogRepository implements LogRepository {
  DriftLogRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<HabitLog>> watchAllLogs() {
    final query = _db.select(_db.logs)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.date)]);

    return query.watch().map(
      (rows) => rows.map((row) => _toEntity(row)).toList(growable: false),
    );
  }

  @override
  Stream<Map<LocalDay, HabitLog>> watchLogsByDay(String habitId) {
    final query = _db.select(_db.logs)
      ..where((t) => t.habitId.equals(habitId) & t.deletedAt.isNull());

    return query.watch().map((rows) {
      final byDay = <LocalDay, HabitLog>{};
      for (final row in rows) {
        final day = LocalDay.tryParse(row.date);
        if (day != null) byDay[day] = _toEntity(row, day);
      }
      return byDay;
    });
  }

  @override
  Future<HabitLog?> findLog(String habitId, LocalDay day) async {
    final query = _db.select(_db.logs)
      ..where(
        (t) =>
            t.habitId.equals(habitId) &
            t.date.equals(day.toIso()) &
            t.deletedAt.isNull(),
      )
      ..limit(1);

    final row = await query.getSingleOrNull();
    return row == null ? null : _toEntity(row, day);
  }

  @override
  Future<void> saveLog(HabitLog log) {
    return _db
        .into(_db.logs)
        .insertOnConflictUpdate(
          LogsCompanion(
            id: Value(log.id),
            habitId: Value(log.habitId),
            date: Value(log.date.toIso()),
            value: Value(log.value),
            status: Value(log.status.storageKey),
            note: Value(log.note),
            updatedAt: Value(log.updatedAt),
            deletedAt: Value(log.deletedAt),
          ),
        );
  }

  @override
  Future<void> deleteLog(String id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.logs)..where((t) => t.id.equals(id))).write(
      LogsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  HabitLog _toEntity(LogRow row, [LocalDay? day]) {
    return HabitLog(
      id: row.id,
      habitId: row.habitId,
      date: day ?? LocalDay.parse(row.date),
      value: row.value,
      status: LogStatus.fromStorageKey(row.status),
      note: row.note,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
