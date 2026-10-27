import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/sync/conflict_resolver.dart';
import '../database/app_database.dart';

/// Result of one sync pass.
class SyncSummary {
  const SyncSummary({
    required this.pushed,
    required this.pulled,
    required this.finishedAt,
    this.error,
  });

  final int pushed;
  final int pulled;
  final DateTime finishedAt;
  final Object? error;

  bool get succeeded => error == null;
}

/// Pushes local changes and pulls remote changes for the four synced tables.
///
/// Every table keeps its own high-water marks in `sync_state`. Pull happens
/// before push so a newer remote row is applied locally before the local copy is
/// uploaded, which makes the newest-updated_at rule hold on both sides.
class SyncService {
  SyncService(this._db, this._client, this.userId);

  final AppDatabase _db;
  final SupabaseClient _client;
  final String userId;

  static final DateTime _epoch = DateTime.utc(1970);

  static const List<String> _tables = ['habits', 'reminders', 'logs', 'settings'];

  RealtimeChannel? _channel;

  Future<SyncSummary> sync() async {
    var pushed = 0;
    var pulled = 0;
    try {
      final habits = await _syncHabits();
      pushed += habits.$1;
      pulled += habits.$2;

      final reminders = await _syncReminders();
      pushed += reminders.$1;
      pulled += reminders.$2;

      final logs = await _syncLogs();
      pushed += logs.$1;
      pulled += logs.$2;

      final settings = await _syncSettings();
      pushed += settings.$1;
      pulled += settings.$2;

      return SyncSummary(
        pushed: pushed,
        pulled: pulled,
        finishedAt: DateTime.now().toUtc(),
      );
    } on Object catch (error) {
      return SyncSummary(
        pushed: pushed,
        pulled: pulled,
        finishedAt: DateTime.now().toUtc(),
        error: error,
      );
    }
  }

