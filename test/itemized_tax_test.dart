import 'dart:convert';
import 'dart:io';

import 'package:fineva/data/data_export.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// The columns of the workbook's EV (cash-flow ledger) sheet as categories.
const _columns = {
  'P': TaxTreatment.revenue,
  'Q': TaxTreatment.nonTaxableIncome,
  'R': TaxTreatment.withdrawal,
  'S': TaxTreatment.szocho,
  'T': TaxTreatment.otherCost,
  'U': TaxTreatment.materialCost,
  'V': TaxTreatment.bankCost,
  'W': TaxTreatment.accountingCost,
  'X': TaxTreatment.itCost,
  'Z': TaxTreatment.nonDeductible,
  'AA': TaxTreatment.vat,
};

void main() {
  group('quarterlyDepreciation', () {
    // The ÉCS sheet's second asset: 33% from 2025-05-27.
    final asset = Asset(
      name: 'Eszköz2',
      purchaseDate: DateTime(2025, 5, 27),
      amount: 280858,
      rate: 3300,
    );

    test('by day from the purchase', () {
      // 280 858 * 33% / 365 a day. (The workbook counts one more day in
      // every quarter after the first: 91, 92, 93, 93 days.)
      const daily = 280858 * 0.33 / 365;
      final y2025 = quarterlyDepreciation(asset, 2025);
      expect(y2025[0], 0);
      // May 27 - June 30: 35 days, 8 887.42 as in the workbook.
      expect(y2025[1], 8887);
      expect(y2025[2], closeTo(daily * 92, 1));
      expect(y2025[3], closeTo(daily * 92, 1));
      final y2026 = quarterlyDepreciation(asset, 2026);
      expect(y2026[0], closeTo(daily * 90, 1));
      expect(y2026[1], closeTo(daily * 91, 1));
      expect(y2026[2], closeTo(daily * 92, 1));
      expect(y2026[3], closeTo(daily * 92, 1));
      // A whole year is the rate.
      expect(y2026.fold(0, (a, b) => a + b), closeTo(280858 * 0.33, 1));
    });

    test('until the cost is used up, never more', () {
      expect(depreciatedBy(asset, 2027), lessThan(asset.amount));
      expect(depreciatedBy(asset, 2030), asset.amount);
      expect(quarterlyDepreciation(asset, 2031), [0, 0, 0, 0]);
      expect(quarterlyDepreciation(asset, 2024), [0, 0, 0, 0]);
    });

    test('100% writes it off in the purchase quarter', () {
      final small = Asset(
        name: 'Telefon',
        purchaseDate: DateTime(2026, 8, 3),
        amount: 150000,
        rate: Asset.writeOffAtOnce,
      );
      expect(quarterlyDepreciation(small, 2026), [0, 0, 150000, 0]);
      expect(quarterlyDepreciation(small, 2027), [0, 0, 0, 0]);
    });
  });

  group('ItemizedTax', () {
    test('the test data of the workbook gives its results', () {
      final fixture = jsonDecode(
        File('test/fixtures/szja_2026_ev.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final categories = [
        for (final (i, MapEntry(key: column, value: treatment))
            in _columns.entries.indexed)
          EntryCategory(
            id: i + 1,
            name: column,
            type: treatment.type!,
            taxTreatment: treatment,
          ),
      ];
      final ids = {
        for (final (i, column) in _columns.keys.indexed) column: i + 1,
      };
      final entries = <Entry>[];
      final perQuarter = List.filled(4, 0);
      for (final row in fixture['entries']! as List) {
        final map = row as Map<String, Object?>;
        final column = map['column']! as String;
        final amount = (map['amount']! as num).toDouble();
        // Depreciation comes from the assets; these rows only offset it.
        if (column == 'Y' || (column == 'Z' && amount < 0)) continue;
        final treatment = _columns[column]!;
        final date = DateTime.parse(map['date']! as String);
        entries.add(
          Entry(
            accountId: 1,
            categoryId: ids[column],
            // A negative cost (a refund) is an entry of the other type.
            type: amount >= 0
                ? treatment.type!
                : (treatment.type == EntryType.income
                      ? EntryType.expense
                      : EntryType.income),
            amount: amount.abs().round(),
            date: date,
          ),
        );
        perQuarter[(date.month - 1) ~/ 3]++;
      }
      final expected = [
        for (final q in fixture['quarters']! as List) q as Map<String, Object?>,
      ];
      double value(Map<String, Object?> map, String key) =>
          (map[key]! as num).toDouble();

      final tax = ItemizedTax(
        entries: entries,
        categories: categories,
        accounts: const [Account(id: 1, name: 'Pénztár')],
        depreciation: [
          for (final q in expected) value(q, 'depreciation').round(),
        ],
        year: 2026,
      );

      for (var q = 0; q < 4; q++) {
        final quarter = tax.quarters[q];
        final want = expected[q];
        // Every entry was rounded to a forint.
        final slack = perQuarter[q] / 2 + 1;
        expect(quarter.revenue, closeTo(value(want, 'revenue'), slack));
        expect(quarter.costs, closeTo(value(want, 'costs'), slack));
        expect(quarter.base, closeTo(value(want, 'base'), slack));
        expect(quarter.vszja, closeTo(value(want, 'vszja'), slack * 0.09 + 1));
        expect(
          quarter.dividendBase,
          closeTo(value(want, 'dividendBase'), slack + 1),
        );
        expect(quarter.szja, closeTo(value(want, 'szja'), slack * 0.15 + 1));
      }
      final year = fixture['year']! as Map<String, Object?>;
      final slack = entries.length / 2 + 1;
      expect(tax.revenue, closeTo(value(year, 'revenue'), slack));
      expect(tax.base, closeTo(value(year, 'base'), slack));
      expect(tax.vszja, closeTo(value(year, 'vszja'), slack * 0.09 + 1));
      expect(tax.szja, closeTo(value(year, 'szja'), slack * 0.15 + 1));
      expect(tax.missingRates, 0);

      // The SZOCHO cap of the workbook: 322 800 * 24 * 13% - 585 000 paid.
      expect(tax.szochoCap, 1007136);
      expect(tax.szochoPaid, 585000);
      expect(tax.szochoOnDividend, 1007136 - 585000);
      // HIPA: 2% of the revenue (no material costs).
      expect(tax.localTax, closeTo(648689, slack * 0.02 + 1));
    });

    test('a loss is carried to the next quarter', () {
      const categories = [
        EntryCategory(
          id: 1,
          name: 'Bevétel',
          type: EntryType.income,
          taxTreatment: TaxTreatment.revenue,
        ),
        EntryCategory(
          id: 2,
          name: 'Költség',
          type: EntryType.expense,
          taxTreatment: TaxTreatment.otherCost,
        ),
        EntryCategory(id: 3, name: 'Magán', type: EntryType.expense),
      ];
      Entry entry(int category, EntryType type, int amount, int month) => Entry(
        accountId: 1,
        categoryId: category,
        type: type,
        amount: amount,
        date: DateTime(2026, month, 10),
      );
      final tax = ItemizedTax(
        entries: [
          entry(1, EntryType.income, 100000, 1),
          entry(2, EntryType.expense, 400000, 2),
          entry(1, EntryType.income, 1000000, 4),
          // Not a business entry.
          entry(3, EntryType.expense, 999999, 5),
        ],
        categories: categories,
        accounts: const [Account(id: 1, name: 'Bank')],
        depreciation: const [0, 0, 0, 0],
        year: 2026,
      );
      final q1 = tax.quarters[0];
      expect(q1.base, -300000);
      expect(q1.vszja, 0);
      expect(q1.szja, 0);
      final q2 = tax.quarters[1];
      expect(q2.lossCarried, -300000);
      expect(q2.base, 700000);
      expect(q2.vszja, 63000);
      expect(q2.dividendBase, 637000);
      expect(q2.szja, 95550);
      expect(q2.deadline, DateTime(2026, 7, 13));
      // The year offsets the loss too.
      expect(tax.base, 700000);
    });

    test('a foreign currency entry needs its exchange rate', () {
      const categories = [
        EntryCategory(
          id: 1,
          name: 'Bevétel',
          type: EntryType.income,
          taxTreatment: TaxTreatment.revenue,
        ),
      ];
      final tax = ItemizedTax(
        entries: [
          Entry(
            accountId: 1,
            categoryId: 1,
            type: EntryType.income,
            amount: 833300, // 8 333.00 EUR
            date: DateTime(2026, 1, 5),
            rate: 386.07,
          ),
          Entry(
            accountId: 1,
            categoryId: 1,
            type: EntryType.income,
            amount: 100,
            date: DateTime(2026, 1, 6),
          ),
        ],
        categories: categories,
        accounts: const [
          Account(id: 1, name: 'Bank EUR', currency: Currency.eur),
        ],
        depreciation: const [0, 0, 0, 0],
        year: 2026,
      );
      // The workbook: 8 333 * 386.07 = 3 217 121.31
      expect(tax.revenue, 3217121);
      expect(tax.missingRates, 1);
    });
  });

  test('VAT carried forward: a negative balance until it is used up', () {
    final profile = const Profile(vatStatus: VatStatus.registered);
    final periods = VatReturnPeriod.ofYear(2026, VatPeriod.quarterly);
    Invoice invoice(InvoiceDirection direction, int vat, int month) => Invoice(
      direction: direction,
      issueDate: DateTime(2026, month, 2),
      fulfillmentDate: DateTime(2026, month, 2),
      netAmount: vat * 100 ~/ 27,
      vatCode: VatCode.vat27,
      vatAmount: vat,
      payments: [InvoicePayment(date: DateTime(2026, month, 2), amount: vat)],
    );
    final invoices = [
      invoice(InvoiceDirection.incoming, 50000, 1), // Q1: -50 000
      invoice(InvoiceDirection.outgoing, 20000, 4), // Q2: +20 000
      invoice(InvoiceDirection.outgoing, 100000, 7), // Q3: +100 000
    ];
    final summaries = [
      for (final period in periods) VatSummary(invoices, profile, period),
    ];
    expect(summaries.map((s) => s.balance), [-50000, 20000, 100000, 0]);
    expect(vatCarriedIn(summaries), [0, -50000, -30000, 0]);
  });
}
