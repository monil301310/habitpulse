import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/constants/app_constants.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The app's local SQLite database.
///
/// Everything the UI shows is read from here, which keeps the app fully
/// offline-first (cloud sync is layered on top in Phase 5).
@DriftDatabase(
  tables: [Habits, Reminders, Logs, AppSettingsTable, SyncStates],
)
class AppDatabase extends _$AppDatabase {
  /// Lets tests inject an in-memory executor.
  AppDatabase(super.e);

  /// Opens the real on-device database (`habitpulse.sqlite`).
  AppDatabase.defaults()
    : super(driftDatabase(name: AppConstants.databaseName));

  @override
  int get schemaVersion => AppConstants.schemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _createLogIndexes();
      },
      onUpgrade: (m, from, to) async {
        // One guarded step per schema version.
        if (from < 2) {
          // v1 could hold two active logs for the same habit and day if a
          // double tap raced; soft-delete the extras before adding the index.
          await customStatement('''
            UPDATE logs SET deleted_at = updated_at
            WHERE deleted_at IS NULL AND id NOT IN (
              SELECT id FROM (
                SELECT id,
                       ROW_NUMBER() OVER (
                         PARTITION BY habit_id, date ORDER BY updated_at DESC, id
                       ) AS position
                FROM logs
                WHERE deleted_at IS NULL
              )
              WHERE position = 1
            )
          ''');
          await _createLogIndexes();
        }
        if (from < 3) {
          await m.addColumn(
            appSettingsTable,
            appSettingsTable.notificationSound,
          );
        }
        if (from < 4) {
          await m.createTable(syncStates);
        }
      },
      beforeOpen: (details) async {
        // SQLite disables foreign keys per connection by default.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createLogIndexes() async {
    // At most one *active* log per habit per local day. Soft-deleted rows are
    // excluded so a day can be cleared and logged again.
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_logs_habit_day
      ON logs (habit_id, date)
      WHERE deleted_at IS NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_logs_day
      ON logs (date)
    ''');
  }
}
