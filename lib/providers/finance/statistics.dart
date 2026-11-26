import '../../data/data_export.dart';
import '../../utils/utils.dart';
import 'date_period.dart';
import 'finance_state.dart';

/// The entries of a category (null: without category) in a period.
typedef CategoryTotal = ({EntryCategory? category, int amount});

/// The balance at the end of [date].
typedef BalancePoint = ({DateTime date, int balance});

/// How long the cash flow's bars are.
enum CashFlowStep { day, week, month, year }

/// Income and expenses of the days from [start] to [last].
typedef CashFlowBucket = ({
  DateTime start,
  DateTime last,
  int income,
  int expense,
});

/// The figures of the statistics page: the current user's entries in
/// [period], in their main [currency]. Entries of other currencies count at
/// the rate of their day ([FinanceState.entryInMain]), balances at the rate
/// of each day; amounts without a rate are left out ([missing]).
class Statistics {
  Statistics(FinanceState state, this.period, {DateTime? today})
    : _state = state,
      currency = state.mainCurrency,
      today = today ?? currentDay() {
    // The oldest first.
    _entries = state.entries.reversed.toList();
    final day = period.last ?? this.today;
    for (final account in state.accounts) {
      if (!state.hasRate(account.currency, day)) missing.add(account.currency);
    }
    for (final entry in _entries) {
      // The opening balance and a transfer are no income or expense, only
      // in the balances.
      if (entry.opening || entry.isTransfer || !period.contains(entry.date)) {
        continue;
      }
      final value = state.entryInMain(entry);
      if (value == null) {
        missing.add(state.account(entry.accountId)?.currency ?? currency);
      } else {
        _inPeriod.add((entry: entry, amount: value.abs()));
      }
    }
  }

  final FinanceState _state;
  final Currency currency;
  final DatePeriod period;

  /// The last day with a balance; days after it are in the future.
  final DateTime today;

  /// The currencies whose amounts are left out for want of a rate.
  final Set<Currency> missing = {};

  late final List<Entry> _entries;

  /// The entries of the period with their amount in [currency].
  final List<({Entry entry, int amount})> _inPeriod = [];

  bool get isEmpty => _inPeriod.isEmpty;

  late final int income = _sum(_inPeriod, EntryType.income);
  late final int expense = _sum(_inPeriod, EntryType.expense);

  /// Income minus expenses.
  int get net => income - expense;

  /// How the balance changed in the period, and why: the result, the
  /// opening entries and the revaluation (see [FinanceState.periodChange]).
  late final change = _state.periodChange(period, today: today);

  /// The same figures of the period before, of the same length; null for
  /// all time.
  late final Statistics? previous = period.isAll
      ? null
      : Statistics(_state, period.previous, today: today);

  /// The part of the income that wasn't spent; null without income.
  double? get savingsRate => income == 0 ? null : net / income;

  static int _sum(
    Iterable<({Entry entry, int amount})> items,
    EntryType type,
  ) => items
      .where((i) => i.entry.type == type)
      .fold(0, (sum, i) => sum + i.amount);

  /// The sum of each category of [type], the largest first.
  List<CategoryTotal> categoryTotals(EntryType type) {
    final sums = <int?, int>{};
    for (final (:entry, :amount) in _inPeriod) {
      if (entry.type != type) continue;
      sums.update(
        entry.categoryId,
        (sum) => sum + amount,
        ifAbsent: () => amount,
      );
    }
    final totals = [
      for (final MapEntry(key: id, value: amount) in sums.entries)
        (category: _state.category(id), amount: amount),
    ];
    return totals..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Whether [balanceSeries] has a point a month (all time, or more than
  /// [maxDailyPoints] days) instead of one a day.
  bool get monthlyBalance =>
      period.isAll || period.days! > Statistics.maxDailyPoints;

  /// The most days the balance line has a point for each.
  static const int maxDailyPoints = 400;

  /// The balance of every account at the end of each day of the period (up
  /// to today), in [currency] at the rates of the day; see [monthlyBalance]
  /// for the end of each month instead. All time starts with the month of
  /// the first entry. An account without a rate is left out.
  List<BalancePoint> balanceSeries() {
    final start =
        period.start ??
        (_entries.isEmpty
            ? DateTime(today.year, today.month)
            : DateTime(_entries.first.date.year, _entries.first.date.month));
    final periodLast = period.last;
    final last = periodLast == null || periodLast.isAfter(today)
        ? today
        : periodLast;
    final days = <DateTime>[];
    if (monthlyBalance) {
      for (
        var month = DateTime(start.year, start.month);
        !month.isAfter(last);
        month = DateTime(month.year, month.month + 1)
      ) {
        final monthEnd = DateTime(month.year, month.month + 1, 0);
        days.add(monthEnd.isAfter(last) ? last : monthEnd);
      }
    } else {
      for (
        var day = start;
        !day.isAfter(last);
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        days.add(day);
      }
    }

    // Each account's balance in its own currency.
    final balances = {for (final account in _state.accounts) ?account.id: 0};
    final points = <BalancePoint>[];
    var next = 0; // the first entry not added yet
    for (final day in days) {
      while (next < _entries.length && !_entries[next].date.isAfter(day)) {
        final entry = _entries[next];
        balances.update(
          entry.accountId,
          (balance) => balance + entry.signedAmount,
          ifAbsent: () => entry.signedAmount,
        );
        next++;
      }
      points.add((date: day, balance: _state.totalInMain(balances, day).total));
    }
    return points;
  }

  /// The length of the [cashFlow] bars: a day up to a week, 7 days up to
  /// two months (a month: days 1-7, 8-14, ...), a month up to two years,
  /// otherwise (and for all time) a year.
  CashFlowStep get cashFlowStep {
    final days = period.days;
    if (days == null) return CashFlowStep.year;
    if (days <= 7) return CashFlowStep.day;
    if (days <= 62) return CashFlowStep.week;
    if (days <= 731) return CashFlowStep.month;
    return CashFlowStep.year;
  }

  /// Income and expenses by [cashFlowStep], over the whole period (all time:
  /// from the year of the first entry to this year).
  List<CashFlowBucket> cashFlow() {
    final first =
        period.start ??
        DateTime(_entries.isEmpty ? today.year : _entries.first.date.year);
    final last = period.last ?? DateTime(today.year, 12, 31);
    final ranges = <(DateTime, DateTime)>[];
    var start = first;
    while (!start.isAfter(last)) {
      final next = switch (cashFlowStep) {
        CashFlowStep.day => DateTime(start.year, start.month, start.day + 1),
        CashFlowStep.week => DateTime(start.year, start.month, start.day + 7),
        CashFlowStep.month => DateTime(start.year, start.month + 1),
        CashFlowStep.year => DateTime(start.year + 1),
      };
      final end = DateTime(next.year, next.month, next.day - 1);
      ranges.add((start, end.isAfter(last) ? last : end));
      start = next;
    }
    return [
      for (final (start, last) in ranges)
        _bucket(
          start,
          last,
          _inPeriod.where(
            (i) => !i.entry.date.isBefore(start) && !i.entry.date.isAfter(last),
          ),
        ),
    ];
  }

  static CashFlowBucket _bucket(
    DateTime start,
    DateTime last,
    Iterable<({Entry entry, int amount})> items,
  ) => (
    start: start,
    last: last,
    income: _sum(items, EntryType.income),
    expense: _sum(items, EntryType.expense),
  );
}
