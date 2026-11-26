import 'dart:math' show pow;

import '../utils/utils.dart';
import 'models/models.dart';

/// The two sides of a transfer (átvezetés) of [fromAmount] from [from] to
/// [to] (of [toAmount] there, if its currency is another; the same amount
/// otherwise) on [date], worth the same in the user's [main] currency, so
/// the transfer changes no total:
///
/// * between main currency accounts: no rates;
/// * from or to the main currency: the other side's rate is what the two
///   amounts make (bought 1000 EUR for 390 000 Ft: 390);
/// * between two other currencies: [fromRate] (the day's rate, or one typed
///   in; required) gives the worth, the other side's rate is made from it.
///
/// The rates made from the amounts are the user's own (manual); they are
/// also returned in [dayRates], to be the day's rates of their currencies.
/// Null if a needed amount or rate is missing.
({Entry from, Entry to, List<ExchangeRate> dayRates})? transferSides({
  required Account from,
  required Account to,
  required int fromAmount,
  int? toAmount,
  required DateTime date,
  String note = '',
  required Currency main,
  double? fromRate,
  RateSource? fromRateSource,
}) {
  final sameCurrency = from.currency == to.currency;
  final received = sameCurrency ? fromAmount : toAmount;
  if (fromAmount <= 0 || received == null || received <= 0) return null;

  // The worth in the main currency's smallest unit, and each side's rate.
  final int worth;
  double? rateOfFrom;
  RateSource? sourceOfFrom;
  if (from.currency == main) {
    worth = fromAmount;
  } else if (to.currency == main) {
    worth = received;
  } else {
    if (fromRate == null) return null;
    rateOfFrom = fromRate;
    sourceOfFrom = fromRateSource ?? RateSource.manual;
    worth =
        (fromAmount /
                pow(10, from.currency.decimals) *
                fromRate *
                pow(10, main.decimals))
            .round();
  }
  double rateFor(Currency currency, int amount) =>
      (worth / pow(10, main.decimals)) / (amount / pow(10, currency.decimals));
  if (from.currency != main && rateOfFrom == null) {
    rateOfFrom = rateFor(from.currency, fromAmount);
    sourceOfFrom = RateSource.manual;
  }
  double? rateOfTo;
  RateSource? sourceOfTo;
  if (to.currency != main) {
    rateOfTo = sameCurrency ? rateOfFrom : rateFor(to.currency, received);
    sourceOfTo = sameCurrency ? sourceOfFrom : RateSource.manual;
  }

  Entry side(
    Account account,
    EntryType type,
    int amount,
    double? rate,
    RateSource? source,
  ) => Entry(
    accountId: account.id!,
    type: type,
    amount: amount,
    date: date,
    note: note,
    rate: rate,
    rateSource: rate == null ? null : source,
  );
  ExchangeRate dayRate(Currency currency, double rate) => ExchangeRate(
    source: RateSource.manual,
    date: date,
    currency: currency,
    base: main,
    rate: rate,
  );
  return (
    from: side(from, EntryType.expense, fromAmount, rateOfFrom, sourceOfFrom),
    to: side(to, EntryType.income, received, rateOfTo, sourceOfTo),
    dayRates: [
      if (rateOfFrom != null && sourceOfFrom == RateSource.manual)
        dayRate(from.currency, rateOfFrom),
      if (rateOfTo != null && !sameCurrency) dayRate(to.currency, rateOfTo),
    ],
  );
}
