import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/app/app.dart';
import 'package:habitpulse/app/providers/clock_providers.dart';
import 'package:habitpulse/app/providers/habit_providers.dart';
import 'package:habitpulse/app/providers/log_providers.dart';
import 'package:habitpulse/app/providers/reminder_providers.dart';
import 'package:habitpulse/app/providers/settings_providers.dart';
import 'package:habitpulse/domain/entities/app_settings.dart';
import 'package:habitpulse/domain/entities/habit.dart';
import 'package:habitpulse/domain/entities/habit_log.dart';
import 'package:habitpulse/domain/entities/habit_reminder.dart';
import 'package:habitpulse/domain/enums/habit_type.dart';
import 'package:habitpulse/domain/enums/log_status.dart';
import 'package:habitpulse/domain/models/local_day.dart';
import 'package:habitpulse/domain/repositories/habit_repository.dart';
import 'package:habitpulse/domain/repositories/log_repository.dart';

/// A repository that never touches the database, so widget tests stay fast and
/// platform-independent (no path_provider / SQLite plugin needed).
final class _FakeHabitRepository implements HabitRepository {
  _FakeHabitRepository([this._habits = const <Habit>[]]);

  final List<Habit> _habits;

  @override
  Stream<List<Habit>> watchHabits({bool includeArchived = false}) {
    return Stream<List<Habit>>.value(_habits);
  }

  @override
  Future<Habit?> getHabit(String id) async {
    for (final habit in _habits) {
      if (habit.id == id) return habit;
    }
    return null;
  }

  @override
  Future<void> saveHabit(Habit habit) async {}

  @override
  Future<void> setArchived(String id, {required bool archived}) async {}

  @override
  Future<void> deleteHabit(String id) async {}
}

final class _FakeLogRepository implements LogRepository {
  _FakeLogRepository([List<HabitLog> initial = const []])
    : _logs = {for (final log in initial) log.id: log};

  final Map<String, HabitLog> _logs;

  @override
  Stream<List<HabitLog>> watchAllLogs() {
    return Stream<List<HabitLog>>.value(_logs.values.toList());
  }

  @override
  Stream<Map<LocalDay, HabitLog>> watchLogsByDay(String habitId) {
    return Stream<Map<LocalDay, HabitLog>>.value(const {});
  }

  @override
  Future<HabitLog?> findLog(String habitId, LocalDay day) async => null;

  @override
  Future<void> saveLog(HabitLog log) async => _logs[log.id] = log;

  @override
  Future<void> deleteLog(String id) async => _logs.remove(id);
}

Widget _appWith({
  required HabitRepository habits,
  LogRepository? logs,
  LocalDay? today,
}) {
  return ProviderScope(
    overrides: [
      habitRepositoryProvider.overrideWithValue(habits),
      logRepositoryProvider.overrideWithValue(logs ?? _FakeLogRepository()),
      appSettingsProvider.overrideWith(
        (ref) => Stream<AppSettings>.value(AppSettings.defaults()),
      ),
      remindersProvider.overrideWith(
        (ref) => Stream<List<HabitReminder>>.value(const <HabitReminder>[]),
      ),
      if (today != null) effectiveTodayProvider.overrideWithValue(today),
    ],
    child: const HabitPulseApp(),
  );
}

