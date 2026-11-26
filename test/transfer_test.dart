import 'package:fineva/data/data_export.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  const bank = Account(id: 1, name: 'Bank');
  const cash = Account(id: 2, name: 'Cash');
  const euro = Account(id: 3, name: 'Euro', currency: Currency.eur);
  const dollar = Account(id: 4, name: 'Dollar', currency: Currency.usd);
  const euro2 = Account(id: 5, name: 'Euro 2', currency: Currency.eur);
  final day = DateTime(2026, 11, 10);

  group('transferSides: the same worth in the main currency', () {
    test('between forint accounts: no rates', () {
      final sides = transferSides(
        from: bank,
        to: cash,
        fromAmount: 50000,
        date: day,
        note: 'ATM',
        main: Currency.huf,
      )!;
      expect(sides.from.type, EntryType.expense);
      expect(sides.from.accountId, bank.id);
      expect(sides.to.type, EntryType.income);
      expect(sides.to.amount, 50000);
      expect(sides.to.note, 'ATM');
      expect(sides.from.rate, isNull);
      expect(sides.to.rate, isNull);
      expect(sides.dayRates, isEmpty);
    });

    test('forints to euros: the rate the amounts make, the day\'s rate', () {
      // 390 000 Ft for 1000.00 EUR.
      final sides = transferSides(
        from: bank,
        to: euro,
        fromAmount: 390000,
        toAmount: 100000,
        date: day,
        main: Currency.huf,
      )!;
      expect(sides.to.rate, 390);
      expect(sides.to.rateSource, RateSource.manual);
      expect(sides.from.rate, isNull);
      final rate = sides.dayRates.single;
      expect(rate.currency, Currency.eur);
      expect(rate.base, Currency.huf);
      expect(rate.rate, 390);
      expect(rate.date, day);
    });

    test('euros to forints, odd amounts: the same worth exactly', () {
      final sides = transferSides(
        from: euro,
        to: bank,
        fromAmount: 26385,
        toAmount: 100001,
        date: day,
        main: Currency.huf,
      )!;
      final state = FinanceState(
        accounts: const [bank, euro],
        entries: [sides.from, sides.to],
      );
      expect(state.entryInMain(sides.from), -100001);
      expect(state.entryInMain(sides.to), 100001);
    });

    test(
      'between two other currencies: at the rate of the one it goes from',
      () {
        final sides = transferSides(
          from: euro,
          to: dollar,
          fromAmount: 10000,
          toAmount: 10850,
          date: day,
          main: Currency.huf,
          fromRate: 390,
          fromRateSource: RateSource.mnb,
        )!;
        expect(sides.from.rate, 390);
        expect(sides.from.rateSource, RateSource.mnb);
        // 39 000 Ft for 108.50 USD.
        expect(sides.to.rate, closeTo(39000 / 108.5, 1e-9));
        // The downloaded rate isn't a new day's rate, the made one is.
        expect(sides.dayRates.map((r) => r.currency), [Currency.usd]);
        final state = FinanceState(
          accounts: const [euro, dollar],
          entries: [sides.from, sides.to],
        );
        expect(state.entryInMain(sides.from), -39000);
        expect(state.entryInMain(sides.to), 39000);

        // Without a rate there is no worth.
        expect(
          transferSides(
            from: euro,
            to: dollar,
            fromAmount: 10000,
            toAmount: 10850,
            date: day,
            main: Currency.huf,
          ),
          isNull,
        );
      },
    );

    test('between two euro accounts: the same rate on both sides', () {
      final sides = transferSides(
        from: euro,
        to: euro2,
        fromAmount: 5000,
        date: day,
        main: Currency.huf,
        fromRate: 391.5,
        fromRateSource: RateSource.manual,
      )!;
      expect(sides.to.amount, 5000);
      expect(sides.from.rate, 391.5);
      expect(sides.to.rate, 391.5);
      expect(sides.dayRates.single.rate, 391.5);
    });

    test('no amount, nothing', () {
      expect(
        transferSides(
          from: bank,
          to: euro,
          fromAmount: 390000,
          date: day,
          main: Currency.huf,
        ),
        isNull,
      );
      expect(
        transferSides(
          from: bank,
          to: cash,
          fromAmount: 0,
          date: day,
          main: Currency.huf,
        ),
        isNull,
      );
    });
  });

  test('a currency exchange is no income or expense: only the rate changing '
      'is a revaluation', () {
    final sides = transferSides(
      from: bank,
      to: euro,
      fromAmount: 390000,
      toAmount: 100000,
      date: day,
      main: Currency.huf,
    )!;
    final state = FinanceState(
      accounts: const [bank, euro],
      entries: [
        Entry(
          id: 2,
          accountId: 3,
          type: EntryType.income,
          amount: 100000,
          date: day,
          rate: 390,
          transferId: 1,
        ),
        Entry(
          id: 1,
          accountId: 1,
          type: EntryType.expense,
          amount: 390000,
          date: day,
          transferId: 1,
        ),
        Entry(
          id: 0,
          accountId: 1,
          type: EntryType.income,
          amount: 500000,
          date: DateTime(2026, 10),
          opening: true,
        ),
      ],
      rates: RateBook([
        ExchangeRate(
          source: RateSource.mnb,
          date: DateTime(2026, 11, 27),
          currency: Currency.eur,
          base: Currency.huf,
          rate: 400,
        ),
      ]),
    );
    expect(sides.to.rate, 390);
    final november = DatePeriod.of(PeriodKind.month, day);
    final totals = state.periodTotals(november);
    expect(totals.income, 0);
    expect(totals.expense, 0);
    final change = state.periodChange(november);
    expect(change.result, 0);
    expect(change.revaluation, 10000);

    expect(state.transferSides(1)!.from.accountId, bank.id);
    expect(state.transferSides(1)!.to.accountId, euro.id);
    expect(state.transferPeer(state.entries.first), bank);
    expect(state.transferPeer(state.entries.last), isNull);
  });

  group('database', () {
    late TestDatabase testDb;
    setUp(() async => testDb = await TestDatabase.create());
    tearDown(() => testDb.dispose());

    test('a transfer is saved as its two sides, replaced when saved again, '
        'deleted with them', () async {
      final db = testDb.datasource;
      final user = await db.insertProfile(const Profile(name: 'Anna'));
      final from = await db.insert(
        Account.table,
        Account(userId: user, name: 'Bank'),
      );
      final to = await db.insert(
        Account.table,
        Account(userId: user, name: 'Cash'),
      );
      Entry side(int account, EntryType type, int amount) =>
          Entry(accountId: account, type: type, amount: amount, date: day);
      final id = await db.saveTransfer(
        null,
        user,
        side(from, EntryType.expense, 1000),
        side(to, EntryType.income, 1000),
      );
      var entries = await db.getAll(Entry.table, Entry.fromMap);
      expect(entries.map((e) => e.transferId), [id, id]);

      await db.saveTransfer(
        id,
        user,
        side(from, EntryType.expense, 700),
        side(to, EntryType.income, 700),
      );
      entries = await db.getAll(Entry.table, Entry.fromMap);
      expect(entries.map((e) => e.amount), [700, 700]);
      expect(await db.accountBalances(user), {from: -700, to: 700});

      await db.deleteTransfer(id, user);
      expect(await db.getAll(Entry.table, Entry.fromMap), isEmpty);
    });
  });
}
