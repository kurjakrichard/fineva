import 'package:equatable/equatable.dart';

import '../../utils/utils.dart';
import 'db_model.dart';
import 'entry.dart';

/// A published or typed in exchange rate: on [date], one unit of [currency]
/// is worth [rate] units of [base]. The MNB's have base HUF; the ECB's are
/// stored the same way, as the value of one unit in EUR (the ECB publishes
/// units per EUR); a manual one has the base it was typed in.
///
/// Rates are shared by every user. They aren't amounts, so [rate] is a
/// double; what it converts is rounded to the smallest unit.
class ExchangeRate extends Equatable implements DbModel {
  const ExchangeRate({
    this.id,
    required this.source,
    required this.date,
    required this.currency,
    required this.base,
    required this.rate,
  });

  static const String table = 'exchange_rates';

  @override
  final int? id;
  final RateSource source;
  final DateTime date;
  final Currency currency;
  final Currency base;
  final double rate;

  factory ExchangeRate.fromMap(Map<String, Object?> map) => ExchangeRate(
    id: map['id'] as int,
    source: RateSource.values.byName(map['source'] as String),
    date: DateTime.parse(map['date'] as String),
    currency: Currency.fromCode(map['currency'] as String),
    base: Currency.fromCode(map['base'] as String),
    rate: (map['rate'] as num).toDouble(),
  );

  @override
  Map<String, Object?> toMap() => {
    'source': source.name,
    'date': Entry.dateText(date),
    'currency': currency.code,
    'base': base.code,
    'rate': rate,
  };

  @override
  List<Object?> get props => [id, source, date, currency, base, rate];
}
