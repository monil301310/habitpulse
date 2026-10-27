import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/domain/logic/day_rollover.dart';
import 'package:habitpulse/domain/models/local_day.dart';

void main() {
  const rollover = DayTime(3, 0); // the default 03:00

  group('resolveEffectiveDay', () {
    test('before the rollover, belongs to the previous day', () {
      expect(
        resolveEffectiveDay(DateTime(2026, 10, 25, 1, 30), rollover),
        const LocalDay(2026, 10, 24),
      );
      expect(
        resolveEffectiveDay(DateTime(2026, 10, 25, 2, 59), rollover),
        const LocalDay(2026, 10, 24),
      );
    });

    test('at or after the rollover, belongs to the current day', () {
      expect(
        resolveEffectiveDay(DateTime(2026, 10, 25, 3, 0), rollover),
        const LocalDay(2026, 10, 25),
      );
      expect(
        resolveEffectiveDay(DateTime(2026, 10, 25, 21, 30), rollover),
        const LocalDay(2026, 10, 25),
      );
    });

    test('rolls across a month and year boundary', () {
      expect(
        resolveEffectiveDay(DateTime(2027, 1, 1, 0, 30), rollover),
        const LocalDay(2026, 12, 31),
      );
    });

    test('a midnight rollover never shifts the day', () {
      const midnight = DayTime(0, 0);
      expect(
        resolveEffectiveDay(DateTime(2026, 10, 25, 0, 0), midnight),
        const LocalDay(2026, 10, 25),
      );
    });

    test('a late rollover keeps late evenings on the previous day', () {
      const late = DayTime(23, 59);
      expect(
        resolveEffectiveDay(DateTime(2026, 10, 25, 23, 0), late),
        const LocalDay(2026, 10, 24),
      );
      expect(
        resolveEffectiveDay(DateTime(2026, 10, 25, 23, 59), late),
        const LocalDay(2026, 10, 25),
      );
    });
  });
}
