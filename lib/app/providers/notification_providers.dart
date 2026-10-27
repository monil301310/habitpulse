import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/notification_coordinator.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/reminder_scheduler.dart';

/// One shared, initialized notification plugin instance.
///
/// `main()` initializes this instance before `runApp`, so the scheduler and UI
/// use the same plugin.
final NotificationService sharedNotificationService = NotificationService();

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return sharedNotificationService;
});

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return ReminderScheduler(ref.watch(notificationServiceProvider));
});

final notificationCoordinatorProvider = Provider<NotificationCoordinator>((
  ref,
) {
  final coordinator = NotificationCoordinator();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
