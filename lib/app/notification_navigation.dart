import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/models/local_day.dart';
import '../presentation/habits/habit_detail_screen.dart';
import '../presentation/recheck/recheck_screen.dart';

/// The app navigator key, used to route notification taps from anywhere.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// The last notification response that still needs to be routed.
final ValueNotifier<NotificationResponse?> pendingNotificationResponse =
    ValueNotifier<NotificationResponse?>(null);

/// Routes a tapped notification to the recheck screen or a habit detail.
///
/// Action-button responses are not navigation events; their database write has
/// already happened in the background (or on launch).
class NotificationNavigation extends StatefulWidget {
  const NotificationNavigation({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationNavigation> createState() => _NotificationNavigationState();
}

class _NotificationNavigationState extends State<NotificationNavigation> {
  @override
  void initState() {
    super.initState();
    pendingNotificationResponse.addListener(_handle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pendingNotificationResponse.value != null) _handle();
    });
  }

  @override
  void dispose() {
    pendingNotificationResponse.removeListener(_handle);
    super.dispose();
  }

  void _handle() {
    final response = pendingNotificationResponse.value;
    if (response == null) return;

    // Consume so the same response is not routed twice.
    pendingNotificationResponse.value = null;

    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(payload);
      data = decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      return;
    }
    if (data == null) return;

    // Windows wraps the action id around the original payload; buttons are
    // handled without navigation.
    if (data['action'] is String && data['payload'] is String) return;

    final action = response.actionId ?? '';
    if (action.isNotEmpty && action != 'open') return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    switch (data['type']) {
      case 'recheck':
        final day = LocalDay.tryParse(data['date'] as String?);
        if (day == null) return;
        final morning = data['morning'] == true;
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => RecheckScreen(day: day, morning: morning),
          ),
        );
      case 'reminder':
        final habitId = data['habitId'] as String?;
        if (habitId == null) return;
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => HabitDetailScreen(habitId: habitId),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
