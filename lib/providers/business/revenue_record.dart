import '../../data/data_export.dart';
import '../../utils/utils.dart';

/// A line of the revenue record: a revenue received, a [payment] of an
/// [invoice].
class RevenueLine {
  const RevenueLine({
    required this.number,
    required this.invoice,
    required this.payment,
    required this.cumulative,
  });

  /// Sorszám: 1, 2, ... in the year, in the order received; the stored
  /// one ([InvoicePayment.recordNumber], renumbered by the database after
  /// every change).
  final int number;
  final Invoice invoice;
  final InvoicePayment payment;

  /// When it was received.
  DateTime get date => payment.date;

  /// The revenue, in forints: the net part of the payment at the invoice's
  /// rate ([Invoice.netHuf]).
  int get amount => invoice.netHuf(payment.amount);

  /// The revenue of the year up to and with this line.
  final int cumulative;
}

/// The revenue record (bevételi nyilvántartás) of a flat-rate sole
/// proprietor for [year]: the revenues received (the payments of the
/// outgoing invoices, an invoice paid in parts once for each), in the order
/// received, numbered (the stored sorszám), with the running total. A revenue counts on the day
/// it is received, with its net amount in forints at the invoice's rate
/// (of its fulfillment, see [Invoice.rateDate]): the same as [FlatRateTax]
/// counts.
class RevenueRecord {
  factory RevenueRecord(List<Invoice> invoices, int year) {
    final received = [
      for (final invoice in invoices)
        if (invoice.direction == InvoiceDirection.outgoing)
          for (final payment in invoice.payments)
            if (payment.date.year == year) (invoice, payment),
    ];
    // In the order received; on a day in the order of the invoices, then
    // as recorded (the database's `FinanceDatasource.revenueOrder`).
    int compare(int a, int b) => a.compareTo(b);
    received.sort(
      (a, b) => [
        a.$2.date.compareTo(b.$2.date),
        a.$1.fulfillmentDate.compareTo(b.$1.fulfillmentDate),
        a.$1.number.compareTo(b.$1.number),
        // Not saved yet: after the saved ones.
        compare(a.$2.id ?? 1 << 62, b.$2.id ?? 1 << 62),
      ].firstWhere((c) => c != 0, orElse: () => 0),
    );
    var cumulative = 0;
    return RevenueRecord._(year, [
      for (final (i, (invoice, payment)) in received.indexed)
        RevenueLine(
          number: payment.recordNumber ?? i + 1,
          invoice: invoice,
          payment: payment,
          cumulative: cumulative += invoice.netHuf(payment.amount),
        ),
    ]);
  }

  RevenueRecord._(this.year, this.lines);

  final int year;
  final List<RevenueLine> lines;

  /// The revenue of the year.
  int get total => lines.isEmpty ? 0 : lines.last.cumulative;

  /// The revenue of each month (1-12) that has some.
  Map<int, int> get months {
    final months = <int, int>{};
    for (final line in lines) {
      months.update(
        line.date.month,
        (sum) => sum + line.amount,
        ifAbsent: () => line.amount,
      );
    }
    return months;
  }
}
