import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/logic/day_rollover.dart';
import '../../domain/models/local_day.dart';

/// The user's day rollover time. Stored in settings later (Phase 5); the
/// confirmed default for V1 is 03:00.
final rolloverTimeProvider = Provider<DayTime>((ref) {
  return DayTime.parse(AppConstants.defaultDayRolloverTime);
});

/// The first day of the week. Confirmed as Monday for V1.
final weekStartProvider = Provider<int>((ref) => AppConstants.defaultWeekStart);

/// The local day "today" currently belongs to, honouring the day rollover.
///
/// Resolved once when the app starts. A long-running session that crosses the
/// rollover time will refresh on the next app launch; scheduling an automatic
/// refresh belongs with the notification work in Phase 4.
final effectiveTodayProvider = Provider<LocalDay>((ref) {
  final rollover = ref.watch(rolloverTimeProvider);
  return resolveEffectiveDay(DateTime.now(), rollover);
});
