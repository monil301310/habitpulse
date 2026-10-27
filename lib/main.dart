import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'app/app.dart';
import 'app/notification_navigation.dart';
import 'app/providers/cloud_providers.dart';
import 'app/providers/notification_providers.dart';
import 'core/config/supabase_config.dart';
import 'core/platform/windows_shell.dart';
import 'data/remote/cloud_runtime.dart';
import 'data/services/notification_action_handler.dart';
import 'data/services/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cloud is optional: without keys the app stays in local-only mode.
  final supabaseConfig = await SupabaseConfig.load();
  final cloudRuntime = await CloudRuntime.initialize(supabaseConfig);

  // Created before runApp so notification responses can update the same
  // database connection the UI watches.
  final container = ProviderContainer(
    overrides: [cloudRuntimeProvider.overrideWithValue(cloudRuntime)],
  );

  await sharedNotificationService.initialize(
    onForeground: (response) async {
      await applyForegroundNotificationAction(container, response);
      pendingNotificationResponse.value = response;
    },
    onBackground: notificationBackgroundHandler,
  );

  // Widget checklist taps run this callback in a background isolate.
  if (WidgetService.isSupported) {
    try {
      await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    } on Object catch (error) {
      debugPrint('Could not register the widget callback: $error');
    }
  }

  // Desktop window, tray and start-with-Windows integration.
  try {
    await WindowsShell.initialize();
  } on Object catch (error) {
    debugPrint('Windows shell setup failed: $error');
  }

  // A notification may have launched the app (Windows buttons, or a tap while
  // the app was terminated). Apply any action before the UI starts.
  try {
    final launch = await sharedNotificationService.launchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final response = launch!.notificationResponse;
      if (response != null) {
        await applyForegroundNotificationAction(container, response);
        pendingNotificationResponse.value = response;
      }
    }
  } on Object catch (error) {
    debugPrint('Could not read notification launch details: $error');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HabitPulseApp(),
    ),
  );
}
