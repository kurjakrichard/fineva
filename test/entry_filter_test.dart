import 'package:fineva/data/data_export.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const food = EntryCategory(
    id: 1,
    name: 'Élelmiszer',
    type: EntryType.expense,
  );
  const salary = EntryCategory(id: 2, name: 'Fizetés', type: EntryType.income);
  final state = FinanceState(
    accounts: const [
      Account(id: 1, name: 'Bankszámla'),
      Account(id: 2, name: 'Megtakarítás', currency: Currency.eur),
    ],
    categories: const [food, salary],
    entries: [
      Entry(
        id: 1,
        accountId: 1,
        categoryId: 2,
        type: EntryType.income,
        amount: 524300,
        date: DateTime(2026, 11, 5),
        note: 'Fizetés november',
      ),
      Entry(
        id: 2,
        accountId: 1,
        categoryId: 1,
        type: EntryType.expense,
        amount: 23450,
        date: DateTime(2026, 11, 3),
        note: 'Bevásárlás',
      ),
      Entry(
        id: 3,
        accountId: 2,
        type: EntryType.income,
        amount: 1250, // 12.50 EUR
        date: DateTime(2026, 10, 28),
        note: 'Kamat',
      ),
    ],
  );
  List<int?> ids(EntryFilter filter) => [
    for (final e in filter.apply(state, (c) => c.name)) e.id,
  ];

  test('nothing set: every entry, the newest first', () {
    expect(const EntryFilter().isActive, isFalse);
    expect(ids(const EntryFilter()), [1, 2, 3]);
  });

  test('the search ignores case and accents, every word must match', () {
    expect(foldForSearch('Élelmiszer KÖZLEKEDÉS'), 'elelmiszer kozlekedes');
    expect(ids(const EntryFilter(text: 'elelmiszer')), [2]);
    expect(ids(const EntryFilter(text: 'bankszamla fizetes')), [1]);
    expect(ids(const EntryFilter(text: 'bankszamla kamat')), isEmpty);
  });

  test('a number is looked for in the amount too', () {
    expect(ids(const EntryFilter(text: '23 450')), [2]);
    expect(ids(const EntryFilter(text: '12,50')), [3]);
    expect(ids(const EntryFilter(text: '524')), [1]);
  });

  test('type, account, category, no category, period', () {
    expect(ids(const EntryFilter().withType(EntryType.income)), [1, 3]);
    expect(ids(const EntryFilter().withAccount(2)), [3]);
    expect(ids(const EntryFilter().withCategory(1)), [2]);
    expect(ids(const EntryFilter().withCategory(null, none: true)), [3]);
    expect(
      ids(
        EntryFilter(
          period: DatePeriod.of(PeriodKind.month, DateTime(2026, 10, 15)),
        ),
      ),
      [3],
    );
    expect(
      ids(
        EntryFilter(
          period: DatePeriod.range(
            DateTime(2026, 10, 1),
            DateTime(2026, 11, 30),
          ),
        ),
      ),
      [1, 2, 3],
    );
    // All time is no filter.
    expect(
      const EntryFilter().withPeriod(const DatePeriod.all()).period,
      isNull,
    );
    expect(
      const EntryFilter().withPeriod(const DatePeriod.all()).isActive,
      isFalse,
    );
  });

  test('filters add up; clearing keeps the search', () {
    final filter = const EntryFilter(text: 'bankszamla')
        .withType(EntryType.expense)
        .withPeriod(DatePeriod.of(PeriodKind.month, DateTime(2026, 11)));
    expect(filter.isActive, isTrue);
    expect(ids(filter), [2]);
    expect(filter.cleared(), const EntryFilter(text: 'bankszamla'));
    expect(ids(filter.withType(null).withCategory(null, none: true)), isEmpty);
  });

  test('the order: by date either way, by amount with its sign (in the main '
      'currency) either way; not a filter', () {
    expect(ids(const EntryFilter(sort: EntrySort.oldest)), [3, 2, 1]);
    // The expense (-23 450) is the smallest; no EUR rate: its own amount,
    // +1250.
    expect(ids(const EntryFilter(sort: EntrySort.largest)), [1, 3, 2]);
    expect(ids(const EntryFilter(sort: EntrySort.smallest)), [2, 3, 1]);
    // 12.50 EUR at 400 is 5000 Ft.
    final withRate = FinanceState(
      accounts: state.accounts,
      categories: state.categories,
      entries: state.entries,
      rates: RateBook([
        ExchangeRate(
          source: RateSource.mnb,
          date: DateTime(2026, 10, 1),
          currency: Currency.eur,
          base: Currency.huf,
          rate: 400,
        ),
      ]),
    );
    expect(
      [
        for (final e in const EntryFilter(
          sort: EntrySort.smallest,
        ).apply(withRate, (c) => c.name))
          e.id,
      ],
      [2, 3, 1],
    );
    expect(
      [
        for (final e in const EntryFilter(
          sort: EntrySort.largest,
        ).apply(withRate, (c) => c.name))
          e.id,
      ],
      [1, 3, 2],
    );
    const sorted = EntryFilter(sort: EntrySort.largest);
    expect(sorted.isActive, isFalse);
    expect(sorted.count, 0);
    // Clearing the filters keeps the order.
    expect(sorted.withType(EntryType.income).cleared().sort, EntrySort.largest);
  });
}
