import 'package:drift/drift.dart';

/// `habits` — one row per habit.
///
/// Mirrors the `habits` table in section 8 of the spec so the local schema and
/// the future Supabase schema stay the same shape.
@DataClassName('HabitRow')
class Habits extends Table {
  /// UUID generated on the device.
  TextColumn get id => text()();

  /// Owner. Until accounts arrive (Phase 5) everything is owned locally.
  TextColumn get userId => text().withDefault(const Constant('local'))();

  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('bolt'))();

  /// Hex accent colour, e.g. `#4ADE80`.
  TextColumn get colour => text().withDefault(const Constant('#4ADE80'))();

  /// `yes_no`, `count`, `timed` or `negative`.
  TextColumn get type => text().withDefault(const Constant('yes_no'))();

  RealColumn get targetValue => real().nullable()();
  TextColumn get unit => text().nullable()();

  /// `daily`, `weekdays` or `times_per_week`.
  TextColumn get scheduleType => text().withDefault(const Constant('daily'))();

  /// Comma-separated ISO weekdays, e.g. `1,3,5`.
  TextColumn get scheduleDays => text().withDefault(const Constant(''))();

  IntColumn get timesPerWeek => integer().nullable()();

  /// Local calendar day as `yyyy-MM-dd`.
  TextColumn get startDate => text().nullable()();

  DateTimeColumn get archivedAt => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// `manual` by default; reserved for notification, widget, nfc, integration.
  TextColumn get source => text().withDefault(const Constant('manual'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// `reminders` — zero or more per habit.
@DataClassName('ReminderRow')
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();

  /// Local time of day, `HH:mm`.
  TextColumn get timeOfDay => text()();

  /// Comma-separated ISO weekdays; empty means "use the habit's days".
  TextColumn get daysOfWeek => text().withDefault(const Constant(''))();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// `logs` — one row per habit per local day.
@DataClassName('LogRow')
class Logs extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();

  /// Local calendar day as `yyyy-MM-dd` (no time-zone shifting).
  TextColumn get date => text()();

  RealColumn get value => real().withDefault(const Constant(0))();

  /// `done`, `partial`, `missed`, `skipped` or `slipped`.
  TextColumn get status => text().withDefault(const Constant('done'))();

  TextColumn get note => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// `settings` — one row per user (currently a single local user).
@DataClassName('SettingsRow')
class AppSettingsTable extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get userId => text()();

  /// `dark`, `light` or `system`.
  TextColumn get theme => text().withDefault(const Constant('dark'))();

  IntColumn get weekStart => integer().withDefault(const Constant(1))();

  /// `HH:mm`.
  TextColumn get dayRolloverTime =>
      text().withDefault(const Constant('03:00'))();

  /// `HH:mm-HH:mm`.
  TextColumn get quietHours =>
      text().withDefault(const Constant('23:00-07:00'))();

  /// `HH:mm`.
  TextColumn get recheckTime => text().withDefault(const Constant('21:30'))();

  /// `HH:mm`, or null when the morning recheck is off.
  TextColumn get morningRecheckTime => text().nullable()();

  /// Whether notifications should play a sound.
  BoolColumn get notificationSound =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}

/// Per-table high-water marks for cloud sync.
@DataClassName('SyncStateRow')
class SyncStates extends Table {
  TextColumn get tableKey => text()();

  /// Newest `updated_at` successfully pushed to the server.
  DateTimeColumn get lastPush => dateTime().nullable()();

  /// Newest remote `updated_at` successfully pulled.
  DateTimeColumn get lastPull => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {tableKey};
}
