import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../presentation/shell/app_shell.dart';
import 'app_shortcuts.dart';
import 'cloud_sync_scope.dart';
import 'notification_navigation.dart';
import 'notification_sync.dart';
import 'providers/theme_mode_provider.dart';
import 'theme/app_theme.dart';
import 'widget_sync.dart';

/// Root of the HabitPulse app.
class HabitPulseApp extends ConsumerWidget {
  const HabitPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: AppShortcuts(
        child: WidgetSync(
          child: NotificationSync(
            child: CloudSyncScope(
              child: NotificationNavigation(child: const AppShell()),
            ),
          ),
        ),
      ),
    );
  }
}
