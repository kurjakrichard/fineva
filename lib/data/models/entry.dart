import 'package:equatable/equatable.dart';

import '../../utils/utils.dart';
import 'db_model.dart';

/// One income or expense on an account, or its opening balance
/// ([opening]): a positive one as income, a negative one as expense.
class Entry extends Equatable implements DbModel {
  const Entry({
    this.id,
    required this.accountId,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
    this.rate,
    this.rateSource,
    this.invoiceId,
    this.opening = false,
    this.transferId,
  });

  static const String table = 'entries';

  @override
  final int? id;
  final int accountId;

  /// Null: no category (also after its category was deleted).
  final int? categoryId;
  final EntryType type;

  /// Always positive, in the smallest unit of the account's currency; [type]
  /// tells whether it adds to or takes from the balance.
  final int amount;

  /// The day only, without time.
  final DateTime date;
  final String note;

  /// On an account of another currency than the user's main one: how many
  /// units of the main currency one unit is worth, on the entry's day (since
  /// schema 12; offered from the rates, see [rateSource]); the dashboard
  /// and the statistics count the entry at it. Null on a main currency
  /// account, or if not given yet.
  final double? rate;

  /// Where [rate] came from: downloaded (MNB, ECB), or typed in (manual:
  /// it is then that day's rate). Null if not known (an invoice's
  /// payment, or older data).
  final RateSource? rateSource;

  /// [rate] as HUF per unit times [exchangeRateScale], for the business
  /// taxes in forints (a sole proprietor's main currency is HUF).
  int? get exchangeRate {
    final rate = this.rate;
    return rate == null ? null : (rate * exchangeRateScale).round();
  }

  /// The invoice whose payment this entry books; it is changed and deleted
  /// with the invoice, not by itself.
  final int? invoiceId;

  /// The account's opening balance (since schema 11): it counts in the
  /// balances, not in the income and expenses; no category. An account can
  /// only be deleted without entries, so this one too must be deleted
  /// first.
  final bool opening;

  /// The transfer (átvezetés) this entry is a side of (since schema 13): an
  /// expense on the account it goes from, an income on the one it goes to,
  /// the same worth in the main currency. It counts in the balances, not in
  /// the income and expenses; changed and deleted as one.
  final int? transferId;

  /// A side of a transfer.
  bool get isTransfer => transferId != null;

  /// [amount] in forints on an account of [currency]; null if a foreign
  /// currency entry has no [exchangeRate].
  int? huf(Currency currency) {
    if (currency == Currency.huf) return amount;
    final rate = exchangeRate;
    return rate == null ? null : currency.toHuf(amount, rate);
  }

  /// [amount] with its sign: negative for an expense.
  int get signedAmount => type == EntryType.income ? amount : -amount;

  factory Entry.fromMap(Map<String, Object?> map) => Entry(
    id: map['id'] as int,
    accountId: map['account_id'] as int,
    categoryId: map['category_id'] as int?,
    type: EntryType.values.byName(map['type'] as String),
    amount: map['amount'] as int,
    date: DateTime.parse(map['date'] as String),
    note: map['note'] as String,
    rate: (map['rate'] as num?)?.toDouble(),
    rateSource: switch (map['rate_source']) {
      final String name => RateSource.values.byName(name),
      _ => null,
    },
    invoiceId: map['invoice_id'] as int?,
    opening: map['opening'] == 1,
    transferId: map['transfer_id'] as int?,
  );

  @override
  Map<String, Object?> toMap() => {
    'account_id': accountId,
    'category_id': categoryId,
    'type': type.name,
    'amount': amount,
    'date': dateText(date),
    'note': note,
    'rate': rate,
    'rate_source': rateSource?.name,
    'invoice_id': invoiceId,
    'opening': opening ? 1 : 0,
    'transfer_id': transferId,
  };

  /// The same entry at another [rate] (with its [rateSource]).
  Entry withRate(double? rate, RateSource? rateSource) => Entry(
    id: id,
    accountId: accountId,
    categoryId: categoryId,
    type: type,
    amount: amount,
    date: date,
    note: note,
    rate: rate,
    rateSource: rateSource,
    invoiceId: invoiceId,
    opening: opening,
    transferId: transferId,
  );

  /// The day as stored in the database: 2026-11-22.
  static String dateText(DateTime date) => DateTime(
    date.year,
    date.month,
    date.day,
  ).toIso8601String().substring(0, 10);

  @override
  List<Object?> get props => [
    id,
    accountId,
    categoryId,
    type,
    amount,
    date,
    note,
    rate,
    rateSource,
    invoiceId,
    opening,
    transferId,
  ];
}
