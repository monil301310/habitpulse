import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../data/services/widget_service.dart';
import '../domain/entities/habit_log.dart';
import '../domain/models/local_day.dart';
import '../presentation/habits/habit_detail_screen.dart';
import 'notification_navigation.dart';
import 'providers/clock_providers.dart';
import 'providers/habit_providers.dart';
import 'providers/log_providers.dart';
import 'providers/reminder_providers.dart';
import 'providers/settings_providers.dart';
import 'providers/widget_providers.dart';

/// Keeps the Android widgets up to date and routes widget taps into the app.
class WidgetSync extends ConsumerStatefulWidget {
  const WidgetSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WidgetSync> createState() => _WidgetSyncState();
}

class _WidgetSyncState extends ConsumerState<WidgetSync>
    with WidgetsBindingObserver {
  Timer? _debounce;
  StreamSubscription<Uri?>? _clicks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _update();
      if (!WidgetService.isSupported) return;
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initial != null) _handleUri(initial);
    });

    if (WidgetService.isSupported) {
      _clicks = HomeWidget.widgetClicked.listen(_handleUri);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _clicks?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // Background writes (widget taps, notification actions) use their own
    // database connection, so re-subscribe the streams to pick them up.
    ref.invalidate(habitsProvider);
    ref.invalidate(allLogsProvider);
    ref.invalidate(remindersProvider);
    ref.invalidate(appSettingsProvider);
    _schedule();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(habitsProvider, (_, _) => _schedule());
    ref.listen(allLogsProvider, (_, _) => _schedule());
    return widget.child;
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _update);
  }

  Future<void> _update() async {
    final habits = ref.read(habitsProvider).value;
    final logs = ref.read(allLogsProvider).value;
    if (habits == null || logs == null) return;

    final byHabit = <String, Map<LocalDay, HabitLog>>{};
    for (final log in logs) {
      (byHabit[log.habitId] ??= <LocalDay, HabitLog>{})[log.date] = log;
    }

    try {
      await ref.read(widgetServiceProvider).update(
        habits: habits,
        logsByHabit: byHabit,
        today: ref.read(effectiveTodayProvider),
        weekStart: ref.read(weekStartProvider),
      );
    } on Object catch (error) {
      debugPrint('Widget update failed: $error');
    }
  }

  void _handleUri(Uri? uri) {
    if (uri == null || uri.host != 'habit') return;
    final habitId = uri.queryParameters['habitId'];
    if (habitId == null || habitId.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => HabitDetailScreen(habitId: habitId),
        ),
      );
    });
  }
}
