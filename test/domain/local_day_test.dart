import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/domain/models/local_day.dart';

void main() {
  group('LocalDay', () {
    test('reports ISO weekdays (Monday = 1, Sunday = 7)', () {
      // 2024-01-01 was a Monday.
      expect(const LocalDay(2024, 1, 1).weekday, 1);
      expect(const LocalDay(2024, 1, 6).weekday, 6);
      expect(const LocalDay(2024, 1, 7).weekday, 7);
    });

    test('adds and subtracts days across month and year boundaries', () {
      expect(const LocalDay(2026, 12, 31).addDays(1), const LocalDay(2027, 1, 1));
      expect(const LocalDay(2024, 2, 28).addDays(1), const LocalDay(2024, 2, 29));
      expect(const LocalDay(2024, 3, 1).addDays(-1), const LocalDay(2024, 2, 29));
      expect(const LocalDay(2026, 1, 1).addDays(-1), const LocalDay(2025, 12, 31));
    });

    test('computes differences in calendar days', () {
      expect(
        const LocalDay(2026, 10, 25).differenceInDays(const LocalDay(2026, 10, 1)),
        24,
      );
      expect(
        const LocalDay(2026, 3, 1).differenceInDays(const LocalDay(2026, 2, 1)),
        28,
      );
      expect(
        const LocalDay(2024, 3, 1).differenceInDays(const LocalDay(2024, 2, 1)),
        29, // leap year
      );
    });

    test('startOfWeek honours the configured week start', () {
      // Wednesday 2024-01-03.
      const wednesday = LocalDay(2024, 1, 3);
      expect(wednesday.startOfWeek(1), const LocalDay(2024, 1, 1)); // Monday
      expect(wednesday.startOfWeek(7), const LocalDay(2023, 12, 31)); // Sunday
    });

    test('parses and formats yyyy-MM-dd', () {
      expect(LocalDay.parse('2026-10-05'), const LocalDay(2026, 10, 5));
      expect(const LocalDay(2026, 10, 5).toIso(), '2026-10-05');
      expect(LocalDay.tryParse('nope'), isNull);
      expect(LocalDay.tryParse(null), isNull);
    });

    test('compares, sorts and hashes by date', () {
      const a = LocalDay(2026, 10, 24);
      const b = LocalDay(2026, 10, 25);
      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect(a.compareTo(b), lessThan(0));
      expect(a == const LocalDay(2026, 10, 24), isTrue);
      expect(a.hashCode, const LocalDay(2026, 10, 24).hashCode);

      final sorted = [b, a, const LocalDay(2026, 1, 1)]..sort();
      expect(sorted.first, const LocalDay(2026, 1, 1));
      expect(sorted.last, b);
    });
  });

  group('DayTime', () {
    test('parses and formats HH:mm', () {
      expect(DayTime.parse('03:00').hour, 3);
      expect(DayTime.parse('21:30').minute, 30);
      expect(const DayTime(7, 5).toStorageString(), '07:05');
    });

    test('compares by minutes since midnight', () {
      expect(const DayTime(3, 0).compareTo(const DayTime(7, 0)), lessThan(0));
      expect(const DayTime(23, 59).compareTo(const DayTime(0, 0)), greaterThan(0));
    });
  });
}
