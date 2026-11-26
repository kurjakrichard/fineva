import 'package:equatable/equatable.dart';

import '../../utils/utils.dart';
import 'db_model.dart';
import 'entry.dart';

/// A payment of an invoice (kiegyenlítés): an invoice can be paid in parts;
/// it is paid when its payments add up to its gross amount
/// (`Invoice.isPaid`). For a flat-rate sole proprietor each payment is a
/// revenue received, a line of the revenue record.
///
/// Table [table] (since schema 16), deleted with its invoice; saved with
/// the invoice (FinanceDatasource.saveInvoice: the saved ones updated, the
/// new ones inserted, the others deleted). A payment of an outgoing invoice
/// has its [recordNumber] in the revenue record.
class InvoicePayment extends Equatable implements DbModel {
  const InvoicePayment({
    this.id,
    this.invoiceId,
    required this.date,
    required this.amount,
    this.method = PaymentMethod.transfer,
    this.note = '',
    this.recordNumber,
  });

  static const String table = 'invoice_payments';

  @override
  final int? id;
  final int? invoiceId;

  /// When it came in (or went out): the revenue counts on this day.
  final DateTime date;

  /// In the smallest unit of the invoice's currency; negative for a credit
  /// note.
  final int amount;

  /// Bank transfer, cash (pénztár) or card.
  final PaymentMethod method;
  final String note;

  /// Its sorszám in the revenue record of its year (since schema 17): the
  /// payments of a user's outgoing invoices numbered in the order received
  /// (`FinanceDatasource.revenueOrder`), renumbered by the datasource after
  /// every change, whatever order they were recorded in; null for an
  /// incoming invoice's or one not saved yet. Not written by [toMap].
  final int? recordNumber;

  factory InvoicePayment.fromMap(Map<String, Object?> map) => InvoicePayment(
    id: map['id'] as int,
    invoiceId: map['invoice_id'] as int,
    date: DateTime.parse(map['date'] as String),
    amount: map['amount'] as int,
    method: PaymentMethod.values.byName(map['method'] as String),
    note: map['note'] as String,
    recordNumber: map['record_number'] as int?,
  );

  @override
  Map<String, Object?> toMap() => {
    'invoice_id': invoiceId,
    'date': Entry.dateText(date),
    'amount': amount,
    'method': method.name,
    'note': note,
  };

  InvoicePayment copyWith({
    int? invoiceId,
    DateTime? date,
    int? amount,
    PaymentMethod? method,
    String? note,
  }) => InvoicePayment(
    id: id,
    invoiceId: invoiceId ?? this.invoiceId,
    date: date ?? this.date,
    amount: amount ?? this.amount,
    method: method ?? this.method,
    note: note ?? this.note,
    recordNumber: recordNumber,
  );

  @override
  List<Object?> get props => [
    id,
    invoiceId,
    date,
    amount,
    method,
    note,
    recordNumber,
  ];
}
