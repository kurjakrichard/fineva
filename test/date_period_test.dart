import 'package:fineva/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DatePeriod of(PeriodKind kind, int y, int m, int d) =>
      DatePeriod.of(kind, DateTime(y, m, d));

  test('a week runs from Monday to Sunday, across months too', () {
    // 2026-11-22 is a Sunday.
    final week = of(PeriodKind.week, 2026, 11, 22);
    expect(week.start, DateTime(2026, 11, 16));
    expect(week.last, DateTime(2026, 11, 22));
    expect(week.days, 7);
    expect(week.next.start, DateTime(2026, 11, 23));
    expect(of(PeriodKind.week, 2026, 12, 31).start, DateTime(2026, 12, 28));
    expect(of(PeriodKind.week, 2026, 12, 31).last, DateTime(2027, 1, 3));
  });

  test('a month, its neighbours across the year, its days', () {
    final november = of(PeriodKind.month, 2026, 11, 22);
    expect(november.start, DateTime(2026, 11));
    expect(november.last, DateTime(2026, 11, 30));
    expect(november.end, DateTime(2026, 12));
    expect(november.contains(DateTime(2026, 11, 30)), isTrue);
    expect(november.contains(DateTime(2026, 12)), isFalse);
    expect(november.previous, of(PeriodKind.month, 2026, 10, 1));
    expect(of(PeriodKind.month, 2027, 1, 5).previous.start, DateTime(2026, 12));
    expect(of(PeriodKind.month, 2026, 2, 1).days, 28);
    // Daylight saving time ends in October: still 31 days.
    expect(of(PeriodKind.month, 2026, 10, 1).days, 31);
  });

  test('a quarter and a year', () {
    final q4 = of(PeriodKind.quarter, 2026, 11, 22);
    expect(q4.start, DateTime(2026, 10));
    expect(q4.last, DateTime(2026, 12, 31));
    expect(q4.next, of(PeriodKind.quarter, 2027, 1, 1));
    expect(of(PeriodKind.quarter, 2026, 3, 31).start, DateTime(2026));
    final year = of(PeriodKind.year, 2025, 6, 1);
    expect(year.start, DateTime(2025));
    expect(year.last, DateTime(2025, 12, 31));
    expect(year.days, 365);
    expect(year.next.start, DateTime(2026));
  });

  test('any days; a whole week, month, quarter or year is that kind', () {
    final custom = DatePeriod.range(
      DateTime(2026, 11, 10, 15),
      DateTime(2026, 11, 3),
    );
    expect(custom.kind, PeriodKind.custom);
    expect(custom.start, DateTime(2026, 11, 3));
    expect(custom.last, DateTime(2026, 11, 10));
    expect(custom.days, 8);
    // The same number of days before and after.
    expect(custom.previous.start, DateTime(2026, 10, 26));
    expect(custom.previous.last, DateTime(2026, 11, 2));
    expect(custom.next.start, DateTime(2026, 11, 11));

    expect(
      DatePeriod.range(DateTime(2026, 11), DateTime(2026, 11, 30)),
      of(PeriodKind.month, 2026, 11, 1),
    );
    expect(
      DatePeriod.range(DateTime(2026, 4), DateTime(2026, 6, 30)).kind,
      PeriodKind.quarter,
    );
    expect(
      DatePeriod.range(DateTime(2026), DateTime(2026, 12, 31)).kind,
      PeriodKind.year,
    );
    expect(
      DatePeriod.range(DateTime(2026, 11, 16), DateTime(2026, 11, 22)).kind,
      PeriodKind.week,
    );
  });

  test('all time has everything and no neighbours', () {
    const all = DatePeriod.all();
    expect(all.contains(DateTime(1990)), isTrue);
    expect(all.days, isNull);
    expect(all.previous, all);
    expect(all.hasPrevious, isFalse);
    expect(all.hasNext, isFalse);
  });

  test('no next period wholly in the future', () {
    expect(DatePeriod.current(PeriodKind.month).hasNext, isFalse);
    expect(DatePeriod.current(PeriodKind.year).hasNext, isFalse);
    expect(DatePeriod.current(PeriodKind.month).previous.hasNext, isTrue);
  });

  test('another kind: around today if the period has it, else its start', () {
    final today = currentDay();
    expect(
      DatePeriod.current(PeriodKind.month).withKind(PeriodKind.week),
      DatePeriod.current(PeriodKind.week),
    );
    final past = of(PeriodKind.month, today.year - 1, 5, 1);
    expect(
      past.withKind(PeriodKind.year),
      of(PeriodKind.year, today.year - 1, 1, 1),
    );
    expect(
      const DatePeriod.all().withKind(PeriodKind.quarter),
      DatePeriod.current(PeriodKind.quarter),
    );
  });
}
