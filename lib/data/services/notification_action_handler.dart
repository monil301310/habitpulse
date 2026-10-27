import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/clock_providers.dart';
import '../../app/providers/habit_providers.dart';
import '../../app/providers/log_providers.dart';
import '../../app/providers/notification_providers.dart';
import '../../app/providers/settings_providers.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/habit.dart';
import '../../domain/logic/day_rollover.dart';
import '../../domain/models/local_day.dart';
import '../database/app_database.dart';
import '../repositories/drift_habit_repository.dart';
import '../repositories/drift_log_repository.dart';
import '../repositories/drift_settings_repository.dart';
import 'habit_log_service.dart';
import 'notification_content.dart';
import 'notification_service.dart';

/// Applies a notification action from the app's own providers.
///
/// Used when the app is running (Android foreground actions and Windows toast
/// buttons). Going through the same database connection as the UI means the
/// habit card updates immediately.
Future<void> applyForegroundNotificationAction(
  ProviderContainer container,
  NotificationResponse response,
) async {
  final parsed = _parse(response);
  if (parsed == null || !parsed.isActionable) return;

  final habit = await container
      .read(habitRepositoryProvider)
      .getHabit(parsed.habitId!);
  if (habit == null) return;

  final settings =
      container.read(appSettingsProvider).value ?? AppSettings.defaults();
  final LocalDay day =
      parsed.date ?? container.read<LocalDay>(effectiveTodayProvider);

  await _apply(
    action: parsed.action,
    habit: habit,
    day: day,
    settings: settings,
    logs: container.read(logServiceProvider),
    schedule: (request) =>
        container.read(notificationServiceProvider).schedule(request),
  );
}

/// Applies a notification action in a background isolate (Android).
Future<void> applyNotificationAction(NotificationResponse response) async {
  final parsed = _parse(response);
  if (parsed == null || !parsed.isActionable) return;

  final database = AppDatabase.defaults();
  try {
    final habit = await DriftHabitRepository(
      database,
    ).getHabit(parsed.habitId!);
    if (habit == null) return;

    final settings = await DriftSettingsRepository(database).load();
    final today = resolveEffectiveDay(
      DateTime.now(),
      DayTime.parse(settings.dayRolloverTime),
    );

    await _apply(
      action: parsed.action,
      habit: habit,
      day: parsed.date ?? today,
      settings: settings,
      logs: HabitLogService(DriftLogRepository(database)),
      schedule: (request) async {
        final notifications = NotificationService();
        await notifications.initialize();
        await notifications.schedule(request);
      },
    );
  } finally {
    await database.close();
  }
}

Future<void> _apply({
  required String action,
  required Habit habit,
  required LocalDay day,
  required AppSettings settings,
  required HabitLogService logs,
  required Future<void> Function(NotificationRequest request) schedule,
}) async {
  switch (action) {
    case actionDone:
      await logs.markDone(habit, day);
    case actionSkip:
      await logs.skip(habit, day);
    case actionSlip:
      await logs.markSlipped(habit, day);
    case actionIncrement:
      await logs.addValue(habit, day, 1);
    case actionSnooze10:
    case actionSnooze60:
      await schedule(
        NotificationRequest(
          id: _snoozeId(habit.id, DateTime.now()),
          title: habit.name,
          body: 'Snoozed reminder',
          when: DateTime.now().add(
            Duration(minutes: action == actionSnooze60 ? 60 : 10),
          ),
          payload: reminderPayload(habitId: habit.id, date: day.toIso()),
          actions: reminderActionsFor(habit),
          playSound: settings.notificationSound,
        ),
      );
  }
}

class _ParsedAction {
  const _ParsedAction({
    required this.action,
    required this.type,
    this.habitId,
    this.date,
  });

  final String action;
  final String type;
  final String? habitId;
  final LocalDay? date;

  bool get isActionable =>
      action.isNotEmpty &&
      action != actionOpen &&
      type == 'reminder' &&
      habitId != null;
}

_ParsedAction? _parse(NotificationResponse response) {
  final rawPayload = response.payload;
  if (rawPayload == null || rawPayload.isEmpty) return null;

  var data = _decode(rawPayload);
  if (data == null) return null;

  var action = response.actionId ?? '';

  // Windows wraps the button action around the original notification payload.
  final wrappedAction = data['action'];
  if (wrappedAction is String && data['payload'] is String) {
    action = wrappedAction;
    data = _decode(data['payload'] as String) ?? data;
  }

  return _ParsedAction(
    action: action,
    type: data['type'] as String? ?? '',
    habitId: data['habitId'] as String?,
    date: LocalDay.tryParse(data['date'] as String?),
  );
}

Map<String, dynamic>? _decode(String raw) {
  try {
    final value = jsonDecode(raw);
    return value is Map<String, dynamic> ? value : null;
  } on Object {
    return null;
  }
}

int _snoozeId(String habitId, DateTime now) {
  final key = '$habitId|${now.millisecondsSinceEpoch}';
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  return hash;
}

/// Android background entry point for notification action buttons.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) async {
  debugPrint('Background notification entrypoint invoked');
  try {
    DartPluginRegistrant.ensureInitialized();
    await applyNotificationAction(response);
    debugPrint('Background notification action finished');
  } on Object catch (error, stackTrace) {
    debugPrint('Background notification action failed: $error\n$stackTrace');
  }
}
