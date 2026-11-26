import 'package:equatable/equatable.dart';

import '../../utils/utils.dart';
import 'db_model.dart';
import 'entry.dart';

/// Where money is kept: cash, a bank account, a card, savings.
class Account extends Equatable implements DbModel {
  const Account({
    this.id,
    this.userId,
    required this.name,
    this.type = AccountType.cash,
    this.currency = Currency.huf,
    this.description = '',
    this.bankAccount = '',
    this.swift = '',
    this.closedDate,
  });

  static const String table = 'accounts';

  @override
  final int? id;

  /// The user ([Profile]) the account belongs to. FinanceNotifier sets it
  /// when saving.
  final int? userId;
  final String name;
  final AccountType type;

  /// Every entry of the account is in this currency. The balance is the sum
  /// of the entries, the opening one ([Entry.opening]) too; the table's
  /// old `initial_balance` column is 0 since schema 11.
  final Currency currency;

  /// Anything about the account; optional (since schema 14, as the next
  /// two).
  final String description;

  /// The account number: a Hungarian one (12345678-12345678[-12345678]) or
  /// an IBAN in groups of four (see [parseBankAccount]); empty if not given.
  final String bankAccount;

  /// The bank's SWIFT / BIC code (see [parseSwift]); empty if not given.
  final String swift;

  /// The day it was closed (no entries after it, its balance 0 then); null
  /// while open. A closed account keeps its entries; it is left out where
  /// new ones are recorded.
  final DateTime? closedDate;

  bool get isClosed => closedDate != null;

  factory Account.fromMap(Map<String, Object?> map) => Account(
    id: map['id'] as int,
    userId: map['user_id'] as int?,
    name: map['name'] as String,
    type: AccountType.values.byName(map['type'] as String),
    currency: Currency.fromCode(map['currency'] as String),
    description: map['description'] as String? ?? '',
    bankAccount: map['bank_account'] as String? ?? '',
    swift: map['swift'] as String? ?? '',
    closedDate: switch (map['closed_date']) {
      final String day => DateTime.parse(day),
      _ => null,
    },
  );

  @override
  Map<String, Object?> toMap() => {
    'user_id': userId,
    'name': name,
    'type': type.name,
    'currency': currency.code,
    'description': description,
    'bank_account': bankAccount,
    'swift': swift,
    'closed_date': switch (closedDate) {
      final day? => Entry.dateText(day),
      null => null,
    },
  };

  Account copyWith({
    int? userId,
    String? name,
    AccountType? type,
    Currency? currency,
    String? description,
    String? bankAccount,
    String? swift,
    DateTime? Function()? closedDate,
  }) => Account(
    id: id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    type: type ?? this.type,
    currency: currency ?? this.currency,
    description: description ?? this.description,
    bankAccount: bankAccount ?? this.bankAccount,
    swift: swift ?? this.swift,
    closedDate: closedDate == null ? this.closedDate : closedDate(),
  );

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    type,
    currency,
    description,
    bankAccount,
    swift,
    closedDate,
  ];
}
