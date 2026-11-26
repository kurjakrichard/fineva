import 'package:fineva/data/data_export.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('periodTotals adds up the period in the main currency; currencies '
      'without a rate are left out', () {
    Entry entry(int accountId, EntryType type, int amount, DateTime date) =>
        Entry(accountId: accountId, type: type, amount: amount, date: date);

    final state = FinanceState(
      accounts: const [
        Account(id: 1, name: 'Cash'),
        Account(id: 2, name: 'Bank'),
        Account(id: 3, name: 'Euro', currency: Currency.eur),
        Account(id: 4, name: 'Dollar', currency: Currency.usd),
      ],
      entries: [
        entry(1, EntryType.income, 1000, DateTime(2026, 11, 30)),
        entry(2, EntryType.income, 500, DateTime(2026, 11, 1)),
        entry(2, EntryType.expense, 300, DateTime(2026, 11, 15)),
        // 10 EUR at 400.
        entry(3, EntryType.expense, 1000, DateTime(2026, 11, 16)),
        // No USD rate.
        entry(4, EntryType.expense, 1000, DateTime(2026, 11, 16)),
        // No income: an opening balance.
        Entry(
          accountId: 1,
          type: EntryType.income,
          amount: 5000,
          date: DateTime(2026, 11, 2),
          opening: true,
        ),
        // Other months.
        entry(1, EntryType.expense, 99, DateTime(2026, 10, 31)),
        entry(1, EntryType.expense, 99, DateTime(2025, 11, 15)),
      ],
      rates: RateBook([
        ExchangeRate(
          source: RateSource.mnb,
          date: DateTime(2026, 11, 13),
          currency: Currency.eur,
          base: Currency.huf,
          rate: 400,
        ),
      ]),
    );

    final november = state.periodTotals(
      DatePeriod.of(PeriodKind.month, DateTime(2026, 11, 22)),
    );
    expect(november.income, 1500);
    expect(november.expense, 300 + 4000);
    expect(november.missing, {Currency.usd});
    expect(state.periodTotals(const DatePeriod.all()).expense, 4498);
  });

  test("an account's ledger: by day, the newest first, with the balance at "
      "each day's end", () {
    const cash = Account(id: 1, name: 'Cash');
    Entry entry(int id, int account, EntryType type, int amount, int day) =>
        Entry(
          id: id,
          accountId: account,
          type: type,
          amount: amount,
          date: DateTime(2026, 11, day),
        );
    final state = FinanceState(
      accounts: const [
        cash,
        Account(id: 2, name: 'Bank'),
      ],
      // The newest first, as loaded.
      entries: [
        entry(5, 1, EntryType.expense, 50, 20),
        entry(4, 2, EntryType.income, 999, 20),
        entry(3, 1, EntryType.expense, 200, 3),
        entry(2, 1, EntryType.income, 500, 3),
        entry(1, 1, EntryType.expense, 100, 1),
        // The opening one, the oldest of its day.
        Entry(
          id: 9,
          accountId: 1,
          type: EntryType.income,
          amount: 1000,
          date: DateTime(2026, 11),
          opening: true,
        ),
      ],
    );
    final days = state.ledger(cash);
    expect(days.map((d) => d.day.day), [20, 3, 1]);
    expect(days.map((d) => d.balance), [1150, 1200, 900]);
    // The day's entries, the newest first; the other account's left out.
    expect(days[1].entries.map((e) => e.id), [3, 2]);
    expect(days[0].entries.map((e) => e.id), [5]);
    expect(days[2].entries.map((e) => e.id), [1, 9]);
    // Just after an entry, as on the statement: the opening one first.
    Entry byId(int id) => state.entries.firstWhere((e) => e.id == id);
    expect(state.balanceAfter(byId(9)), 1000);
    expect(state.balanceAfter(byId(1)), 900);
    expect(state.balanceAfter(byId(2)), 1400);
    expect(state.balanceAfter(byId(3)), 1200);
    expect(state.balanceAfter(byId(5)), 1150);
    expect(state.balanceAfter(byId(4)), 999);
    expect(state.ledger(const Account(id: 3, name: 'Empty')), isEmpty);
  });

  test('the balances at the end of a day', () {
    final state = FinanceState(
      accounts: const [
        Account(id: 1, name: 'Cash'),
        Account(id: 2, name: 'Euro', currency: Currency.eur),
      ],
      entries: [
        Entry(
          accountId: 1,
          type: EntryType.income,
          amount: 500,
          date: DateTime(2026, 11, 2),
        ),
        Entry(
          accountId: 1,
          type: EntryType.expense,
          amount: 300,
          date: DateTime(2026, 10, 31),
        ),
        Entry(
          accountId: 2,
          type: EntryType.income,
          amount: 25,
          date: DateTime(2026, 10, 1),
        ),
        // The openings.
        Entry(
          accountId: 2,
          type: EntryType.income,
          amount: 50,
          date: DateTime(2026, 9, 1),
          opening: true,
        ),
        Entry(
          accountId: 1,
          type: EntryType.income,
          amount: 1000,
          date: DateTime(2026, 9, 1),
          opening: true,
        ),
      ],
    );
    expect(state.balancesAt(DateTime(2026, 8, 31)), {1: 0, 2: 0});
    expect(state.balancesAt(DateTime(2026, 9, 30)), {1: 1000, 2: 50});
    // The day itself counts.
    expect(state.balancesAt(DateTime(2026, 10, 31)), {1: 700, 2: 75});
    expect(state.balancesAt(DateTime(2026, 11, 30)), {1: 1200, 2: 75});
    // No EUR rate: left out.
    final total = state.totalInMain(
      state.balancesAt(DateTime(2026, 10, 31)),
      DateTime(2026, 10, 31),
    );
    expect(total.total, 700);
    expect(total.missing, {Currency.eur});
  });

  test('a personal user sees the personal categories, a sole proprietor the '
      'business ones', () {
    const personal = EntryCategory(
      id: 1,
      name: 'Food',
      type: EntryType.expense,
    );
    const business = EntryCategory(
      id: 2,
      name: 'Business expense',
      type: EntryType.expense,
      scope: CategoryScope.business,
    );
    const categories = [personal, business];
    expect(
      const FinanceState(
        categories: categories,
        profile: Profile(),
      ).visibleCategories,
      [personal],
    );
    expect(
      const FinanceState(
        categories: categories,
        profile: Profile(userType: UserType.soleProprietor),
      ).visibleCategories,
      [business],
    );
  });

  test('an entry counts at its own rate; the balances at the last rate of '
      'the day; the difference is the revaluation', () {
    // 1000 EUR bought at 390 (its own rate); the rate is 400 at the end.
    final state = FinanceState(
      accounts: const [
        Account(id: 1, name: 'Bank'),
        Account(id: 2, name: 'Euro', currency: Currency.eur),
      ],
      entries: [
        Entry(
          accountId: 2,
          type: EntryType.income,
          amount: 100000,
          date: DateTime(2026, 11, 10),
          rate: 390,
          rateSource: RateSource.manual,
        ),
        Entry(
          accountId: 1,
          type: EntryType.expense,
          amount: 390000,
          date: DateTime(2026, 11, 10),
        ),
        Entry(
          accountId: 1,
          type: EntryType.income,
          amount: 500000,
          date: DateTime(2026, 10, 1),
          opening: true,
        ),
      ],
      rates: RateBook([
        ExchangeRate(
          source: RateSource.mnb,
          date: DateTime(2026, 11, 9),
          currency: Currency.eur,
          base: Currency.huf,
          rate: 385,
        ),
        ExchangeRate(
          source: RateSource.mnb,
          date: DateTime(2026, 11, 27),
          currency: Currency.eur,
          base: Currency.huf,
          rate: 400,
        ),
      ]),
    );
    final november = DatePeriod.of(PeriodKind.month, DateTime(2026, 11));
    // The entry at 390, not at the day's 385.
    final totals = state.periodTotals(november);
    expect(totals.income, 390000);
    expect(totals.expense, 390000);
    final change = state.periodChange(november);
    expect(change.opening, 500000);
    // 110 000 Ft and 1000 EUR at 400.
    expect(change.closing, 110000 + 400000);
    expect(change.result, 0);
    expect(change.openings, 0);
    expect(change.revaluation, 10000);

    // October: only the opening entry.
    final october = state.periodChange(
      DatePeriod.of(PeriodKind.month, DateTime(2026, 10)),
    );
    expect(october.opening, 0);
    expect(october.openings, 500000);
    expect(october.revaluation, 0);

    // The offered rate: the day's last one.
    expect(state.offeredRate(Currency.eur, DateTime(2026, 11, 10))?.rate, 385);
    expect(state.offeredRate(Currency.huf, DateTime(2026, 11, 10)), isNull);
  });

  test('an account can be closed with a 0 balance then and no later '
      'entries; a closed one is left out where new entries go', () {
    final state = FinanceState(
      accounts: [
        const Account(id: 1, name: 'Bank'),
        Account(id: 2, name: 'Old', closedDate: DateTime(2026, 6, 30)),
      ],
      entries: [
        Entry(
          accountId: 1,
          type: EntryType.expense,
          amount: 100,
          date: DateTime(2026, 7, 2),
        ),
        Entry(
          accountId: 1,
          type: EntryType.income,
          amount: 100,
          date: DateTime(2026, 6, 1),
        ),
      ],
    );
    const bank = Account(id: 1, name: 'Bank');
    expect(state.closingCheck(bank, DateTime(2026, 6, 30)), (
      balance: 100,
      later: 1,
    ));
    expect(state.closingCheck(bank, DateTime(2026, 7, 2)), (
      balance: 0,
      later: 0,
    ));
    expect(state.lastEntryDay(bank), DateTime(2026, 7, 2));
    expect(state.openAccounts().map((a) => a.id), [1]);
    // An entry's own account is kept.
    expect(state.openAccounts(keep: 2).map((a) => a.id), [1, 2]);
  });
}
