import '../models/local_day.dart';

/// Resolves which local day a moment in time belongs to, honouring the
/// user-configurable "day rollover" time.
///
/// With the default 03:00 rollover, a log made at 01:30 counts for the previous
/// calendar day, so late-night logging still completes "today".
LocalDay resolveEffectiveDay(DateTime now, DayTime rollover) {
  final calendarDay = LocalDay.fromDateTime(now);
  final minutesNow = now.hour * 60 + now.minute;
  return minutesNow < rollover.minutesSinceMidnight
      ? calendarDay.addDays(-1)
      : calendarDay;
}