void main() {
  testWidgets('renders the empty home screen', (tester) async {
    await tester.pumpWidget(_appWith(habits: _FakeHabitRepository()));
    await tester.pumpAndSettle();

    expect(find.text('HabitPulse'), findsOneWidget);
    expect(find.text('No habits yet'), findsOneWidget);
    expect(find.text('Add your first habit'), findsOneWidget);
  });

  testWidgets('defaults to dark theme and cycles to light', (tester) async {
    await tester.pumpWidget(_appWith(habits: _FakeHabitRepository()));
    await tester.pumpAndSettle();

    MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    await tester.tap(find.byTooltip('Switch theme'));
    await tester.pumpAndSettle();

    app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
  });

  testWidgets('settings screen shows database status', (tester) async {
    await tester.pumpWidget(_appWith(habits: _FakeHabitRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Local database'), findsOneWidget);
    expect(find.textContaining('schema v4'), findsOneWidget);
    expect(find.text('0 habits'), findsOneWidget);
  });

  testWidgets('habit card shows name, type and streak', (tester) async {
    const today = LocalDay(2026, 10, 25);
    final stamp = DateTime.utc(2026, 10, 25);

    final habit = Habit(
      id: 'h1',
      userId: 'local',
      name: 'Meditate',
      icon: 'meditate',
      colour: '#4ADE80',
      type: HabitType.yesNo,
      startDate: today.addDays(-2),
      createdAt: stamp,
      updatedAt: stamp,
    );

    final logs = [
      for (var i = 2; i >= 0; i--)
        HabitLog(
          id: 'l$i',
          habitId: 'h1',
          date: today.addDays(-i),
          status: LogStatus.done,
          updatedAt: stamp,
        ),
    ];

    await tester.pumpWidget(
      _appWith(
        habits: _FakeHabitRepository([habit]),
        logs: _FakeLogRepository(logs),
        today: today,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meditate'), findsOneWidget);
    expect(find.text('Done today'), findsOneWidget);
    expect(find.text('3d'), findsOneWidget);
    expect(find.text('No habits yet'), findsNothing);
  });

  testWidgets('count habit shows its value against the target', (tester) async {
    const today = LocalDay(2026, 10, 25);
    final stamp = DateTime.utc(2026, 10, 25);

    final habit = Habit(
      id: 'h2',
      userId: 'local',
      name: 'Drink water',
      icon: 'water',
      colour: '#22D3EE',
      type: HabitType.count,
      targetValue: 8,
      unit: 'glasses',
      startDate: today,
      createdAt: stamp,
      updatedAt: stamp,
    );

    final log = HabitLog(
      id: 'l1',
      habitId: 'h2',
      date: today,
      value: 5,
      status: LogStatus.partial,
      updatedAt: stamp,
    );

    await tester.pumpWidget(
      _appWith(
        habits: _FakeHabitRepository([habit]),
        logs: _FakeLogRepository([log]),
        today: today,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Drink water'), findsOneWidget);
    expect(find.text('5 / 8 glasses'), findsOneWidget);
  });

  testWidgets('Ctrl+2 switches to Insights', (tester) async {
    await tester.pumpWidget(_appWith(habits: _FakeHabitRepository()));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('No insights yet'), findsOneWidget);
  });

  testWidgets('phone layout uses bottom navigation', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_appWith(habits: _FakeHabitRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Pick a habit'), findsNothing);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('No insights yet'), findsOneWidget);
  });

  testWidgets('wide layout opens the habit detail in a side pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const today = LocalDay(2026, 10, 25);
    final stamp = DateTime.utc(2026, 10, 25);
    final habit = Habit(
      id: 'h1',
      userId: 'local',
      name: 'Meditate',
      icon: 'meditate',
      colour: '#4ADE80',
      type: HabitType.yesNo,
      startDate: today.addDays(-2),
      createdAt: stamp,
      updatedAt: stamp,
    );

    await tester.pumpWidget(
      _appWith(
        habits: _FakeHabitRepository([habit]),
        logs: _FakeLogRepository([
          HabitLog(
            id: 'l1',
            habitId: 'h1',
            date: today,
            status: LogStatus.done,
            updatedAt: stamp,
          ),
        ]),
        today: today,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pick a habit'), findsOneWidget);

    await tester.tap(find.text('Meditate'));
    await tester.pumpAndSettle();

    // Still on Today: the detail replaced the placeholder inside the pane.
    expect(find.text('Pick a habit'), findsNothing);
    expect(find.text('Current streak'), findsOneWidget);
  });
}
