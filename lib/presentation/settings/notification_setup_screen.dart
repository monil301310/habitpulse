import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/clock_providers.dart';
import '../../app/providers/notification_providers.dart';
import '../../app/providers/settings_providers.dart';
import '../../app/theme/app_colors.dart';
import '../../data/services/notification_content.dart';
import '../../data/services/notification_service.dart';
import '../../domain/entities/app_settings.dart';

/// Guides the user through the permissions and battery settings reminders need.
///
/// Samsung One UI can silently stop background alarms, so this screen also
/// lists the exact battery steps for those devices.
class NotificationSetupScreen extends ConsumerStatefulWidget {
  const NotificationSetupScreen({super.key});

  @override
  ConsumerState<NotificationSetupScreen> createState() =>
      _NotificationSetupScreenState();
}

class _NotificationSetupScreenState
    extends ConsumerState<NotificationSetupScreen> {
  bool? _notificationsAllowed;
  bool? _exactAlarmsAllowed;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final service = ref.read(notificationServiceProvider);
    final allowed = await service.notificationsEnabled();
    final exact = await service.canScheduleExactAlarms();
    if (!mounted) return;
    setState(() {
      _notificationsAllowed = allowed;
      _exactAlarmsAllowed = exact;
    });
  }

  Future<void> _requestPermissions() async {
    await ref.read(notificationServiceProvider).requestPermissions();
    await _refresh();
  }

  Future<void> _testNotification() async {
    final service = ref.read(notificationServiceProvider);
    final settings =
        ref.read(appSettingsProvider).value ?? AppSettings.defaults();
    final messenger = ScaffoldMessenger.of(context);

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
      const SnackBar(content: Text('Test reminder sent.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification setup')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'HabitPulse schedules reminders locally on this device, so they '
              'work offline. Allow the permissions below to make sure they '
              'fire on time.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _StatusTile(
              icon: Icons.notifications_active_rounded,
              label: 'Notifications',
              description: 'Required for any reminder to appear.',
              allowed: _notificationsAllowed,
              onRequest: _requestPermissions,
            ),
            const SizedBox(height: 12),
            _StatusTile(
              icon: Icons.alarm_rounded,
              label: 'Exact alarms',
              description: 'Lets reminders fire at the exact minute.',
              allowed: _exactAlarmsAllowed,
              onRequest: _requestPermissions,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Samsung / One UI battery steps',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Samsung can stop background alarms. Open Settings and:\n'
                      '1. Battery → Background usage limits → remove HabitPulse '
                      'from Sleeping apps and Deep sleeping apps.\n'
                      '2. App info → Battery → choose Unrestricted.\n'
                      '3. Turn off “Put unused apps to sleep” for HabitPulse.\n\n'
                      'Then tap the test button below to confirm a reminder '
                      'arrives.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _testNotification,
              icon: const Icon(Icons.notifications_rounded),
              label: const Text('Send test reminder'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.allowed,
    required this.onRequest,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool? allowed;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAllowed = allowed == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isAllowed ? AppColors.green : theme.colorScheme.error)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isAllowed ? AppColors.green : theme.colorScheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  Text(description, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (allowed == null)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (isAllowed)
              const Icon(Icons.check_circle_rounded, color: AppColors.green)
            else
              TextButton(onPressed: onRequest, child: const Text('Allow')),
          ],
        ),
      ),
    );
  }
}
