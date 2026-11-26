import 'package:equatable/equatable.dart';

import 'db_model.dart';
import 'entry.dart';

/// A fixed asset of a sole proprietor taxed on itemized costs (eszköz): its
/// cost is written off as depreciation (értékcsökkenés), see
/// `quarterlyDepreciation`.
class Asset extends Equatable implements DbModel {
  const Asset({
    this.id,
    this.userId,
    required this.name,
    required this.purchaseDate,
    this.invoiceNumber = '',
    this.supplier = '',
    required this.amount,
    required this.rate,
  });

  static const String table = 'assets';

  /// [rate] of an asset written off at once (kisértékű eszköz).
  static const int writeOffAtOnce = 10000;

  @override
  final int? id;

  /// The user it belongs to. FinanceNotifier sets it when saving.
  final int? userId;
  final String name;

  /// Beszerzés / üzembe helyezés: depreciation runs from this day.
  final DateTime purchaseDate;
  final String invoiceNumber;
  final String supplier;

  /// Cost in forints.
  final int amount;

  /// Yearly depreciation rate in basis points: 3300 is 33%;
  /// [writeOffAtOnce] writes it off in the purchase quarter.
  final int rate;

  factory Asset.fromMap(Map<String, Object?> map) => Asset(
    id: map['id'] as int,
    userId: map['user_id'] as int,
    name: map['name'] as String,
    purchaseDate: DateTime.parse(map['purchase_date'] as String),
    invoiceNumber: map['invoice_number'] as String,
    supplier: map['supplier'] as String,
    amount: map['amount'] as int,
    rate: map['rate'] as int,
  );

  @override
  Map<String, Object?> toMap() => {
    'user_id': userId,
    'name': name,
    'purchase_date': Entry.dateText(purchaseDate),
    'invoice_number': invoiceNumber,
    'supplier': supplier,
    'amount': amount,
    'rate': rate,
  };

  Asset copyWith({int? userId}) => Asset(
    id: id,
    userId: userId ?? this.userId,
    name: name,
    purchaseDate: purchaseDate,
    invoiceNumber: invoiceNumber,
    supplier: supplier,
    amount: amount,
    rate: rate,
  );

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    purchaseDate,
    invoiceNumber,
    supplier,
    amount,
    rate,
  ];
}
