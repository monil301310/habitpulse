/// A date in the user's local calendar with no time and no time zone.
///
/// Log dates are stored as local calendar days so a completion never shifts
/// when the device changes time zone (spec section 8). All calendar arithmetic
/// uses UTC internally so daylight-saving transitions cannot skip or repeat a
/// day.
class LocalDay implements Comparable<LocalDay> {
  const LocalDay(this.year, this.month, this.day);

  factory LocalDay.fromDateTime(DateTime dateTime) =>
      LocalDay(dateTime.year, dateTime.month, dateTime.day);

  /// Parses `yyyy-MM-dd`.
  factory LocalDay.parse(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid local day: $iso');
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      throw FormatException('Invalid local day: $iso');
    }
    return LocalDay(year, month, day);
  }

  /// Tries to parse `yyyy-MM-dd`, returning null instead of throwing.
  static LocalDay? tryParse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return LocalDay.parse(iso);
    } on FormatException {
      return null;
    }
  }

  final int year;
  final int month;
  final int day;

  /// ISO weekday: Monday = 1 … Sunday = 7.
  int get weekday => DateTime.utc(year, month, day).weekday;

  LocalDay addDays(int days) {
    final shifted = DateTime.utc(
      year,
      month,
      day,
    ).add(Duration(days: days));
    return LocalDay(shifted.year, shifted.month, shifted.day);
  }

  int differenceInDays(LocalDay other) {
    return DateTime.utc(
      year,
      month,
      day,
    ).difference(DateTime.utc(other.year, other.month, other.day)).inDays;
  }

  bool isBefore(LocalDay other) => compareTo(other) < 0;
  bool isAfter(LocalDay other) => compareTo(other) > 0;
  bool isSameDayAs(LocalDay? other) => other != null && this == other;

  /// The first day of the calendar week containing this day.
  ///
  /// [weekStart] is an ISO weekday (Monday = 1).
  LocalDay startOfWeek(int weekStart) {
    final delta = (weekday - weekStart + 7) % 7;
    return addDays(-delta);
  }

  String toIso() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  int compareTo(LocalDay other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) {
    return other is LocalDay &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

/// A wall-clock time of day with no date, used for rollover, reminders and the
/// recheck.
class DayTime implements Comparable<DayTime> {
  const DayTime(this.hour, this.minute);

  /// Parses `HH:mm`.
  factory DayTime.parse(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid time of day: $value');
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      throw FormatException('Invalid time of day: $value');
    }
    return DayTime(hour, minute);
  }

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  String toStorageString() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  int compareTo(DayTime other) =>
      minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  @override
  bool operator ==(Object other) {
    return other is DayTime && other.hour == hour && other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => toStorageString();
}
