import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// A button attached to a notification.
class NotificationActionSpec {
  const NotificationActionSpec({required this.id, required this.title});

  final String id;
  final String title;
}

/// A notification to show now or at a future time.
class NotificationRequest {
  const NotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    required this.payload,
    this.actions = const <NotificationActionSpec>[],
    this.playSound = true,
  });

  final int id;
  final String title;
  final String body;
  final DateTime when;
  final String payload;
  final List<NotificationActionSpec> actions;
  final bool playSound;
}

/// Thin wrapper around `flutter_local_notifications` for Android and Windows.
///
/// Scheduling is local and offline; no push server is involved.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String androidChannelId = 'habit_reminders';
  static const String _androidChannelName = 'Habit reminders';
  static const String _windowsAppName = 'HabitPulse';
  static const String _windowsAppUserModelId = 'com.habitpulse.habitpulse';
  static const String _windowsGuid = '6f1a8c9e-2b4d-4f7a-9c1e-8d3b5a7f2e64';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize({
    DidReceiveNotificationResponseCallback? onForeground,
    DidReceiveBackgroundNotificationResponseCallback? onBackground,
  }) async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object catch (error) {
      debugPrint('Could not resolve local timezone: $error');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const windows = WindowsInitializationSettings(
      appName: _windowsAppName,
      appUserModelId: _windowsAppUserModelId,
      guid: _windowsGuid,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, windows: windows),
      onDidReceiveNotificationResponse: onForeground,
      onDidReceiveBackgroundNotificationResponse: onBackground,
    );
    _initialized = true;
  }

  /// Requests notification permission and exact-alarm access on Android.
  ///
  /// Returns whether notifications are allowed.
  Future<bool> requestPermissions() async {
    if (!_isAndroid) return true;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    return granted ?? true;
  }

  Future<bool> notificationsEnabled() async {
    if (!_isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!_isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } on Object catch (error) {
      debugPrint('Could not cancel notifications: $error');
    }
  }

  /// Shows a notification immediately (used by the "Test reminder" button).
  Future<void> showNow(NotificationRequest request) async {
    if (!_initialized) return;
    await _plugin.show(
      id: request.id,
      title: request.title,
      body: request.body,
      notificationDetails: _details(request),
      payload: request.payload,
    );
  }

  /// Schedules a one-off notification at [NotificationRequest.when].
  ///
  /// Falls back to an inexact alarm if exact alarms are not permitted.
  Future<void> schedule(NotificationRequest request) async {
    if (!_initialized) return;

    final details = _details(request);
    final scheduledDate = tz.TZDateTime.from(request.when, tz.local);

    try {
      await _plugin.zonedSchedule(
        id: request.id,
        title: request.title,
        body: request.body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: request.payload,
      );
    } on Object catch (error) {
      debugPrint('Exact scheduling failed, retrying inexact: $error');
      await _plugin.zonedSchedule(
        id: request.id,
        title: request.title,
        body: request.body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: request.payload,
      );
    }
  }

  Future<NotificationAppLaunchDetails?> launchDetails() {
    return _plugin.getNotificationAppLaunchDetails();
  }

  NotificationDetails _details(NotificationRequest request) {
    final android = AndroidNotificationDetails(
      androidChannelId,
      _androidChannelName,
      channelDescription: 'Reminders for your habits',
      importance: Importance.high,
      priority: Priority.high,
      playSound: request.playSound,
      enableVibration: request.playSound,
      category: AndroidNotificationCategory.reminder,
      actions: [
        for (final action in request.actions)
          AndroidNotificationAction(
            action.id,
            action.title,
            showsUserInterface: action.id == 'open',
            cancelNotification: true,
          ),
      ],
    );

    final windows = WindowsNotificationDetails(
      actions: [
        for (final action in request.actions)
          WindowsAction(
            content: action.title,
            arguments: jsonEncode({
              'action': action.id,
              'payload': request.payload,
            }),
          ),
      ],
      scenario: WindowsNotificationScenario.reminder,
      audio: request.playSound ? null : WindowsNotificationAudio.silent(),
    );

    return NotificationDetails(android: android, windows: windows);
  }
}
