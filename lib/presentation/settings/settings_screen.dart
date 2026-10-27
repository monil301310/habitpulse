import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers/clock_providers.dart';
import '../../app/providers/cloud_providers.dart';
import '../../app/providers/demo_providers.dart';
import '../../app/providers/habit_providers.dart';
import '../../app/providers/log_providers.dart';
import '../../app/providers/notification_providers.dart';
import '../../app/providers/reminder_providers.dart';
import '../../app/providers/settings_providers.dart';
import '../../app/providers/theme_mode_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/platform/windows_shell.dart';
import '../../data/remote/cloud_runtime.dart';
import '../../data/services/export_service.dart';
import '../../data/services/notification_content.dart';
import '../../data/services/notification_service.dart';
import '../../data/sync/sync_controller.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_log.dart';
import '../../domain/entities/habit_reminder.dart';
import '../../domain/enums/habit_type.dart';
import '../../domain/models/local_day.dart';
import '../auth/auth_screen.dart';
import 'notification_setup_screen.dart';

/// Phase 1 settings surface.
///
/// Theme selection and a live database status are here so the foundation can be
/// exercised end-to-end; the full settings screen (rollover, quiet hours,
/// account, export) arrives in later phases.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    final habitsAsync = ref.watch(habitsProvider);
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults();
    final runtime = ref.watch(cloudRuntimeProvider);
    final user = ref.watch(currentUserProvider);
    final syncController = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _SectionCard(
              title: 'Appearance',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Dark is the default. System follows your device setting.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                      ],
                      selected: {mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) => ref
                          .read(themeModeProvider.notifier)
                          .setMode(selection.first),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Local data',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storage_rounded),
                    title: const Text('Local database'),
                    subtitle: Text(
                      'Drift (SQLite) · schema v${AppConstants.schemaVersion}',
                    ),
                    trailing: habitsAsync.maybeWhen(
                      data: (habits) => Text(
                        '${habits.length} '
                        '${habits.length == 1 ? 'habit' : 'habits'}',
                      ),
                      orElse: () => const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      runtime.configured
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                    ),
                    title: const Text('Cloud sync'),
                    subtitle: Text(
                      !runtime.configured
                          ? 'Local-only — add Supabase keys to .env'
                          : user == null
                          ? 'Available — sign in above'
                          : 'Signed in as ${user.email ?? 'your account'}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Data',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_rounded),
                    title: const Text('Export as JSON'),
                    subtitle: const Text(
                      'Habits, reminders, logs and settings',
                    ),
                    onTap: () => _export(context, ref, asJson: true),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.table_view_rounded),
                    title: const Text('Export as CSV'),
                    subtitle: const Text('One row per logged day'),
                    onTap: () => _export(context, ref, asJson: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Account',
              child: _accountSection(
                context,
                ref,
                runtime,
                user,
                syncController,
              ),
            ),
            const SizedBox(height: 16),
            if (WindowsShell.isActive) ...[
              _SectionCard(
                title: 'Windows',
                child: Column(
                  children: [
                    const _StartWithWindowsTile(),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.close_fullscreen_rounded),
                      title: const Text('Close to tray'),
                      subtitle: Text(
                        WindowsShell.trayAvailable
                            ? 'Closing the window keeps HabitPulse running. '
                                  'Quit from the tray menu.'
                            : 'The tray icon is unavailable on this system.',
                      ),
                    ),
                    const Divider(height: 1),
                    const _ShortcutTile(
                      shortcut: 'Ctrl + N',
                      action: 'New habit',
                    ),
                    const _ShortcutTile(
                      shortcut: 'Ctrl + 1 / 2 / 3',
                      action: 'Today / Insights / Settings',
                    ),
                    const _ShortcutTile(
                      shortcut: 'Ctrl + ,',
                      action: 'Settings',
                    ),
                    const _ShortcutTile(
                      shortcut: 'Esc',
                      action: 'Back',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _SectionCard(
              title: 'Notifications',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.nightlight_round),
                    title: const Text('Quiet hours'),
                    subtitle: Text(settings.quietHours),
                    onTap: () => _editQuietHours(context, ref, settings),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.replay_rounded),
                    title: const Text('Daily recheck'),
                    subtitle: Text(settings.recheckTime),
                    onTap: () => _pickRecheckTime(context, ref, settings),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.wb_twilight_rounded),
                    title: const Text('Morning recheck'),
                    subtitle: Text(
                      settings.morningRecheckTime == null
                          ? 'Off'
                          : settings.morningRecheckTime!,
                    ),
                    value: settings.morningRecheckTime != null,
                    onChanged: (enabled) =>
                        _toggleMorningRecheck(context, ref, settings, enabled),
                  ),
                  if (settings.morningRecheckTime != null) ...[
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_rounded),
                      title: const Text('Morning recheck time'),
                      subtitle: Text(settings.morningRecheckTime!),
                      onTap: () =>
                          _pickMorningTime(context, ref, settings),
                    ),
                  ],
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.volume_up_rounded),
                    title: const Text('Notification sound'),
                    value: settings.notificationSound,
                    onChanged: (enabled) =>
                        _setNotificationSound(ref, settings, enabled),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notification_important_rounded),
                    title: const Text('Notification setup'),
                    subtitle: const Text(
                      'Permissions, exact alarms & battery',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationSetupScreen(),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_active_rounded),
                    title: const Text('Send test notification'),
                    onTap: () => _testNotification(context, ref, settings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'About',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bolt_rounded),
                    title: const Text(AppConstants.appName),
                    subtitle: const Text('Phase 3 · Heatmap & insights'),
                  ),
                  const Divider(),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('Version'),
                    subtitle: Text('1.0.0 (build 1)'),
                  ),
                ],
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Developer',
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.auto_awesome_rounded),
                      title: const Text('Seed 3 years of demo data'),
                      subtitle: const Text(
                        'Five habits with about 1,000 days of history',
                      ),
                      onTap: () => _seedDemo(context, ref),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_sweep_rounded),
                      title: const Text('Delete demo data'),
                      onTap: () => _clearDemo(context, ref),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notification_add_rounded),
                      title: const Text('Run notification test'),
                      subtitle: const Text(
                        'Creates a test habit and shows a reminder with actions',
                      ),
                      onTap: () => _runNotificationTest(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _seedDemo(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final today = ref.read(effectiveTodayProvider);
    await ref.read(demoDataServiceProvider).seed(today: today);
    messenger.showSnackBar(
      const SnackBar(content: Text('Three years of demo data seeded.')),
    );
  }

  Future<void> _clearDemo(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(demoDataServiceProvider).clear();
    messenger.showSnackBar(
      const SnackBar(content: Text('Demo data removed.')),
    );
  }

  /// Debug helper: creates a habit and schedules a real reminder one minute
  /// out, so the notification actions can be checked with the app closed.
  Future<void> _runNotificationTest(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now().toUtc();
    final today = ref.read(effectiveTodayProvider);
    final service = ref.read(notificationServiceProvider);

    // A fresh install needs POST_NOTIFICATIONS before anything can appear.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final enabled = await service.notificationsEnabled();
      if (!enabled) {
        final granted = await service.requestPermissions();
        if (!granted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Notifications are blocked. Allow them in Settings → '
                'Notification setup, then try again.',
              ),
            ),
          );
          return;
        }
      }
    }

    final habit = Habit(
      id: const Uuid().v4(),
      userId: 'local',
      name: 'Notification test',
      icon: 'bolt',
      colour: '#4ADE80',
      type: HabitType.yesNo,
      startDate: today,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(habitRepositoryProvider).saveHabit(habit);

    // Let the debounced notification rebuild finish first; otherwise its
    // cancel-all would remove the test notification.
    await Future<void>.delayed(const Duration(seconds: 3));

    final settings =
        ref.read(appSettingsProvider).value ?? AppSettings.defaults();
    await service.showNow(
      NotificationRequest(
        id: 999003,
        title: habit.name,
        body: 'Tap Done in this notification to complete it',
        when: DateTime.now(),
        payload: reminderPayload(
          habitId: habit.id,
          date: today.toIso(),
        ),
        actions: reminderActionsFor(habit),
        playSound: settings.notificationSound,
      ),
    );

    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Test notification shown. Open the shade and tap Done, with the '
          'app in the background.',
        ),
      ),
    );
  }

  Widget _accountSection(
    BuildContext context,
    WidgetRef ref,
    CloudRuntime runtime,
    User? user,
    SyncController controller,
  ) {
    final theme = Theme.of(context);

    if (!runtime.configured) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.cloud_off_rounded),
        title: const Text('Cloud sync not set up'),
        subtitle: const Text(
          'Add Supabase keys to .env — see SETUP_SUPABASE.md',
        ),
        onTap: () => _showCloudSetupHelp(context),
      );
    }

    if (runtime.error != null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error),
        title: const Text('Cloud unavailable'),
        subtitle: Text(runtime.error!),
      );
    }

    if (user == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.login_rounded),
        title: const Text('Sign in to sync'),
        subtitle: const Text('Email, magic link or Google'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
        ),
      );
    }

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_rounded),
          title: Text(user.email ?? 'Signed in'),
          subtitle: const Text('Cloud sync is on'),
        ),
        ValueListenableBuilder<SyncStatus>(
          valueListenable: controller.status,
          builder: (context, status, _) {
            final text = status.syncing
                ? 'Syncing…'
                : status.error != null
                ? 'Sync error: ${status.error}'
                : status.lastSyncedAt != null
                ? 'Synced '
                      '${TimeOfDay.fromDateTime(status.lastSyncedAt!.toLocal()).format(context)}'
                : 'Waiting for the first sync';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sync_rounded),
              title: const Text('Sync status'),
              subtitle: Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: status.syncing ? null : controller.syncNow,
                child: const Text('Sync now'),
              ),
            );
          },
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Sign out'),
          subtitle: const Text('Clears local data after confirmation'),
          onTap: () => _signOut(context, ref),
        ),
      ],
    );
  }

  void _showCloudSetupHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cloud sync setup'),
        content: const Text(
          '1. Create a Supabase project.\n'
          '2. Run supabase/schema.sql in the SQL editor.\n'
          '3. Enable Email and Google providers.\n'
          '4. Copy the project URL and anon key into .env.\n'
          '5. Restart the app. Full steps are in SETUP_SUPABASE.md.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'The local database will be cleared. Make sure everything has '
          'synced first. Cloud data stays in your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final sync = ref.read(syncServiceProvider);
    final controller = ref.read(syncControllerProvider);
    await ref.read(authServiceProvider)?.signOut();
    await sync?.clearLocalData();
    await ref.read(notificationServiceProvider).cancelAll();
    controller.reset();
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref, {
    required bool asJson,
  }) async {
    final habits = ref.read(habitsProvider).value ?? const <Habit>[];
    final logs = ref.read(allLogsProvider).value ?? const <HabitLog>[];
    final reminders =
        ref.read(remindersProvider).value ?? const <HabitReminder>[];
    final settings =
        ref.read(appSettingsProvider).value ?? AppSettings.defaults();
    final service = ExportService();

    try {
      final result = asJson
          ? await service.exportJson(
              habits: habits,
              logs: logs,
              reminders: reminders,
              settings: settings,
            )
          : await service.exportCsv(habits: habits, logs: logs);

      if (!context.mounted) return;
      if (Platform.isAndroid) await service.share(result);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to ${result.path}'),
          action: Platform.isWindows
              ? SnackBarAction(
                  label: 'Show',
                  onPressed: () => service.reveal(result),
                )
              : null,
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    }
  }

  Future<void> _saveSettings(WidgetRef ref, AppSettings settings) {    return ref
        .read(settingsRepositoryProvider)
        .save(settings.copyWith(updatedAt: DateTime.now().toUtc()));
  }

  Future<TimeOfDay?> _pickTime(
    BuildContext context,
    TimeOfDay initial,
    String help,
  ) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      helpText: help,
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _parseTimeOfDay(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  (DayTime, DayTime) _parseQuietHours(String value) {
    try {
      final parts = value.split('-');
      return (DayTime.parse(parts[0].trim()), DayTime.parse(parts[1].trim()));
    } on Object {
      return (const DayTime(23, 0), const DayTime(7, 0));
    }
  }

  Future<void> _editQuietHours(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final (start, end) = _parseQuietHours(settings.quietHours);

    final newStart = await _pickTime(
      context,
      TimeOfDay(hour: start.hour, minute: start.minute),
      'Quiet hours start',
    );
    if (newStart == null) return;
    if (!context.mounted) return;

    final newEnd = await _pickTime(
      context,
      TimeOfDay(hour: end.hour, minute: end.minute),
      'Quiet hours end',
    );
    if (newEnd == null) return;

    await _saveSettings(
      ref,
      settings.copyWith(
        quietHours: '${_formatTime(newStart)}-${_formatTime(newEnd)}',
      ),
    );
  }

  Future<void> _pickRecheckTime(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final current = _parseTimeOfDay(
      settings.recheckTime,
      const TimeOfDay(hour: 21, minute: 30),
    );
    final picked = await _pickTime(context, current, 'Daily recheck time');
    if (picked == null) return;
    await _saveSettings(
      ref,
      settings.copyWith(recheckTime: _formatTime(picked)),
    );
  }

  Future<void> _pickMorningTime(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final current = _parseTimeOfDay(
      settings.morningRecheckTime ?? '08:00',
      const TimeOfDay(hour: 8, minute: 0),
    );
    final picked = await _pickTime(context, current, 'Morning recheck time');
    if (picked == null) return;
    await _saveSettings(
      ref,
      settings.copyWith(morningRecheckTime: _formatTime(picked)),
    );
  }

  Future<void> _toggleMorningRecheck(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    bool enabled,
  ) async {
    if (!enabled) {
      await _saveSettings(
        ref,
        settings.copyWith(clearMorningRecheck: true),
      );
      return;
    }

    final picked = await _pickTime(
      context,
      const TimeOfDay(hour: 8, minute: 0),
      'Morning recheck time',
    );
    if (picked == null) return;
    await _saveSettings(
      ref,
      settings.copyWith(morningRecheckTime: _formatTime(picked)),
    );
  }

  Future<void> _setNotificationSound(
    WidgetRef ref,
    AppSettings settings,
    bool enabled,
  ) {
    return _saveSettings(
      ref,
      settings.copyWith(notificationSound: enabled),
    );
  }

  Future<void> _testNotification(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(notificationServiceProvider);

    if (defaultTargetPlatform == TargetPlatform.android) {
      final enabled = await service.notificationsEnabled();
      if (!enabled) {
        final granted = await service.requestPermissions();
        if (!granted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Allow notifications first.')),
          );
          return;
        }
      }
    }

    await service.showNow(
      NotificationRequest(
        id: 999001,
        title: 'HabitPulse test reminder',
        body: 'Reminders are working on this device.',
        when: DateTime.now(),
        payload: recheckPayload(
          date: ref.read(effectiveTodayProvider).toIso(),
        ),
        actions: const [
          NotificationActionSpec(id: actionOpen, title: 'Open'),
        ],
        playSound: settings.notificationSound,
      ),
    );

    messenger.showSnackBar(
      const SnackBar(content: Text('Test notification sent.')),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StartWithWindowsTile extends StatefulWidget {
  const _StartWithWindowsTile();

  @override
  State<_StartWithWindowsTile> createState() => _StartWithWindowsTileState();
}

class _StartWithWindowsTileState extends State<_StartWithWindowsTile> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await LaunchAtStartup.instance.isEnabled();
      if (mounted) setState(() => _enabled = value);
    } on Object {
      if (mounted) setState(() => _enabled = false);
    }
  }

  Future<void> _set(bool value) async {
    final previous = _enabled;
    setState(() => _enabled = value);
    try {
      final changed = value
          ? await LaunchAtStartup.instance.enable()
          : await LaunchAtStartup.instance.disable();
      if (!changed) throw StateError('Windows rejected the change');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _enabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update startup: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.rocket_launch_outlined),
      title: const Text('Start with Windows'),
      subtitle: const Text('Open HabitPulse when you sign in'),
      value: _enabled ?? false,
      onChanged: _enabled == null ? null : _set,
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.shortcut, required this.action});

  final String shortcut;
  final String action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(action),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          shortcut,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
