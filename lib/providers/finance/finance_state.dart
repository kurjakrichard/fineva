import 'dart:math' show pow;

import 'package:equatable/equatable.dart';

import '../../data/data_export.dart';
import '../../utils/utils.dart';
import 'date_period.dart';
import 'rate_book.dart';

/// A day of an account's entries: the balance at the end of [day] and the
/// day's entries, the newest first.
typedef AccountDay = ({DateTime day, int balance, List<Entry> entries});

/// Everything the pages show: the users, and the current user's accounts,
/// categories, entries and balances.
class FinanceState extends Equatable {
  const FinanceState({
    this.profiles = const [],
    this.profile,
    this.accounts = const [],
    this.categories = const [],
    this.entries = const [],
    this.balances = const {},
    this.invoices = const [],
    this.assets = const [],
    this.rates = const RateBook.empty(),
    this.loaded = false,
    this.error,
  });

  const FinanceState.initial() : this();

  /// Every user. Empty until the first onboarding is finished.
  final List<Profile> profiles;

  /// The current user, null if there is none. The rest of the state is
  /// theirs.
  final Profile? profile;

  final List<Account> accounts;
  final List<EntryCategory> categories;

  /// The newest first.
  final List<Entry> entries;

  /// Balance of every account by id.
  final Map<int, int> balances;

  /// The current user's invoices (sole proprietors), the newest first.
  final List<Invoice> invoices;

  /// The current user's assets (itemized taxation), the newest first.
  final List<Asset> assets;

  /// Every exchange rate (shared by the users).
  final RateBook rates;

  /// True once the first load finished (ok or failed).
  final bool loaded;

  /// Set when the last load failed.
  final String? error;

