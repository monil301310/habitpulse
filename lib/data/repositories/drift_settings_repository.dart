import 'package:drift/drift.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../database/app_database.dart';

/// Drift-backed settings, stored as one row for the local user.
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<AppSettings> watchSettings() {
    final query = _db.select(_db.appSettingsTable)
      ..where((t) => t.userId.equals('local'));

    return query.watchSingleOrNull().map(
      (row) => row == null ? AppSettings.defaults() : _toEntity(row),
    );
  }

  @override
  Future<AppSettings> load() async {
    final query = _db.select(_db.appSettingsTable)
      ..where((t) => t.userId.equals('local'));
    final row = await query.getSingleOrNull();
    return row == null ? AppSettings.defaults() : _toEntity(row);
  }

  @override
  Future<void> save(AppSettings settings) {
    return _db
        .into(_db.appSettingsTable)
        .insertOnConflictUpdate(
          AppSettingsTableCompanion(
            userId: Value(settings.userId),
            theme: Value(settings.theme),
            weekStart: Value(settings.weekStart),
            dayRolloverTime: Value(settings.dayRolloverTime),
            quietHours: Value(settings.quietHours),
            recheckTime: Value(settings.recheckTime),
            morningRecheckTime: Value(settings.morningRecheckTime),
            notificationSound: Value(settings.notificationSound),
            updatedAt: Value(settings.updatedAt),
          ),
        );
  }

  AppSettings _toEntity(SettingsRow row) {
    return AppSettings(
      userId: row.userId,
      theme: row.theme,
      weekStart: row.weekStart,
      dayRolloverTime: row.dayRolloverTime,
      quietHours: row.quietHours,
      recheckTime: row.recheckTime,
      morningRecheckTime: row.morningRecheckTime,
      notificationSound: row.notificationSound,
      updatedAt: row.updatedAt,
    );
  }
}
