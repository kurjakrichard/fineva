import 'package:equatable/equatable.dart';

/// The kinds of [DatePeriod].
enum PeriodKind { week, month, quarter, year, all, custom }

/// Today, without the time of day.
DateTime currentDay() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// A span of days that the dashboard, the entries and the statistics show:
/// a week (Monday to Sunday), a calendar month, quarter or year, any days
/// from one to another, or all time.
class DatePeriod extends Equatable {
  const DatePeriod._(this.kind, this.start, this.last);

  /// All time.
  const DatePeriod.all() : this._(PeriodKind.all, null, null);

  /// The week, month, quarter or year that has [day]; for
  /// [PeriodKind.custom] the day alone.
  factory DatePeriod.of(PeriodKind kind, DateTime day) {
    final y = day.year;
    final m = day.month;
    final d = day.day;
    return switch (kind) {
      PeriodKind.week => DatePeriod._(
        kind,
        DateTime(y, m, d - day.weekday + 1),
        DateTime(y, m, d - day.weekday + 7),
      ),
      PeriodKind.month => DatePeriod._(
        kind,
        DateTime(y, m),
        DateTime(y, m + 1, 0),
      ),
      PeriodKind.quarter => DatePeriod._(
        kind,
        DateTime(y, _quarterStart(m)),
        DateTime(y, _quarterStart(m) + 3, 0),
      ),
      PeriodKind.year => DatePeriod._(kind, DateTime(y), DateTime(y, 12, 31)),
      PeriodKind.all => const DatePeriod.all(),
      PeriodKind.custom => DatePeriod._(
        kind,
        DateTime(y, m, d),
        DateTime(y, m, d),
      ),
    };
  }

  /// This week, month, quarter or year.
  factory DatePeriod.current(PeriodKind kind) =>
      DatePeriod.of(kind, currentDay());

  /// The days from [first] to [last], both included (in either order). A
  /// whole week, month, quarter or year is that kind of period.
  factory DatePeriod.range(DateTime first, DateTime last) {
    var a = DateTime(first.year, first.month, first.day);
    var b = DateTime(last.year, last.month, last.day);
    if (b.isBefore(a)) (a, b) = (b, a);
    for (final kind in const [
      PeriodKind.year,
      PeriodKind.quarter,
      PeriodKind.month,
      PeriodKind.week,
    ]) {
      final period = DatePeriod.of(kind, a);
      if (period.start == a && period.last == b) return period;
    }
    return DatePeriod._(PeriodKind.custom, a, b);
  }

  final PeriodKind kind;

  /// The first day; null for all time.
  final DateTime? start;

  /// The last day; null for all time.
  final DateTime? last;

  bool get isAll => kind == PeriodKind.all;

  /// The day after [last]; null for all time.
  DateTime? get end {
    final last = this.last;
    return last == null ? null : DateTime(last.year, last.month, last.day + 1);
  }

  /// How many days it has; null for all time.
  int? get days {
    final start = this.start;
    final last = this.last;
    if (start == null || last == null) return null;
    // In UTC: no daylight saving hour in the difference.
    return DateTime.utc(
          last.year,
          last.month,
          last.day,
        ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
        1;
  }

  bool contains(DateTime date) {
    final start = this.start;
    final end = this.end;
    return (start == null || !date.isBefore(start)) &&
        (end == null || date.isBefore(end));
  }

  /// The period of the same kind and length before; all time stays.
  DatePeriod get previous => _shift(-1);

  /// The period of the same kind and length after; all time stays.
  DatePeriod get next => _shift(1);

  /// False for all time.
  bool get hasPrevious => !isAll;

  /// True if [next] has begun by today: periods wholly in the future have
  /// nothing to show.
  bool get hasNext => !isAll && !next.start!.isAfter(currentDay());

  /// A period of [kind] (not custom) instead of this one: the one with today
  /// if this one has today, otherwise the one with this one's first day.
  DatePeriod withKind(PeriodKind kind) {
    final today = currentDay();
    final start = this.start;
    return DatePeriod.of(
      kind,
      start == null || contains(today) ? today : start,
    );
  }

  DatePeriod _shift(int by) {
    final start = this.start;
    final last = this.last;
    if (start == null || last == null) return this;
    return switch (kind) {
      PeriodKind.week => DatePeriod.of(
        kind,
        DateTime(start.year, start.month, start.day + 7 * by),
      ),
      PeriodKind.month => DatePeriod.of(
        kind,
        DateTime(start.year, start.month + by),
      ),
      PeriodKind.quarter => DatePeriod.of(
        kind,
        DateTime(start.year, start.month + 3 * by),
      ),
      PeriodKind.year => DatePeriod.of(kind, DateTime(start.year + by)),
      PeriodKind.custom => DatePeriod._(
        kind,
        DateTime(start.year, start.month, start.day + days! * by),
        DateTime(last.year, last.month, last.day + days! * by),
      ),
      PeriodKind.all => this,
    };
  }

  static int _quarterStart(int month) => (month - 1) ~/ 3 * 3 + 1;

  @override
  List<Object?> get props => [kind, start, last];

  @override
  String toString() => 'DatePeriod(${kind.name}, $start, $last)';
}