  /// Subscribes to Supabase realtime for all synced tables.
  void startRealtime(void Function() onRemoteChange) {
    if (_channel != null) return;

    var channel = _client.channel('habitpulse-$userId');
    for (final table in _tables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => onRemoteChange(),
      );
    }
    _channel = channel;
    _channel!.subscribe();
  }

  Future<void> stopRealtime() async {
    await _channel?.unsubscribe();
    _channel = null;
  }

  Future<void> resetSyncState() async {
    await _db.delete(_db.syncStates).go();
  }

  /// Clears all local user data (used on sign-out).
  Future<void> clearLocalData() async {
    await _db.transaction(() async {
      await _db.delete(_db.logs).go();
      await _db.delete(_db.reminders).go();
      await _db.delete(_db.habits).go();
      await _db.delete(_db.appSettingsTable).go();
      await _db.delete(_db.syncStates).go();
    });
  }

  // ------------------------------------------------------------------ habits

  Future<(int, int)> _syncHabits() async {
    final state = await _stateRow('habits');
    final lastPull = state?.lastPull ?? _epoch;
    final lastPush = state?.lastPush ?? _epoch;

    final remote = await _client
        .from('habits')
        .select()
        .eq('user_id', userId)
        .gte('updated_at', lastPull.toUtc().toIso8601String());

    var pulled = 0;
    DateTime? newestPull;

    for (final row in remote) {
      final remoteUpdated = _dt(row['updated_at']);
      if (remoteUpdated == null) continue;

      final local = await (_db.select(
        _db.habits,
      )..where((t) => t.id.equals(row['id'] as String))).getSingleOrNull();

      if (!shouldApplyRemote(
        localUpdatedAt: local?.updatedAt,
        remoteUpdatedAt: remoteUpdated,
      )) {
        continue;
      }

      await _db
          .into(_db.habits)
          .insertOnConflictUpdate(_habitFromRemote(row));
      pulled++;
      newestPull = _maxDate(newestPull, remoteUpdated);
    }

    final localRows =
        await (_db.select(_db.habits)
              ..where((t) => t.updatedAt.isBiggerThanValue(lastPush)))
            .get();

    if (localRows.isNotEmpty) {
      await _pushInChunks(
        'habits',
        localRows.map(_habitToRemote).toList(growable: false),
      );
    }

    final newestPush = localRows.isEmpty
        ? state?.lastPush
        : localRows
              .map((row) => row.updatedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    await _setState(
      'habits',
      lastPush: newestPush ?? lastPush,
      lastPull: newestPull ?? lastPull,
    );
    return (localRows.length, pulled);
  }

  HabitsCompanion _habitFromRemote(Map<String, dynamic> row) {
    return HabitsCompanion(
      id: Value(row['id'] as String),
      userId: Value(row['user_id'] as String? ?? userId),
      name: Value(row['name'] as String? ?? ''),
      icon: Value(row['icon'] as String? ?? 'bolt'),
      colour: Value(row['colour'] as String? ?? '#4ADE80'),
      type: Value(row['type'] as String? ?? 'yes_no'),
      targetValue: Value((row['target_value'] as num?)?.toDouble()),
      unit: Value(row['unit'] as String?),
      scheduleType: Value(row['schedule_type'] as String? ?? 'daily'),
      scheduleDays: Value(row['schedule_days'] as String? ?? ''),
      timesPerWeek: Value((row['times_per_week'] as num?)?.toInt()),
      startDate: Value(row['start_date'] as String?),
      archivedAt: Value(_dt(row['archived_at'])),
      sortOrder: Value((row['sort_order'] as num?)?.toInt() ?? 0),
      source: Value(row['source'] as String? ?? 'manual'),
      createdAt: Value(_dt(row['created_at']) ?? DateTime.now().toUtc()),
      updatedAt: Value(_dt(row['updated_at']) ?? DateTime.now().toUtc()),
      deletedAt: Value(_dt(row['deleted_at'])),
    );
  }

  Map<String, dynamic> _habitToRemote(HabitRow row) {
    return {
      'id': row.id,
      'user_id': userId,
      'name': row.name,
      'icon': row.icon,
      'colour': row.colour,
      'type': row.type,
      'target_value': row.targetValue,
      'unit': row.unit,
      'schedule_type': row.scheduleType,
      'schedule_days': row.scheduleDays,
      'times_per_week': row.timesPerWeek,
      'start_date': row.startDate,
      'archived_at': _iso(row.archivedAt),
      'sort_order': row.sortOrder,
      'source': row.source,
      'created_at': _iso(row.createdAt),
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _iso(row.deletedAt),
    };
  }

  // --------------------------------------------------------------- reminders

  Future<(int, int)> _syncReminders() async {
    final state = await _stateRow('reminders');
    final lastPull = state?.lastPull ?? _epoch;
    final lastPush = state?.lastPush ?? _epoch;

    final remote = await _client
        .from('reminders')
        .select()
        .eq('user_id', userId)
        .gte('updated_at', lastPull.toUtc().toIso8601String());

    var pulled = 0;
    DateTime? newestPull;

    for (final row in remote) {
      final remoteUpdated = _dt(row['updated_at']);
      if (remoteUpdated == null) continue;

      final local = await (_db.select(
        _db.reminders,
      )..where((t) => t.id.equals(row['id'] as String))).getSingleOrNull();

      if (!shouldApplyRemote(
        localUpdatedAt: local?.updatedAt,
        remoteUpdatedAt: remoteUpdated,
      )) {
        continue;
      }

      await _db
          .into(_db.reminders)
          .insertOnConflictUpdate(_reminderFromRemote(row));
      pulled++;
      newestPull = _maxDate(newestPull, remoteUpdated);
    }

    final localRows =
        await (_db.select(_db.reminders)
              ..where((t) => t.updatedAt.isBiggerThanValue(lastPush)))
            .get();

    if (localRows.isNotEmpty) {
      await _pushInChunks(
        'reminders',
        localRows.map(_reminderToRemote).toList(growable: false),
      );
    }

    final newestPush = localRows.isEmpty
        ? state?.lastPush
        : localRows
              .map((row) => row.updatedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    await _setState(
      'reminders',
      lastPush: newestPush ?? lastPush,
      lastPull: newestPull ?? lastPull,
    );
    return (localRows.length, pulled);
  }

  RemindersCompanion _reminderFromRemote(Map<String, dynamic> row) {
    return RemindersCompanion(
      id: Value(row['id'] as String),
      habitId: Value(row['habit_id'] as String),
      timeOfDay: Value(row['time_of_day'] as String? ?? '09:00'),
      daysOfWeek: Value(row['days_of_week'] as String? ?? ''),
      enabled: Value(row['enabled'] as bool? ?? true),
      updatedAt: Value(_dt(row['updated_at']) ?? DateTime.now().toUtc()),
      deletedAt: Value(_dt(row['deleted_at'])),
    );
  }

  Map<String, dynamic> _reminderToRemote(ReminderRow row) {
    return {
      'id': row.id,
      'user_id': userId,
      'habit_id': row.habitId,
      'time_of_day': row.timeOfDay,
      'days_of_week': row.daysOfWeek,
      'enabled': row.enabled,
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _iso(row.deletedAt),
    };
  }

  // -------------------------------------------------------------------- logs

  Future<(int, int)> _syncLogs() async {
    final state = await _stateRow('logs');
    final lastPull = state?.lastPull ?? _epoch;
    final lastPush = state?.lastPush ?? _epoch;

    final remote = await _client
        .from('logs')
        .select()
        .eq('user_id', userId)
        .gte('updated_at', lastPull.toUtc().toIso8601String());

    var pulled = 0;
    DateTime? newestPull;

    for (final row in remote) {
      final remoteUpdated = _dt(row['updated_at']);
      if (remoteUpdated == null) continue;

      final remoteId = row['id'] as String;
      final habitId = row['habit_id'] as String;
      final date = row['date'] as String;

      final localById = await (_db.select(
        _db.logs,
      )..where((t) => t.id.equals(remoteId))).getSingleOrNull();
      // A second device may have created a different id for the same habit/day.
      final localSameDay =
          await (_db.select(_db.logs)..where(
                (t) =>
                    t.habitId.equals(habitId) &
                    t.date.equals(date) &
                    t.deletedAt.isNull(),
              ))
              .getSingleOrNull();

      final local = localById ?? localSameDay;

      if (!shouldApplyRemote(
        localUpdatedAt: local?.updatedAt,
        remoteUpdatedAt: remoteUpdated,
        isLog: true,
        localStatus: local?.status,
        remoteStatus: row['status'] as String?,
      )) {
        continue;
      }

      // Make room for the winning row without changing the loser's updated_at
      // (which would push the deletion to other devices).
      if (localSameDay != null && localSameDay.id != remoteId) {
        await (_db.update(_db.logs)
              ..where((t) => t.id.equals(localSameDay.id)))
            .write(LogsCompanion(deletedAt: Value(DateTime.now().toUtc())));
      }

      await _db.into(_db.logs).insertOnConflictUpdate(_logFromRemote(row));
      pulled++;
      newestPull = _maxDate(newestPull, remoteUpdated);
    }

    final localRows =
        await (_db.select(_db.logs)
              ..where((t) => t.updatedAt.isBiggerThanValue(lastPush)))
            .get();

    if (localRows.isNotEmpty) {
      await _pushInChunks(
        'logs',
        localRows.map(_logToRemote).toList(growable: false),
      );
    }

    final newestPush = localRows.isEmpty
        ? state?.lastPush
        : localRows
              .map((row) => row.updatedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    await _setState(
      'logs',
      lastPush: newestPush ?? lastPush,
      lastPull: newestPull ?? lastPull,
    );
    return (localRows.length, pulled);
  }

  LogsCompanion _logFromRemote(Map<String, dynamic> row) {
    return LogsCompanion(
      id: Value(row['id'] as String),
      habitId: Value(row['habit_id'] as String),
      date: Value(row['date'] as String),
      value: Value((row['value'] as num?)?.toDouble() ?? 0),
      status: Value(row['status'] as String? ?? 'done'),
      note: Value(row['note'] as String?),
      updatedAt: Value(_dt(row['updated_at']) ?? DateTime.now().toUtc()),
      deletedAt: Value(_dt(row['deleted_at'])),
    );
  }

  Map<String, dynamic> _logToRemote(LogRow row) {
    return {
      'id': row.id,
      'user_id': userId,
      'habit_id': row.habitId,
      'date': row.date,
      'value': row.value,
      'status': row.status,
      'note': row.note,
      'updated_at': _iso(row.updatedAt),
      'deleted_at': _iso(row.deletedAt),
    };
  }

  // ---------------------------------------------------------------- settings

  Future<(int, int)> _syncSettings() async {
    final state = await _stateRow('settings');
    final lastPull = state?.lastPull ?? _epoch;
    final lastPush = state?.lastPush ?? _epoch;

    final remote = await _client
        .from('settings')
        .select()
        .eq('user_id', userId)
        .gte('updated_at', lastPull.toUtc().toIso8601String());

    var pulled = 0;
    DateTime? newestPull;

    if (remote.isNotEmpty) {
      final row = remote.first;
      final remoteUpdated = _dt(row['updated_at']);
      final local = await (_db.select(
        _db.appSettingsTable,
      )..where((t) => t.userId.equals('local'))).getSingleOrNull();

      if (remoteUpdated != null &&
          shouldApplyRemote(
            localUpdatedAt: local?.updatedAt,
            remoteUpdatedAt: remoteUpdated,
          )) {
        await _db
            .into(_db.appSettingsTable)
            .insertOnConflictUpdate(_settingsFromRemote(row));
        pulled = 1;
        newestPull = remoteUpdated;
      }
    }

    final localRows =
        await (_db.select(_db.appSettingsTable)
              ..where((t) => t.updatedAt.isBiggerThanValue(lastPush)))
            .get();

    if (localRows.isNotEmpty) {
      await _pushInChunks(
        'settings',
        localRows.map(_settingsToRemote).toList(growable: false),
      );
    }

    final newestPush = localRows.isEmpty
        ? state?.lastPush
        : localRows
              .map((row) => row.updatedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    await _setState(
      'settings',
      lastPush: newestPush ?? lastPush,
      lastPull: newestPull ?? lastPull,
    );
    return (localRows.length, pulled);
  }

  AppSettingsTableCompanion _settingsFromRemote(
    Map<String, dynamic> row,
  ) {
    return AppSettingsTableCompanion(
      // Local settings always live under the single local row.
      userId: const Value('local'),
      theme: Value(row['theme'] as String? ?? 'dark'),
      weekStart: Value((row['week_start'] as num?)?.toInt() ?? 1),
      dayRolloverTime: Value(row['day_rollover_time'] as String? ?? '03:00'),
      quietHours: Value(row['quiet_hours'] as String? ?? '23:00-07:00'),
      recheckTime: Value(row['recheck_time'] as String? ?? '21:30'),
      morningRecheckTime: Value(row['morning_recheck_time'] as String?),
      notificationSound: Value(row['notification_sound'] as bool? ?? true),
      updatedAt: Value(_dt(row['updated_at']) ?? DateTime.now().toUtc()),
    );
  }

  Map<String, dynamic> _settingsToRemote(SettingsRow row) {
    return {
      'user_id': userId,
      'theme': row.theme,
      'week_start': row.weekStart,
      'day_rollover_time': row.dayRolloverTime,
      'quiet_hours': row.quietHours,
      'recheck_time': row.recheckTime,
      'morning_recheck_time': row.morningRecheckTime,
      'notification_sound': row.notificationSound,
      'updated_at': _iso(row.updatedAt),
    };
  }

  // ------------------------------------------------------------------ shared

  Future<SyncStateRow?> _stateRow(String table) async {
    final query = _db.select(_db.syncStates)
      ..where((t) => t.tableKey.equals(table));
    return query.getSingleOrNull();
  }

  Future<void> _setState(
    String table, {
    required DateTime lastPush,
    required DateTime lastPull,
  }) {
    return _db
        .into(_db.syncStates)
        .insertOnConflictUpdate(
          SyncStatesCompanion(
            tableKey: Value(table),
            lastPush: Value(lastPush),
            lastPull: Value(lastPull),
          ),
        );
  }

  Future<void> _pushInChunks(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    const chunkSize = 100;
    for (var start = 0; start < rows.length; start += chunkSize) {
      final end = math.min(start + chunkSize, rows.length);
      await _client.from(table).upsert(rows.sublist(start, end));
    }
  }

  static DateTime? _dt(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }

  static String? _iso(DateTime? value) {
    return value?.toUtc().toIso8601String();
  }

  static DateTime _maxDate(DateTime? current, DateTime candidate) {
    if (current == null) return candidate;
    return candidate.isAfter(current) ? candidate : current;
  }
}