  Account? account(int id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  EntryCategory? category(int? id) {
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// The kind of categories the current user sees: a sole proprietor's
  /// business ones, otherwise the personal ones.
  CategoryScope get categoryScope => (profile?.isSoleProprietor ?? false)
      ? CategoryScope.business
      : CategoryScope.personal;

  /// The categories of the current user's kind.
  List<EntryCategory> get visibleCategories => [
    for (final category in categories)
      if (category.scope == categoryScope) category,
  ];

  int balanceOf(Account account) => balances[account.id] ?? 0;

  /// The two sides of the transfer with [transferId]: the one it goes
  /// from (an expense) and the one it goes to; null if not both are there.
  ({Entry from, Entry to})? transferSides(int transferId) {
    Entry? from;
    Entry? to;
    for (final entry in entries) {
      if (entry.transferId != transferId) continue;
      if (entry.type == EntryType.expense) {
        from = entry;
      } else {
        to = entry;
      }
    }
    return from == null || to == null ? null : (from: from, to: to);
  }

  /// The account at the other side of [entry]'s transfer; null if it isn't
  /// one.
  Account? transferPeer(Entry entry) {
    final transferId = entry.transferId;
    if (transferId == null) return null;
    for (final other in entries) {
      if (other.transferId == transferId && other.id != entry.id) {
        return account(other.accountId);
      }
    }
    return null;
  }

  /// The balance of [entry]'s account just after it, as on a bank
  /// statement: the account's entries up to it in the order of [ledger]
  /// (by day, the day's opening entry first, then as recorded). Null if it
  /// isn't saved.
  int? balanceAfter(Entry entry) {
    var balance = 0;
    // The oldest first.
    for (final other in entries.reversed) {
      if (other.accountId != entry.accountId) continue;
      balance += other.signedAmount;
      if (other.id == entry.id) return balance;
    }
    return null;
  }

  /// [account]'s opening entries ([Entry.opening]); usually one or none.
  List<Entry> openingsOf(Account account) => [
    for (final entry in entries)
      if (entry.accountId == account.id && entry.opening) entry,
  ];

  /// Why [account] can't be closed on [day]: its balance then (it must be
  /// 0) and how many entries it has after it (there must be none). Both 0:
  /// it can be.
  ({int balance, int later}) closingCheck(Account account, DateTime day) {
    final end = DateTime(day.year, day.month, day.day + 1);
    var balance = 0;
    var later = 0;
    for (final entry in entries) {
      if (entry.accountId != account.id) continue;
      if (entry.date.isBefore(end)) {
        balance += entry.signedAmount;
      } else {
        later++;
      }
    }
    return (balance: balance, later: later);
  }

  /// The day of [account]'s last entry; null without entries.
  DateTime? lastEntryDay(Account account) {
    for (final entry in entries) {
      // The newest first.
      if (entry.accountId == account.id) return entry.date;
    }
    return null;
  }

  /// The accounts new entries can go on: the open ones, and [keep] (an
  /// entry's own, even if closed since).
  List<Account> openAccounts({int? keep}) => [
    for (final account in accounts)
      if (!account.isClosed || account.id == keep) account,
  ];

  /// How many entries [account] has; it can only be deleted without any.
  int entryCountOf(Account account) =>
      entries.where((e) => e.accountId == account.id).length;

  /// [account]'s entries by day, the newest day first, each day with the
  /// balance at its end and its entries (the newest first, as [entries]).
  List<AccountDay> ledger(Account account) {
    // The oldest first, to add them up.
    final own = [
      for (final entry in entries.reversed)
        if (entry.accountId == account.id) entry,
    ];
    final days = <AccountDay>[];
    var balance = 0;
    var start = 0;
    for (var i = 0; i < own.length; i++) {
      balance += own[i].signedAmount;
      final last = i + 1 == own.length || own[i + 1].date != own[i].date;
      if (!last) continue;
      days.add((
        day: own[i].date,
        balance: balance,
        entries: own.sublist(start, i + 1).reversed.toList(),
      ));
      start = i + 1;
    }
    return days.reversed.toList();
  }

  /// The currency the dashboard and the statistics show everything in.
  Currency get mainCurrency => profile?.mainCurrency ?? Currency.huf;

  RateSource get rateSource => profile?.rateSourceInUse ?? RateSource.mnb;

  /// Whether [currency] can be converted to [mainCurrency] on [date].
  bool hasRate(Currency currency, DateTime date) =>
      currency == mainCurrency ||
      rates.quote(currency, mainCurrency, date, rateSource) != null;

  /// [amount] of [from] in [mainCurrency] at the rate of [date]; null if
  /// there is no rate for it.
  int? toMain(int amount, Currency from, DateTime date) {
    final main = mainCurrency;
    if (from == main) return amount;
    final quote = rates.quote(from, main, date, rateSource);
    return quote == null ? null : _atRate(amount, from, quote.rate);
  }

  /// [amount] of [from] in [mainCurrency], one unit of [from] being worth
  /// [rate] of it.
  int _atRate(int amount, Currency from, double rate) =>
      (amount / pow(10, from.decimals) * rate * pow(10, mainCurrency.decimals))
          .round();

  /// [entry]'s amount (signed) in [mainCurrency]: at its own rate
  /// ([Entry.rate]), or if it has none at the rate of its day. Null if
  /// there is no rate for it.
  int? entryInMain(Entry entry) {
    final currency = account(entry.accountId)?.currency ?? mainCurrency;
    if (currency == mainCurrency) return entry.signedAmount;
    final rate = entry.rate;
    if (rate != null) return _atRate(entry.signedAmount, currency, rate);
    return toMain(entry.signedAmount, currency, entry.date);
  }

  /// The rate offered for a new entry of [currency] on [date]: the day's
  /// (the last typed in, otherwise the downloaded one); null for the main
  /// currency, or without rates.
  RateQuote? offeredRate(Currency currency, DateTime date) =>
      currency == mainCurrency
      ? null
      : rates.quote(currency, mainCurrency, date, rateSource);

  /// The sum of [balances] (by account id; the opening balance if missing)
  /// in [mainCurrency] at the rates of [date], and the currencies left out
  /// for want of a rate.
  ({int total, Set<Currency> missing}) totalInMain(
    Map<int, int> balances,
    DateTime date,
  ) {
    var total = 0;
    final missing = <Currency>{};
    for (final account in accounts) {
      final balance = balances[account.id] ?? 0;
      final value = toMain(balance, account.currency, date);
      if (value == null) {
        missing.add(account.currency);
      } else {
        total += value;
      }
    }
    return (total: total, missing: missing);
  }

  /// The balance of every account by id at the end of [day]: its entries
  /// up to that day (the opening one too).
  Map<int, int> balancesAt(DateTime day) {
    final end = DateTime(day.year, day.month, day.day + 1);
    final result = {for (final account in accounts) ?account.id: 0};
    for (final entry in entries) {
      if (!entry.date.isBefore(end)) continue;
      result.update(
        entry.accountId,
        (balance) => balance + entry.signedAmount,
        ifAbsent: () => entry.signedAmount,
      );
    }
    return result;
  }

  /// Income and expenses of the entries in [period] in [mainCurrency] (see
  /// [entryInMain]), and the currencies left out for want of a rate.
  ({int income, int expense, Set<Currency> missing}) periodTotals(
    DatePeriod period,
  ) {
    var income = 0;
    var expense = 0;
    final missing = <Currency>{};
    for (final entry in entries) {
      // The opening balance and a transfer are no income or expense.
      if (entry.opening || entry.isTransfer || !period.contains(entry.date)) {
        continue;
      }
      final value = entryInMain(entry);
      if (value == null) {
        final currency = account(entry.accountId)?.currency;
        if (currency != null) missing.add(currency);
      } else if (value >= 0) {
        income += value;
      } else {
        expense -= value;
      }
    }
    return (income: income, expense: expense, missing: missing);
  }

  /// How the balance of every account (in [mainCurrency]) changed in
  /// [period]: from [opening] (the end of the day before; 0 for all time) to
  /// [closing] (the end of its last day; now for all time), each at the
  /// last rate of its day, as the [result] (income - expenses, at the
  /// entries' own rates), the opening entries ([openings]) and the
  /// [revaluation]: the rest, made by the rates changing.
  ({int opening, int closing, int result, int openings, int revaluation})
  periodChange(DatePeriod period, {DateTime? today}) {
    final start = period.start;
    final dayBefore = start == null
        ? null
        : DateTime(start.year, start.month, start.day - 1);
    final opening = dayBefore == null
        ? 0
        : totalInMain(balancesAt(dayBefore), dayBefore).total;
    final last = period.last;
    // All time: every entry, at today's rates.
    final closing = last == null
        ? totalInMain(balancesAt(DateTime(9999)), today ?? currentDay()).total
        : totalInMain(balancesAt(last), last).total;
    final totals = periodTotals(period);
    final result = totals.income - totals.expense;
    var openings = 0;
    for (final entry in entries) {
      if (!entry.opening || !period.contains(entry.date)) continue;
      openings += entryInMain(entry) ?? 0;
    }
    return (
      opening: opening,
      closing: closing,
      result: result,
      openings: openings,
      revaluation: closing - opening - result - openings,
    );
  }

  FinanceState copyWith({bool? loaded, String? error}) => FinanceState(
    profiles: profiles,
    profile: profile,
    accounts: accounts,
    categories: categories,
    entries: entries,
    balances: balances,
    invoices: invoices,
    assets: assets,
    rates: rates,
    loaded: loaded ?? this.loaded,
    error: error,
  );

  @override
  List<Object?> get props => [
    profiles,
    profile,
    accounts,
    categories,
    entries,
    balances,
    invoices,
    assets,
    rates,
    loaded,
    error,
  ];

  /// Short form for the provider log.
  @override
  String toString() =>
      'FinanceState(users: ${profiles.length}, user: ${profile?.id}, '
      'accounts: ${accounts.length}, '
      'categories: ${categories.length}, entries: ${entries.length}, '
      'loaded: $loaded, error: $error)';
}
