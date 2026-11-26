import 'package:fineva/data/data_export.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice sale(
  String number,
  DateTime fulfilled,
  int net, {
  DateTime? paid,
  int? paidAmount,
  InvoiceDirection direction = InvoiceDirection.outgoing,
  Currency currency = Currency.huf,
  int rate = Invoice.rateScale,
}) => Invoice(
  direction: direction,
  number: number,
  issueDate: fulfilled,
  fulfillmentDate: fulfilled,
  netAmount: net,
  vatCode: VatCode.aam,
  currency: currency,
  exchangeRate: rate,
  payments: [
    if (paid != null) InvoicePayment(date: paid, amount: paidAmount ?? net),
  ],
);

void main() {
  final invoices = [
    sale('A-1', DateTime(2026, 1, 5), 650000, paid: DateTime(2026, 1, 12)),
    sale('A-2', DateTime(2026, 1, 20), 280000, paid: DateTime(2026, 2, 3)),
    // Partly paid: only what came in.
    sale(
      'A-3',
      DateTime(2026, 2, 1),
      900000,
      paid: DateTime(2026, 2, 2),
      paidAmount: 500000,
    ),
    // 1000.00 EUR at 390.
    sale(
      'A-4',
      DateTime(2026, 2, 1),
      100000,
      paid: DateTime(2026, 2, 3),
      currency: Currency.eur,
      rate: 3900000,
    ),
    // Not revenue of 2026: unpaid, paid in another year, a cost.
    sale('A-5', DateTime(2026, 3, 1), 300000),
    sale('A-0', DateTime(2025, 12, 20), 100000, paid: DateTime(2025, 12, 30)),
    sale(
      'B-1',
      DateTime(2026, 3, 1),
      50000,
      paid: DateTime(2026, 3, 2),
      direction: InvoiceDirection.incoming,
    ),
  ];

  test('the revenues received in the order received, numbered, with the '
      'running total; by month; the same as the flat-rate tax counts', () {
    final record = RevenueRecord(invoices, 2026);
    expect(record.lines.map((l) => l.invoice.number), [
      'A-1',
      'A-3',
      // The same day: in the order of the invoices.
      'A-2',
      'A-4',
    ]);
    expect(record.lines.map((l) => l.number), [1, 2, 3, 4]);
    expect(record.lines.map((l) => l.amount), [650000, 500000, 280000, 390000]);
    expect(record.lines.map((l) => l.cumulative), [
      650000,
      1150000,
      1430000,
      1820000,
    ]);
    expect(record.total, 1820000);
    expect(record.months, {1: 650000, 2: 1170000});

    const profile = Profile(name: 'EV', userType: UserType.soleProprietor);
    expect(record.total, FlatRateTax(invoices, profile, 2026).revenue);
  });

  test('an invoice paid in parts: each part a revenue of its own day, in '
      'its quarter', () {
    final invoice = Invoice(
      direction: InvoiceDirection.outgoing,
      number: 'R-1',
      issueDate: DateTime(2026, 3, 20),
      fulfillmentDate: DateTime(2026, 3, 20),
      netAmount: 900000,
      vatCode: VatCode.aam,
      payments: [
        InvoicePayment(date: DateTime(2026, 3, 25), amount: 500000),
        InvoicePayment(
          date: DateTime(2026, 4, 8),
          amount: 400000,
          method: PaymentMethod.cash,
        ),
      ],
    );
    expect(invoice.isPaid, isTrue);
    expect(invoice.paidDate, DateTime(2026, 4, 8));
    final record = RevenueRecord([invoice], 2026);
    expect(record.lines.map((l) => (l.number, l.amount, l.cumulative)), [
      (1, 500000, 500000),
      (2, 400000, 900000),
    ]);
    expect(record.lines.last.payment.method, PaymentMethod.cash);
    const profile = Profile(name: 'EV', userType: UserType.soleProprietor);
    final tax = FlatRateTax([invoice], profile, 2026);
    expect(tax.quarters.map((q) => q.revenue), [500000, 400000, 0, 0]);
    expect(kataRevenue([invoice], 2026), 900000);

    // Partly paid: open.
    final part = invoice.copyWith(payments: [invoice.payments.first]);
    expect(part.isPaid, isFalse);
    expect(part.openAmount, 400000);
    expect(part.paidNetHufIn(2026), 500000);
  });

  test("the payments can't add up to more than the invoice, nor be 0", () {
    final invoice = sale('A-1', DateTime(2026, 1, 5), 1000);
    InvoicePayment pay(int amount) =>
        InvoicePayment(date: DateTime(2026, 1, 9), amount: amount);
    checkPayments(invoice.copyWith(payments: [pay(400), pay(600)]));
    for (final wrong in [
      [pay(400), pay(601)],
      [pay(0)],
      [pay(-1)],
    ]) {
      expect(
        () => checkPayments(invoice.copyWith(payments: wrong)),
        throwsStateError,
      );
    }
    // A credit note's are negative.
    final credit = sale('J-1', DateTime(2026, 2, 1), -1000);
    checkPayments(credit.copyWith(payments: [pay(-1000)]));
    expect(
      () => checkPayments(credit.copyWith(payments: [pay(1000)])),
      throwsStateError,
    );
  });

  test('the rate date: the fulfillment, or the issue if earlier', () {
    final invoice = sale('A-1', DateTime(2026, 3, 5), 1000);
    expect(invoice.rateDate, DateTime(2026, 3, 5));
    final early = Invoice(
      direction: InvoiceDirection.outgoing,
      issueDate: DateTime(2026, 3, 2),
      fulfillmentDate: DateTime(2026, 3, 5),
      netAmount: 1000,
      vatCode: VatCode.aam,
    );
    expect(early.rateDate, DateTime(2026, 3, 2));
  });

  test('a year without revenue', () {
    final record = RevenueRecord(invoices, 2024);
    expect(record.lines, isEmpty);
    expect(record.total, 0);
    expect(record.months, isEmpty);
  });

  test('invoices only: a flat-rate, VAT exempt sole proprietor', () {
    const ev = Profile(name: 'EV', userType: UserType.soleProprietor);
    expect(ev.invoicesOnly, isTrue);
    expect(ev.incomingInvoices, isFalse);
    expect(ev.copyWith(euReporting: true).incomingInvoices, isTrue);
    for (final other in [
      const Profile(name: 'Personal'),
      ev.copyWith(vatStatus: VatStatus.registered),
      ev.copyWith(taxRegime: TaxRegime.kata),
      ev.copyWith(taxRegime: TaxRegime.itemized),
    ]) {
      expect(other.invoicesOnly, isFalse, reason: '$other');
      expect(other.incomingInvoices, isTrue);
    }
  });
}
