import 'package:drift/drift.dart';

import '../../domain/entities/habit_reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../database/app_database.dart';

/// Drift-backed implementation of [ReminderRepository].
class DriftReminderRepository implements ReminderRepository {
  DriftReminderRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<HabitReminder>> watchAll() {
    final query = _db.select(_db.reminders)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.timeOfDay)]);

    return query.watch().map(
      (rows) => rows.map(_toEntity).toList(growable: false),
    );
  }

  @override
  Future<List<HabitReminder>> listForHabit(String habitId) async {
    final query = _db.select(_db.reminders)..where(
      (t) => t.habitId.equals(habitId) & t.deletedAt.isNull(),
    );
    final rows = await query.get();
    return rows.map(_toEntity).toList(growable: false);
  }

  @override
  Future<void> replaceForHabit(
    String habitId,
    List<HabitReminder> reminders,
  ) async {
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.reminders)..where(
                (t) => t.habitId.equals(habitId) & t.deletedAt.isNull(),
              ))
              .get();

      final keepIds = reminders.map((r) => r.id).toSet();
      for (final row in existing) {
        if (!keepIds.contains(row.id)) {
          await (_db.update(_db.reminders)..where((t) => t.id.equals(row.id)))
              .write(
                RemindersCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        }
      }

      for (final reminder in reminders) {
        await _db
            .into(_db.reminders)
            .insertOnConflictUpdate(
              RemindersCompanion(
                id: Value(reminder.id),
                habitId: Value(reminder.habitId),
                timeOfDay: Value(reminder.timeOfDay),
                daysOfWeek: Value(_daysToCsv(reminder.daysOfWeek)),
                enabled: Value(reminder.enabled),
                updatedAt: Value(reminder.updatedAt),
                deletedAt: Value(reminder.deletedAt),
              ),
            );
      }
    });
  }

  HabitReminder _toEntity(ReminderRow row) {
    return HabitReminder(
      id: row.id,
      habitId: row.habitId,
      timeOfDay: row.timeOfDay,
      daysOfWeek: _parseDays(row.daysOfWeek),
      enabled: row.enabled,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  static String _daysToCsv(Set<int> days) {
    final sorted = days.toList()..sort();
    return sorted.join(',');
  }

  static Set<int> _parseDays(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const <int>{};
    return trimmed
        .split(',')
        .map((part) => int.tryParse(part.trim()))
        .whereType<int>()
        .toSet();
  }
}
