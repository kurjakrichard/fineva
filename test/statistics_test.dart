import 'package:fineva/data/data_export.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Statistics', () {
    const food = EntryCategory(id: 1, name: 'Food', type: EntryType.expense);
    const rent = EntryCategory(id: 2, name: 'Rent', type: EntryType.expense);
    Entry entry(
      int accountId,
      EntryType type,
      int amount,
      DateTime date, [
      int? categoryId,
    ]) => Entry(
      accountId: accountId,
      type: type,
      amount: amount,
      date: date,
      categoryId: categoryId,
    );

    final state = FinanceState(
      accounts: const [
        Account(id: 1, name: 'Cash'),
        Account(id: 2, name: 'Bank'),
        Account(id: 3, name: 'Euro', currency: Currency.eur),
      ],
      categories: const [food, rent],
      // The newest first, as FinanceState has them.
      entries: [
        entry(3, EntryType.expense, 999, DateTime(2026, 11, 20), 1),
        entry(1, EntryType.expense, 300, DateTime(2026, 11, 15), 1),
        entry(2, EntryType.expense, 400, DateTime(2026, 11, 3), 2),
        entry(2, EntryType.expense, 100, DateTime(2026, 11, 2)),
        entry(1, EntryType.income, 2000, DateTime(2026, 11, 1)),
        entry(1, EntryType.expense, 50, DateTime(2026, 10, 31), 1),
        // The opening balances: only in the balances.
        Entry(
          accountId: 2,
          type: EntryType.income,
          amount: 500,
          date: DateTime(2026, 10),
          opening: true,
        ),
        Entry(
          accountId: 1,
          type: EntryType.income,
          amount: 1000,
          date: DateTime(2026, 10),
          opening: true,
        ),
      ],
    );
    final november = Statistics(
      state,
      DatePeriod.of(PeriodKind.month, DateTime(2026, 11)),
      today: DateTime(2026, 11, 22),
    );

    test('totals of the period in the main currency; no EUR rate', () {
      expect(november.missing, {Currency.eur});
      expect(november.income, 2000);
      expect(november.expense, 800);
      expect(november.net, 1200);
      expect(november.savingsRate, 0.6);
      expect(
        Statistics(
          state,
          DatePeriod.of(PeriodKind.month, DateTime(2026, 9)),
        ).savingsRate,
        isNull,
      );
      // The month before, to compare with; none for all time.
      expect(november.previous!.period.start, DateTime(2026, 10));
      expect(november.previous!.expense, 50);
      expect(Statistics(state, const DatePeriod.all()).previous, isNull);
      // October's opening balances are no income.
      final october = Statistics(
        state,
        DatePeriod.of(PeriodKind.month, DateTime(2026, 10)),
      );
      expect(october.income, 0);
      expect(october.expense, 50);
    });

    test('category totals, the largest first, with the uncategorized', () {
      expect(november.categoryTotals(EntryType.expense), [
        (category: rent, amount: 400),
        (category: food, amount: 300),
        (category: null, amount: 100),
      ]);
      expect(november.categoryTotals(EntryType.income), [
        (category: null, amount: 2000),
      ]);
    });

    test('the balance at the end of each day up to today', () {
      final points = november.balanceSeries();
      expect(points, hasLength(22));
      expect(points.first.date, DateTime(2026, 11, 1));
      // 1500 opening, -50 in October, +2000 on the 1st.
      expect(points.first.balance, 3450);
      expect(points[1].balance, 3350); // -100 on the 2nd
      expect(points.last.date, DateTime(2026, 11, 22));
      expect(points.last.balance, 2650);
    });

    test('all time: the balance at the end of each month', () {
      final points = Statistics(
        state,
        const DatePeriod.all(),
        today: DateTime(2026, 11, 22),
      ).balanceSeries();
      expect(points.map((p) => p.date), [
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 22),
      ]);
      expect(points.map((p) => p.balance), [1450, 2650]);
    });

    test('cash flow by week of a month and by month of a year', () {
      final weeks = november.cashFlow();
      expect(weeks.map((w) => (w.start.day, w.last.day)), [
        (1, 7),
        (8, 14),
        (15, 21),
        (22, 28),
        (29, 30),
      ]);
      expect(weeks.first.income, 2000);
      expect(weeks.first.expense, 500);
      expect(weeks[2].expense, 300);

      final months = Statistics(
        state,
        DatePeriod.of(PeriodKind.year, DateTime(2026)),
      ).cashFlow();
      expect(months, hasLength(12));
      expect(months[9].expense, 50);
      expect(months[10].expense, 800);
    });

    test('cash flow by day of a week, by month of a quarter or of days '
        'across a year', () {
      final week = Statistics(
        state,
        DatePeriod.of(PeriodKind.week, DateTime(2026, 11, 3)),
      );
      expect(week.cashFlowStep, CashFlowStep.day);
      final days = week.cashFlow();
      expect(days.map((d) => d.start.day), [2, 3, 4, 5, 6, 7, 8]);
      expect(days[1].expense, 400);

      final quarter = Statistics(
        state,
        DatePeriod.of(PeriodKind.quarter, DateTime(2026, 11)),
      );
      expect(quarter.cashFlowStep, CashFlowStep.month);
      expect(quarter.cashFlow().map((m) => (m.start, m.last)), [
        (DateTime(2026, 10), DateTime(2026, 10, 31)),
        (DateTime(2026, 11), DateTime(2026, 11, 30)),
        (DateTime(2026, 12), DateTime(2026, 12, 31)),
      ]);

      // Months cut at the period's ends.
      final custom = Statistics(
        state,
        DatePeriod.range(DateTime(2026, 10, 15), DateTime(2027, 1, 10)),
      );
      expect(custom.cashFlowStep, CashFlowStep.month);
      final months = custom.cashFlow();
      expect(months.first.start, DateTime(2026, 10, 15));
      expect(months.last.last, DateTime(2027, 1, 10));
      expect(months, hasLength(4));
    });

    test('a long period has a balance point a month', () {
      final twoYears = Statistics(
        state,
        DatePeriod.range(DateTime(2025, 6, 1), DateTime(2026, 12, 31)),
        today: DateTime(2026, 11, 22),
      );
      expect(twoYears.monthlyBalance, isTrue);
      final points = twoYears.balanceSeries();
      expect(points.first.date, DateTime(2025, 6, 30));
      expect(points.last.date, DateTime(2026, 11, 22));
      expect(points, hasLength(18));
      expect(twoYears.cashFlowStep, CashFlowStep.month);
    });

    test('other currencies at the rate of the day: entries at their '
        'day, balances at each day', () {
      final withRates = FinanceState(
        accounts: state.accounts,
        categories: state.categories,
        entries: state.entries,
        rates: RateBook([
          ExchangeRate(
            source: RateSource.mnb,
            date: DateTime(2026, 11, 2),
            currency: Currency.eur,
            base: Currency.huf,
            rate: 400,
          ),
          ExchangeRate(
            source: RateSource.mnb,
            date: DateTime(2026, 11, 20),
            currency: Currency.eur,
            base: Currency.huf,
            rate: 410,
          ),
        ]),
      );
      final stats = Statistics(
        withRates,
        DatePeriod.of(PeriodKind.month, DateTime(2026, 11)),
        today: DateTime(2026, 11, 22),
      );
      expect(stats.missing, isEmpty);
      // 9.99 EUR at 410 on the 20th: 4096 Ft.
      expect(stats.expense, 800 + 4096);
      expect(stats.categoryTotals(EntryType.expense).first, (
        category: food,
        amount: 300 + 4096,
      ));
      final points = stats.balanceSeries();
      // Before the 20th the EUR account is empty.
      expect(points[18].balance, 2650);
      expect(points[19].balance, 2650 - 4096);
    });
  });
}
