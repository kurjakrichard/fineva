import 'package:fineva/data/data_export.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice({
  InvoiceDirection direction = InvoiceDirection.outgoing,
  required int net,
  VatCode code = VatCode.aam,
  int? vat,
  DateTime? fulfillment,
  DateTime? paid,
  int? paidAmount,
}) {
  final date = fulfillment ?? DateTime(2026, 1, 10);
  final vatAmount = vat ?? Invoice.vatOf(net, code);
  return Invoice(
    direction: direction,
    issueDate: date,
    fulfillmentDate: date,
    netAmount: net,
    vatCode: code,
    vatAmount: vatAmount,
    payments: [
      if (paid != null)
        InvoicePayment(date: paid, amount: paidAmount ?? net + vatAmount),
    ],
  );
}

void main() {
  group('Invoice', () {
    test('forint amounts of a foreign currency invoice', () {
      final invoice = Invoice(
        direction: InvoiceDirection.outgoing,
        issueDate: DateTime(2026),
        fulfillmentDate: DateTime(2026),
        currency: Currency.eur,
        exchangeRate: 3897300, // 389.73 HUF/EUR
        netAmount: 10000, // 100.00 EUR
        vatCode: VatCode.eufad37,
      );
      expect(invoice.huf(invoice.netAmount), 38973);
    });

    test('the net part of a partial payment', () {
      final invoice = _invoice(
        net: 100000,
        code: VatCode.vat27,
        paid: DateTime(2026, 2),
        paidAmount: 63500,
      );
      expect(invoice.gross, 127000);
      expect(invoice.openAmount, 63500);
      expect(invoice.paidNetHuf, 50000);
    });

    test('the VAT date of the workbooks: paid within 45 days, or +45', () {
      final fulfilled = DateTime(2026, 3, 20);
      DateTime vatDate(DateTime? paid, [InvoiceDirection? direction]) =>
          Invoice.vatDateOf(
            direction ?? InvoiceDirection.outgoing,
            fulfilled,
            paid,
          );
      // Open: the fulfillment + 45 days.
      expect(vatDate(null), DateTime(2026, 5, 4));
      // Paid in time: the payment date (on the 45th day too, and before).
      expect(vatDate(DateTime(2026, 4, 2)), DateTime(2026, 4, 2));
      expect(vatDate(DateTime(2026, 5, 4)), DateTime(2026, 5, 4));
      expect(vatDate(DateTime(2026, 3, 1)), DateTime(2026, 3, 1));
      // Paid later: the fulfillment + 45 days.
      expect(vatDate(DateTime(2026, 5, 5)), DateTime(2026, 5, 4));
      // A cost: the fulfillment date.
      expect(
        vatDate(DateTime(2026, 4, 2), InvoiceDirection.incoming),
        fulfilled,
      );
    });

    test('the VAT codes of a direction and a partner location', () {
      expect(VatCode.available(InvoiceDirection.outgoing, PartnerLocation.eu), [
        VatCode.kbaet,
        VatCode.eufad37,
        VatCode.eufade,
        VatCode.eue,
      ]);
      expect(
        VatCode.available(
          InvoiceDirection.incoming,
          PartnerLocation.thirdCountry,
        ),
        [VatCode.ho, VatCode.importServices, VatCode.importGoods],
      );
      expect(
        VatCode.available(InvoiceDirection.outgoing, PartnerLocation.domestic),
        contains(VatCode.aam),
      );
    });
  });

  group('FlatRateTax', () {
    const profile = Profile(userType: UserType.soleProprietor);

    test('without revenue: the minimum contributions, as in the workbook', () {
      final tax = FlatRateTax(const [], profile, 2026);
      final q1 = tax.quarters.first;
      expect(q1.szja, 0);
      expect(q1.contributionBase, 1119600);
      expect(q1.tb, 207126);
      expect(q1.szocho, 145548);
      expect(q1.localTax, 12500);
      expect(q1.chamberFee, 5000);
      expect(q1.total, 370174);
      expect(tax.quarters[1].total, 365174);
      expect(tax.total, 1465696);
      expect(tax.revenueLimit, 38736000);
      expect(tax.taxFreeRevenue, 3521455);
    });

    test('not in main occupation there is no minimum', () {
      final tax = FlatRateTax(
        const [],
        profile.copyWith(mainOccupation: false),
        2026,
      );
      expect(tax.quarters.first.tb, 0);
      expect(tax.quarters.first.szocho, 0);
    });

    test('the SZJA is due above the tax-free income, cumulated', () {
      final tax = FlatRateTax(
        [
          for (final month in [1, 4, 7, 10])
            _invoice(net: 2000000, paid: DateTime(2026, month, 15)),
          // Not paid, or paid in another year: no revenue.
          _invoice(net: 999999),
          _invoice(net: 999999, paid: DateTime(2025, 12, 31)),
          // A cost is no revenue.
          _invoice(
            direction: InvoiceDirection.incoming,
            net: 999999,
            paid: DateTime(2026, 1, 20),
          ),
        ],
        profile,
        2026,
      );
      expect(tax.revenue, 8000000);
      expect(tax.quarters.map((q) => q.income), [
        1100000,
        1100000,
        1100000,
        1100000,
      ]);
      // 1 936 800 is tax free.
      expect(tax.quarters.map((q) => q.taxableIncome), [
        0,
        263200,
        1100000,
        1100000,
      ]);
      expect(tax.quarters.map((q) => q.szja), [0, 39480, 165000, 165000]);
      // The cumulated base stays under the minimums paid.
      expect(tax.quarters.map((q) => q.tb), [207126, 207126, 207126, 207126]);
    });

    test('a contribution base above the minimum', () {
      final tax = FlatRateTax(
        [_invoice(net: 6000000, paid: DateTime(2026, 1, 15))],
        profile,
        2026,
      );
      final q1 = tax.quarters.first;
      expect(q1.taxableIncome, 1363200);
      expect(q1.szja, 204480);
      expect(q1.contributionBase, 1363200);
      expect(q1.tb, 252192);
      expect(q1.szocho, 177216);
      expect(q1.total, 651388);
      // Nothing more to cumulate: the minimum again.
      expect(tax.quarters[1].contributionBase, 1119600);
    });

    test('the local tax band and the revenue limit', () {
      final tax = FlatRateTax(
        [_invoice(net: 40000000, paid: DateTime(2026, 3, 1))],
        profile,
        2026,
      );
      expect(tax.overLimit, isTrue);
      // Above 25 million: 2% of the revenue, a quarter each quarter.
      expect(tax.quarters.first.localTax, 200000);
    });

    test('deadlines: the 12th after the quarter, or the next workday', () {
      final tax = FlatRateTax(const [], profile, 2026);
      expect(tax.quarters.map((q) => q.deadline), [
        DateTime(2026, 4, 13), // the 12th is a Sunday
        DateTime(2026, 7, 13),
        DateTime(2026, 10, 12),
        DateTime(2027, 1, 12),
      ]);
    });

    test('payments with the NAV tax codes', () {
      final payments = FlatRateTax(const [], profile, 2026).payments(1);
      expect(payments.map((p) => p.kind.code), [
        '103',
        '258',
        '406',
        null,
        null,
      ]);
      expect(payments.last.kind, TaxKind.chamberFee);
    });
  });

  group('VatSummary', () {
    final q1 = VatReturnPeriod.ofYear(2026, VatPeriod.quarterly).first;
    final invoices = [
      _invoice(net: 100000, code: VatCode.vat27),
      _invoice(net: 10000, code: VatCode.vat5),
      _invoice(net: 200000, code: VatCode.eufad37),
      _invoice(
        direction: InvoiceDirection.incoming,
        net: 40000,
        code: VatCode.vat27,
      ),
      _invoice(
        direction: InvoiceDirection.incoming,
        net: 50000,
        code: VatCode.euServices,
      ),
      // Next quarter.
      _invoice(
        net: 999999,
        code: VatCode.vat27,
        fulfillment: DateTime(2026, 4, 1),
      ),
    ];

    test('periods and deadlines', () {
      expect(VatReturnPeriod.ofYear(2026, VatPeriod.monthly), hasLength(12));
      expect(q1.end, DateTime(2026, 4));
      expect(q1.deadline, DateTime(2026, 4, 20));
      expect(
        VatReturnPeriod.ofYear(2026, VatPeriod.yearly).single.deadline,
        DateTime(2027, 1, 20),
      );
    });

    test('a VAT registered sole proprietor deducts', () {
      final summary = VatSummary(
        invoices,
        const Profile(vatStatus: VatStatus.registered),
        q1,
      );
      expect(summary.payable[27], (base: 100000, vat: 27000));
      expect(summary.payable[5], (base: 10000, vat: 500));
      expect(summary.deductible[27], (base: 40000, vat: 10800));
      expect(summary.reverseCharge, (base: 50000, vat: 13500));
      expect(summary.exemptSales, {PartnerLocation.eu: 200000});
      // In thousands: 27 + 1 + 14 payable, 11 + 14 deductible.
      expect(summary.totalPayable, 42000);
      expect(summary.totalDeductible, 25000);
      expect(summary.balance, 17000);
    });

    test('an outgoing invoice counts in the period of its VAT date', () {
      final march = _invoice(
        net: 100000,
        code: VatCode.vat27,
        fulfillment: DateTime(2026, 3, 20),
      );
      const profile = Profile(vatStatus: VatStatus.registered);
      final q2 = VatReturnPeriod.ofYear(2026, VatPeriod.quarterly)[1];
      // Open: fulfilled in Q1, VAT date May 4.
      expect(VatSummary([march], profile, q1).payable, isEmpty);
      expect(VatSummary([march], profile, q2).payable[27]?.vat, 27000);

      // Paid on March 25: Q1.
      final paid = Invoice(
        direction: march.direction,
        issueDate: march.issueDate,
        fulfillmentDate: march.fulfillmentDate,
        netAmount: march.netAmount,
        vatCode: march.vatCode,
        vatAmount: march.vatAmount,
        payments: [
          InvoicePayment(date: DateTime(2026, 3, 25), amount: march.gross),
        ],
      );
      expect(VatSummary([paid], profile, q1).payable[27]?.vat, 27000);
    });

    test('an exempt one pays the self-assessed VAT without deduction', () {
      final summary = VatSummary(
        invoices.where((i) => i.vatCode == VatCode.euServices).toList(),
        const Profile(vatStatus: VatStatus.exempt, euReporting: true),
        q1,
      );
      expect(summary.totalPayable, 14000);
      expect(summary.totalDeductible, 0);
    });
  });

  test('KATA revenue is the paid net of the year', () {
    expect(
      kataRevenue([
        _invoice(net: 100000, paid: DateTime(2026, 5)),
        _invoice(net: 100000),
        _invoice(net: 100000, paid: DateTime(2025, 5)),
      ], 2026),
      100000,
    );
  });
}
