import 'dart:math' show pow;

import 'package:intl/intl.dart';

/// Currencies an account can have: the forint and every currency both the
/// MNB and the ECB publish a rate for (see `RateBook`). Stored by [code].
///
/// Amounts are stored as whole numbers of the currency's smallest unit
/// ([decimals] digits after the point): forints for HUF (no fillér), cents
/// for EUR. So sums are exact, without floating point rounding.
enum Currency {
  huf('HUF', 'Ft', 0),
  eur('EUR', '€', 2),
  usd('USD', r'$', 2),
  gbp('GBP', '£', 2),
  chf('CHF', 'CHF', 2),
  czk('CZK', 'Kč', 2),
  pln('PLN', 'zł', 2),
  ron('RON', 'lei', 2),
  sek('SEK', 'SEK', 2),
  nok('NOK', 'NOK', 2),
  dkk('DKK', 'DKK', 2),
  isk('ISK', 'ISK', 0),
  tryLira('TRY', '₺', 2),
  jpy('JPY', '¥', 0),
  cny('CNY', 'CN¥', 2),
  hkd('HKD', r'HK$', 2),
  krw('KRW', '₩', 0),
  sgd('SGD', r'S$', 2),
  inr('INR', '₹', 2),
  idr('IDR', 'Rp', 2),
  myr('MYR', 'RM', 2),
  php('PHP', '₱', 2),
  thb('THB', '฿', 2),
  ils('ILS', '₪', 2),
  aud('AUD', r'A$', 2),
  nzd('NZD', r'NZ$', 2),
  cad('CAD', r'CA$', 2),
  mxn('MXN', r'MX$', 2),
  brl('BRL', r'R$', 2),
  zar('ZAR', 'R', 2);

  const Currency(this.code, this.symbol, this.decimals);

  /// ISO 4217 code, stored in the database.
  final String code;
  final String symbol;
  final int decimals;

  /// The currency with [code]; HUF for an unknown code.
  static Currency fromCode(String code) =>
      values.firstWhere((c) => c.code == code, orElse: () => huf);

  /// 123456 (cents) -> "1 234,56 €" in Hungarian, "€1,234.56" in English.
  String format(int amount, String locale) => NumberFormat.currency(
    locale: locale,
    symbol: symbol,
    decimalDigits: decimals,
  ).format(amount / pow(10, decimals));

  /// The amount typed into a field: "1 234,5" or "1234.50" -> 123450
  /// (cents). Spaces are ignored, both ',' and '.' work as the decimal
  /// point. Null if it isn't a number.
  int? parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    if (!RegExp(r'^-?\d*\.?\d*$').hasMatch(cleaned)) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return (value * pow(10, decimals)).round();
  }

  /// [amount] as editable text, without symbol and grouping: 123450 ->
  /// "1234.50" (cents), 1234 -> "1234" (forints).
  String toInput(int amount) =>
      (amount / pow(10, decimals)).toStringAsFixed(decimals);

  /// [amount] (in the smallest unit) in forints at [exchangeRate] (HUF per
  /// unit times [exchangeRateScale]).
  int toHuf(int amount, int exchangeRate) => this == huf
      ? amount
      : (amount * exchangeRate / (pow(10, decimals) * exchangeRateScale))
            .round();
}

/// Exchange rates are stored as HUF per unit times this: 389.73 HUF/EUR is
/// 3897300.
const int exchangeRateScale = 10000;

/// "389,73" or "389.73" -> 3897300; null if it isn't a positive number.
int? parseExchangeRate(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || value <= 0) return null;
  return (value * exchangeRateScale).round();
}

/// 3897300 -> "389.73".
String exchangeRateText(int rate) =>
    (rate / exchangeRateScale).toString().replaceAll(RegExp(r'\.0+$'), '');

/// [rate] as text to edit: at least four significant digits, without
/// trailing zeros: 373.22, 2.1431, 0.002677.
String rateInput(double rate) {
  final digits = rate >= 100
      ? 2
      : rate >= 1
      ? 4
      : 6;
  final text = rate.toStringAsFixed(digits);
  return text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

/// A rate typed in: "373,22" or "373.22"; null unless a positive number.
double? parseRate(String text) {
  final value = double.tryParse(
    text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'),
  );
  return value == null || value <= 0 ? null : value;
}
