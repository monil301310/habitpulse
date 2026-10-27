import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/domain/enums/log_status.dart';
import 'package:habitpulse/domain/enums/schedule_type.dart';
import 'package:habitpulse/domain/logic/heatmap_logic.dart';
import 'package:habitpulse/domain/models/local_day.dart';

import '../support/fixtures.dart';

void main() {
  const today = LocalDay(2024, 1, 15); // Monday
  final habit = testHabit(startDate: const LocalDay(2024, 1, 1));

  HeatmapIntensity intensityFor({
    required LocalDay day,
    LogStatus? status,
  }) {
    return heatmapIntensityFor(
      habit: habit,
      log: status == null ? null : testLog(date: day, status: status),
      day: day,
      today: today,
    );
  }

  test('future days are empty', () {
    expect(intensityFor(day: today.addDays(1)), HeatmapIntensity.empty);
  });

  test('days before the start date are empty', () {
    expect(
      intensityFor(day: const LocalDay(2023, 12, 31)),
      HeatmapIntensity.empty,
    );
  });

  test('not-due weekdays are empty', () {
    final weekdays = testHabit(
      scheduleType: ScheduleType.weekdays,
      scheduleDays: {1, 3, 5},
      startDate: const LocalDay(2024, 1, 1),
    );

    // Sunday 14 Jan is not due for a Mon/Wed/Fri habit.
    expect(
      heatmapIntensityFor(
        habit: weekdays,
        log: null,
        day: const LocalDay(2024, 1, 14),
        today: today,
      ),
      HeatmapIntensity.empty,
    );
  });

  test('a closed due day with no log is missed', () {
    expect(
      intensityFor(day: const LocalDay(2024, 1, 14)),
      HeatmapIntensity.missed,
    );
  });

  test('today with no log stays open (empty)', () {
    expect(intensityFor(day: today), HeatmapIntensity.empty);
  });

  test('times-per-week unlogged days are neutral, not missed', () {
    final weekly = testHabit(
      scheduleType: ScheduleType.timesPerWeek,
      timesPerWeek: 3,
      startDate: const LocalDay(2024, 1, 1),
    );

    expect(
      heatmapIntensityFor(
        habit: weekly,
        log: null,
        day: const LocalDay(2024, 1, 10),
        today: today,
      ),
      HeatmapIntensity.empty,
    );
  });

  test('log statuses map to intensities', () {
    expect(intensityFor(day: today, status: LogStatus.done), HeatmapIntensity.done);
    expect(
      intensityFor(day: today, status: LogStatus.partial),
      HeatmapIntensity.partial,
    );
    expect(
      intensityFor(day: today, status: LogStatus.skipped),
      HeatmapIntensity.skipped,
    );
    expect(
      intensityFor(day: today, status: LogStatus.missed),
      HeatmapIntensity.missed,
    );
    expect(
      intensityFor(day: today, status: LogStatus.slipped),
      HeatmapIntensity.missed,
    );
  });
}
