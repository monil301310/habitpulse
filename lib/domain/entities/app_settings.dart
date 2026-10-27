/// Per-user preferences.
class AppSettings {
  const AppSettings({
    required this.userId,
    this.theme = 'dark',
    this.weekStart = 1,
    this.dayRolloverTime = '03:00',
    this.quietHours = '23:00-07:00',
    this.recheckTime = '21:30',
    this.morningRecheckTime,
    this.notificationSound = true,
    required this.updatedAt,
  });

  /// The single local user until accounts arrive (Phase 5).
  factory AppSettings.defaults({DateTime? now}) {
    return AppSettings(
      userId: 'local',
      updatedAt: now ?? DateTime.now().toUtc(),
    );
  }

  final String userId;

  /// One of `dark`, `light`, or `system`.
  final String theme;

  /// ISO weekday the week starts on (Monday = 1).
  final int weekStart;

  /// `HH:mm` when a day closes so late-night logging still counts.
  final String dayRolloverTime;

  /// `HH:mm-HH:mm` window during which no reminders fire.
  final String quietHours;

  /// `HH:mm` of the daily recheck notification.
  final String recheckTime;

  /// `HH:mm` of the optional morning recheck, or null when disabled.
  final String? morningRecheckTime;

  /// Whether notifications play a sound.
  final bool notificationSound;

  final DateTime updatedAt;

  AppSettings copyWith({
    String? theme,
    int? weekStart,
    String? dayRolloverTime,
    String? quietHours,
    String? recheckTime,
    String? morningRecheckTime,
    bool clearMorningRecheck = false,
    bool? notificationSound,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      userId: userId,
      theme: theme ?? this.theme,
      weekStart: weekStart ?? this.weekStart,
      dayRolloverTime: dayRolloverTime ?? this.dayRolloverTime,
      quietHours: quietHours ?? this.quietHours,
      recheckTime: recheckTime ?? this.recheckTime,
      morningRecheckTime: clearMorningRecheck
          ? null
          : (morningRecheckTime ?? this.morningRecheckTime),
      notificationSound: notificationSound ?? this.notificationSound,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
