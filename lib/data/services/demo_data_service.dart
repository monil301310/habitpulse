import 'package:drift/drift.dart';

import '../../domain/enums/log_status.dart';
import '../../domain/models/local_day.dart';
import '../database/app_database.dart';

/// Creates (or removes) a realistic three-year history for performance and
/// visual testing. Debug builds only; see the Developer section in Settings.
class DemoDataService {
  DemoDataService(this._db);

  final AppDatabase _db;

  static const String _prefix = 'demo-';

  Future<void> seed({required LocalDay today, int days = 1095}) async {
    await clear();

    final now = DateTime.now().toUtc();
    final startDate = today.addDays(-(days - 1));

    final habits = [
      _HabitSeed(
        id: '${_prefix}read',
        name: 'Read 20 pages',
        icon: 'book',
        colour: '#4ADE80',
        type: 'count',
        targetValue: 20,
        unit: 'pages',
        scheduleType: 'daily',
        doneThreshold: 80,
      ),
      _HabitSeed(
        id: '${_prefix}gym',
        name: 'Gym session',
        icon: 'fitness',
        colour: '#60A5FA',
        type: 'yes_no',
        scheduleType: 'weekdays',
        scheduleDays: '1,3,5',
        doneThreshold: 70,
        skipThreshold: 85,
      ),
      _HabitSeed(
        id: '${_prefix}meditate',
        name: 'Meditate',
        icon: 'meditate',
        colour: '#A78BFA',
        type: 'timed',
        targetValue: 15,
        unit: 'min',
        scheduleType: 'daily',
        doneThreshold: 65,
      ),
      _HabitSeed(
        id: '${_prefix}sugar',
        name: 'No added sugar',
        icon: 'no_smoke',
        colour: '#FB923C',
        type: 'negative',
        scheduleType: 'daily',
        doneThreshold: 78,
        slipThreshold: 92,
      ),
      _HabitSeed(
        id: '${_prefix}water',
        name: 'Drink water',
        icon: 'water',
        colour: '#22D3EE',
        type: 'count',
        targetValue: 8,
        unit: 'glasses',
        scheduleType: 'daily',
        doneThreshold: 75,
      ),
    ];

    final habitRows = [
      for (final seed in habits)
        HabitsCompanion.insert(
          id: seed.id,
          name: seed.name,
          icon: Value(seed.icon),
          colour: Value(seed.colour),
          type: Value(seed.type),
          targetValue: Value(seed.targetValue),
          unit: Value(seed.unit),
          scheduleType: Value(seed.scheduleType),
          scheduleDays: Value(seed.scheduleDays ?? ''),
          startDate: Value(startDate.toIso()),
          source: const Value('demo'),
          createdAt: now,
          updatedAt: now,
        ),
    ];

    final logRows = <LogsCompanion>[];

    for (var habitIndex = 0; habitIndex < habits.length; habitIndex++) {
      final seed = habits[habitIndex];
      final habitId = seed.id;
      final scheduleType = seed.scheduleType;

      for (var offset = 0; offset < days; offset++) {
        final day = startDate.addDays(offset);

        final due = switch (scheduleType) {
          'weekdays' => (seed.scheduleDays ?? '')
              .split(',')
              .contains('${day.weekday}'),
          _ => true,
        };
        if (!due) continue;

        // Deterministic pseudo-random so seeding the same range looks the same.
        final roll =
            (day.differenceInDays(const LocalDay(2000, 1, 1)) * 37 +
                habitIndex * 101) %
            100;

        final result = _logFor(seed, roll);
        if (result == null) continue;

        logRows.add(
          LogsCompanion.insert(
            id: '${_prefix}log-$habitId-${day.toIso()}',
            habitId: habitId,
            date: day.toIso(),
            value: Value(result.value),
            status: Value(result.status.storageKey),
            updatedAt: now,
          ),
        );
      }
    }

    await _db.batch((batch) {
      batch.insertAll(_db.habits, habitRows, mode: InsertMode.insertOrReplace);
      batch.insertAll(_db.logs, logRows, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> clear() async {
    await (_db.delete(_db.logs)
          ..where((t) => t.habitId.like('$_prefix%')))
        .go();
    await (_db.delete(_db.habits)..where((t) => t.id.like('$_prefix%'))).go();
  }

  _LogResult? _logFor(_HabitSeed seed, int roll) {
    if (roll < seed.doneThreshold) {
      final doneValue = (seed.type == 'count' || seed.type == 'timed')
          ? (seed.targetValue ?? 0)
          : 0.0;
      return _LogResult(LogStatus.done, doneValue);
    }

    switch (seed.type) {
      case 'count':
        final target = seed.targetValue ?? 1;
        final value = (target * 0.5).clamp(1, target - 1).toDouble();
        return _LogResult(LogStatus.partial, value);
      case 'timed':
        final target = seed.targetValue ?? 1;
        final value = (target * 0.5).clamp(1, target - 1).toDouble();
        return _LogResult(LogStatus.partial, value);
      case 'negative':
        final slipThreshold = seed.slipThreshold;
        if (slipThreshold != null && roll < slipThreshold) {
          return const _LogResult(LogStatus.slipped, 0);
        }
        return null;
      default:
        if (seed.skipThreshold != null && roll < seed.skipThreshold!) {
          return const _LogResult(LogStatus.skipped, 0);
        }
        return null;
    }
  }
}

class _HabitSeed {
  const _HabitSeed({
    required this.id,
    required this.name,
    required this.icon,
    required this.colour,
    required this.type,
    required this.scheduleType,
    this.targetValue,
    this.unit,
    this.scheduleDays,
    this.doneThreshold = 80,
    this.skipThreshold,
    this.slipThreshold,
  });

  final String id;
  final String name;
  final String icon;
  final String colour;
  final String type;
  final String scheduleType;
  final double? targetValue;
  final String? unit;
  final String? scheduleDays;
  final int doneThreshold;
  final int? skipThreshold;
  final int? slipThreshold;
}

class _LogResult {
  const _LogResult(this.status, this.value);

  final LogStatus status;
  final double value;
}
