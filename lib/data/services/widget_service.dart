import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/enums/log_status.dart';
import '../../domain/logic/day_rollover.dart';
import '../../domain/models/local_day.dart';
import '../../domain/widgets/widget_payload.dart';
import '../../presentation/widgets/widget_heatmap_preview.dart';
import '../database/app_database.dart';
import '../repositories/drift_habit_repository.dart';
import '../repositories/drift_log_repository.dart';
import '../repositories/drift_settings_repository.dart';
import 'habit_log_service.dart';

/// Pushes data to the two Android home-screen widgets.
class WidgetService {
  static const String checklistWidget = 'HabitPulseChecklistWidgetProvider';
  static const String heatmapWidget = 'HabitPulseHeatmapWidgetProvider';

  static const String _package = 'com.habitpulse.habitpulse';

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> update({
    required List<Habit> habits,
    required Map<String, Map<LocalDay, HabitLog>> logsByHabit,
    required LocalDay today,
    required int weekStart,
  }) async {
    if (!isSupported) return;

    await updateChecklistOnly(
      habits: habits,
      logsByHabit: logsByHabit,
      today: today,
    );
    await _updateHeatmap(
      habits: habits,
      logsByHabit: logsByHabit,
      today: today,
      weekStart: weekStart,
    );
  }

  Future<void> updateChecklistOnly({
    required List<Habit> habits,
    required Map<String, Map<LocalDay, HabitLog>> logsByHabit,
    required LocalDay today,
  }) async {
    if (!isSupported) return;

    final payload = buildWidgetChecklistPayload(
      habits: habits,
      logsByHabit: logsByHabit,
      today: today,
    );

    await HomeWidget.saveWidgetData<String>(
      'checklist_json',
      jsonEncode(payload.toJson()),
    );
    await HomeWidget.updateWidget(
      androidName: checklistWidget,
      qualifiedAndroidName: '$_package.$checklistWidget',
    );
  }

  Future<void> _updateHeatmap({
    required List<Habit> habits,
    required Map<String, Map<LocalDay, HabitLog>> logsByHabit,
    required LocalDay today,
    required int weekStart,
  }) async {
    if (habits.isEmpty) return;
    final habit = habits.first;

    await HomeWidget.renderFlutterWidget(
      WidgetHeatmapPreview(
        habit: habit,
        logs: logsByHabit[habit.id] ?? const <LocalDay, HabitLog>{},
        today: today,
        weekStart: weekStart,
      ),
      key: 'heatmap_image',
      logicalSize: const Size(300, 160),
      pixelRatio: 2,
    );
    await HomeWidget.saveWidgetData<String>('heatmap_habit_id', habit.id);
    await HomeWidget.updateWidget(
      androidName: heatmapWidget,
      qualifiedAndroidName: '$_package.$heatmapWidget',
    );
  }
}

/// Android background entry point for checklist row taps.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;

  DartPluginRegistrant.ensureInitialized();

  final habitId = uri.queryParameters['habitId'];
  final day = LocalDay.tryParse(uri.queryParameters['date']);
  if (habitId == null || day == null) return;

  final database = AppDatabase.defaults();
  try {
    final habit = await DriftHabitRepository(database).getHabit(habitId);
    if (habit == null) return;

    final logs = HabitLogService(DriftLogRepository(database));
    final existing = await logs.logFor(habit, day);
    if (existing?.status == LogStatus.done) {
      await logs.clear(habit, day);
    } else {
      await logs.markDone(habit, day);
    }

    final allHabits = await DriftHabitRepository(
      database,
    ).watchHabits().first;
    final allLogs = await DriftLogRepository(database).watchAllLogs().first;
    final byHabit = <String, Map<LocalDay, HabitLog>>{};
    for (final log in allLogs) {
      (byHabit[log.habitId] ??= <LocalDay, HabitLog>{})[log.date] = log;
    }

    await WidgetService().updateChecklistOnly(
      habits: allHabits,
      logsByHabit: byHabit,
      today: day,
    );
  } on Object catch (error) {
    debugPrint('Widget action failed: $error');
  } finally {
    await database.close();
  }
}

/// Resolves the effective day from stored settings (used by background taps).
Future<LocalDay> effectiveDayFor(AppDatabase database) async {
  final settings = await DriftSettingsRepository(database).load();
  return resolveEffectiveDay(
    DateTime.now(),
    DayTime.parse(settings.dayRolloverTime),
  );
}
