import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('schema v4 is created and habits round-trip', () async {
    // First query opens the database and runs the onCreate migration.
    final initial = await db.select(db.habits).get();
    expect(initial, isEmpty);
    expect(db.schemaVersion, 4);

    final now = DateTime.utc(2026, 10, 25, 12);
    await db
        .into(db.habits)
        .insert(
          HabitsCompanion.insert(
            id: 'h1',
            name: 'Read 20 pages',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final rows = await db.select(db.habits).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Read 20 pages');
    expect(rows.single.type, 'yes_no');
    expect(rows.single.userId, 'local');

    // Soft-delete visibility: a deleted habit is still stored.
    await (db.update(db.habits)..where((t) => t.id.equals('h1'))).write(
      HabitsCompanion(deletedAt: Value(now)),
    );
    final remaining = await db.select(db.habits).get();
    expect(remaining.single.deletedAt, isNotNull);
  });

  test('only one active log per habit per day is allowed', () async {
    final now = DateTime.utc(2026, 10, 25, 12);
    await db
        .into(db.habits)
        .insert(
          HabitsCompanion.insert(
            id: 'h1',
            name: 'Read',
            createdAt: now,
            updatedAt: now,
          ),
        );

    Future<void> insertLog(String id) {
      return db
          .into(db.logs)
          .insert(
            LogsCompanion.insert(
              id: id,
              habitId: 'h1',
              date: '2026-10-25',
              updatedAt: now,
            ),
          );
    }

    await insertLog('l1');
    await expectLater(insertLog('l2'), throwsA(isA<Exception>()));

    // A soft-deleted log frees the day for a fresh one.
    await (db.update(db.logs)..where((t) => t.id.equals('l1'))).write(
      LogsCompanion(deletedAt: Value(now)),
    );
    await insertLog('l3');

    final active = await (db.select(
      db.logs,
    )..where((t) => t.deletedAt.isNull())).get();
    expect(active, hasLength(1));
    expect(active.single.id, 'l3');
  });

  test('a log survives a save-and-read round trip', () async {
    final now = DateTime.utc(2026, 10, 25, 12);
    await db
        .into(db.habits)
        .insert(
          HabitsCompanion.insert(
            id: 'h1',
            name: 'Water',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.logs)
        .insert(
          LogsCompanion.insert(
            id: 'l1',
            habitId: 'h1',
            date: '2026-10-25',
            value: const Value(5),
            status: const Value('partial'),
            updatedAt: now,
          ),
        );

    final log = await (db.select(
      db.logs,
    )..where((t) => t.id.equals('l1'))).getSingle();

    expect(log.value, 5);
    expect(log.status, 'partial');
  });
}
