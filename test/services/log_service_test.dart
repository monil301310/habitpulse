import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/data/services/habit_log_service.dart';
import 'package:habitpulse/domain/entities/habit_log.dart';
import 'package:habitpulse/domain/enums/habit_type.dart';
import 'package:habitpulse/domain/enums/log_status.dart';
import 'package:habitpulse/domain/models/local_day.dart';
import 'package:habitpulse/domain/repositories/log_repository.dart';

import '../support/fixtures.dart';

/// Minimal in-memory log store for service tests.
class _InMemoryLogRepository implements LogRepository {
  final Map<String, HabitLog> _logs = {};

  @override
  Future<HabitLog?> findLog(String habitId, LocalDay day) async {
    for (final log in _logs.values) {
      if (log.habitId == habitId && log.date == day && log.deletedAt == null) {
        return log;
      }
    }
    return null;
  }

  @override
  Future<void> saveLog(HabitLog log) async => _logs[log.id] = log;

  @override
  Future<void> deleteLog(String id) async {
    final log = _logs[id];
    if (log != null) {
      _logs[id] = HabitLog(
        id: log.id,
        habitId: log.habitId,
        date: log.date,
        value: log.value,
        status: log.status,
        note: log.note,
        updatedAt: log.updatedAt,
        deletedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Stream<List<HabitLog>> watchAllLogs() => const Stream.empty();

  @override
  Stream<Map<LocalDay, HabitLog>> watchLogsByDay(String habitId) =>
      const Stream.empty();
}

void main() {
  const day = LocalDay(2026, 10, 25);

  late _InMemoryLogRepository repository;
  late HabitLogService service;

  setUp(() {
    repository = _InMemoryLogRepository();
    service = HabitLogService(repository);
  });

  test('markDone completes a yes/no habit', () async {
    final habit = testHabit();

    await service.markDone(habit, day);
    final log = await repository.findLog(habit.id, day);

    expect(log, isNotNull);
    expect(log!.status, LogStatus.done);
  });

  test('markDone jumps count and timed habits to their target', () async {
    final count = testHabit(type: HabitType.count, targetValue: 8);
    final timed = testHabit(id: 'h2', type: HabitType.timed, targetValue: 30);

    await service.markDone(count, day);
    await service.markDone(timed, day);

    expect((await repository.findLog(count.id, day))!.value, 8);
    expect((await repository.findLog(count.id, day))!.status, LogStatus.done);
    expect((await repository.findLog(timed.id, day))!.value, 30);
  });

  test('addValue stays partial below the target and completes at it', () async {
    final habit = testHabit(type: HabitType.count, targetValue: 3);

    await service.addValue(habit, day, 1);
    var log = await repository.findLog(habit.id, day);
    expect(log!.value, 1);
    expect(log.status, LogStatus.partial);

    await service.addValue(habit, day, 1);
    log = await repository.findLog(habit.id, day);
    expect(log!.value, 2);
    expect(log.status, LogStatus.partial);

    await service.addValue(habit, day, 1);
    log = await repository.findLog(habit.id, day);
    expect(log!.value, 3);
    expect(log.status, LogStatus.done);
  });

  test('addValue never goes below zero', () async {
    final habit = testHabit(type: HabitType.count, targetValue: 8);

    await service.addValue(habit, day, -5);

    expect((await repository.findLog(habit.id, day))!.value, 0);
  });

  test('updating an existing log reuses its id', () async {
    final habit = testHabit(type: HabitType.count, targetValue: 8);

    await service.setValue(habit, day, 2);
    final first = await repository.findLog(habit.id, day);
    await service.setValue(habit, day, 6);
    final second = await repository.findLog(habit.id, day);

    expect(second!.id, first!.id);
    expect(second.value, 6);
    expect(repository._logs.length, 1);
  });

  test('setValue marks done exactly at the target and partial below it', () async {
    final habit = testHabit(type: HabitType.timed, targetValue: 30);

    await service.setValue(habit, day, 29);
    expect((await repository.findLog(habit.id, day))!.status, LogStatus.partial);

    await service.setValue(habit, day, 30);
    expect((await repository.findLog(habit.id, day))!.status, LogStatus.done);
  });

  test('skip, miss and slip record the right statuses', () async {
    final habit = testHabit(type: HabitType.negative);

    await service.skip(habit, day);
    expect((await repository.findLog(habit.id, day))!.status, LogStatus.skipped);

    await service.markMissed(habit, day);
    expect((await repository.findLog(habit.id, day))!.status, LogStatus.missed);

    await service.markSlipped(habit, day);
    expect((await repository.findLog(habit.id, day))!.status, LogStatus.slipped);

    await service.confirmAvoided(habit, day);
    expect((await repository.findLog(habit.id, day))!.status, LogStatus.done);
  });

  test('clear removes the active log for the day', () async {
    final habit = testHabit();

    await service.markDone(habit, day);
    await service.clear(habit, day);

    expect(await repository.findLog(habit.id, day), isNull);
  });

  test('setNote saves and clears a note on an existing log', () async {
    final habit = testHabit();

    await service.markDone(habit, day);
    await service.setNote(habit, day, '  Tough day  ');
    expect((await repository.findLog(habit.id, day))!.note, 'Tough day');

    await service.setNote(habit, day, '   ');
    expect((await repository.findLog(habit.id, day))!.note, isNull);
  });

  test('setNote does nothing when the day has no log', () async {
    final habit = testHabit();

    await service.setNote(habit, day, 'A note');

    expect(await repository.findLog(habit.id, day), isNull);
  });
}
