import 'dart:math' show max;

import '../../data/data_export.dart';
import '../../utils/utils.dart';
import 'tax_year.dart';

/// One quarter of flat-rate taxation (átalányadózás). Amounts in forints.
class FlatRateQuarter {
  const FlatRateQuarter({
    required this.quarter,
    required this.revenue,
    required this.income,
    required this.taxableIncome,
    required this.contributionBase,
    required this.szochoBase,
    required this.szja,
    required this.tb,
    required this.szocho,
    required this.localTax,
    required this.chamberFee,
    required this.deadline,
  });

  /// 1-4.
  final int quarter;

  /// The paid net revenue of the quarter.
  final int revenue;

  /// Revenue minus the cost ratio.
  final int income;

  /// The costs counted: the cost ratio of the revenue ([revenue] -
  /// [income]).
  int get cost => revenue - income;

  /// The part of the income above the yearly tax-free income: the base of
  /// the SZJA (átalányadó alap).
  final int taxableIncome;
  int get taxFreeIncome => income - taxableIncome;

  /// TB contribution base (járulékalap), at least the minimum in main
  /// occupation.
  final int contributionBase;
  final int szochoBase;

  final int szja;
  final int tb;
  final int szocho;

  /// Helyi iparűzési adó (paid to the municipality).
  final int localTax;

  /// Kamarai hozzájárulás.
  final int chamberFee;

  /// When the quarter's taxes are due: the 12th of the next month.
  final DateTime deadline;

  int get total => szja + tb + szocho + localTax + chamberFee;
}

/// A tax to pay: its NAV tax code (adónem) and bank account, if it goes to
/// NAV.
typedef TaxPayment = ({TaxKind kind, int amount});

enum TaxKind {
  szja('103', '10032000-06056353'),
  szocho('258', '10032000-06055912'),
  tb('406', '10032000-06055802'),
  localTax(null, null),
  chamberFee(null, '12100011-10639683');

  const TaxKind(this.code, this.account);

  /// NAV adónem kód.
  final String? code;

  /// The account to transfer it to; the municipality's for the local tax.
  final String? account;
}

/// Flat-rate taxation of [year] from the paid outgoing invoices, as the
/// "Átalányadózás" sheet of the income record workbooks calculates it:
/// revenue counts in the month it was paid (each payment of an invoice in
/// its own), the income is the revenue
/// minus the cost ratio, the SZJA is due on the income above half of the
/// yearly minimum wage, the contributions on the same (cumulated), at least
/// on the minimum in main occupation.
class FlatRateTax {
  FlatRateTax(List<Invoice> invoices, Profile profile, int year)
    : taxYear = TaxYear.of(year),
      costRatio = profile.costRatio,
      mainOccupation = profile.mainOccupation {
    final revenue = List.filled(12, 0);
    for (final invoice in invoices) {
      if (invoice.direction != InvoiceDirection.outgoing) continue;
      // Each payment in the month it came in.
      for (final payment in invoice.payments) {
        if (payment.date.year != year) continue;
        revenue[payment.date.month - 1] += invoice.netHuf(payment.amount);
      }
    }
    monthlyRevenue = revenue;
    _calculate();
  }

  final TaxYear taxYear;
  final int costRatio;
  final bool mainOccupation;

  /// The paid net revenue of each month.
  late final List<int> monthlyRevenue;
  late final List<FlatRateQuarter> quarters;

  int get revenue => monthlyRevenue.fold(0, (sum, r) => sum + r);
  int get revenueLimit => taxYear.flatRateRevenueLimit;
  bool get overLimit => revenue > revenueLimit;

  /// The revenue up to which no SZJA is due.
  int get taxFreeRevenue =>
      (taxYear.taxFreeIncome * 100 / (100 - costRatio)).round();

  int get total => quarters.fold(0, (sum, q) => sum + q.total);

  void _calculate() {
    final taxFree = taxYear.taxFreeIncome;
    final minBase = mainOccupation ? 3 * taxYear.guaranteedMinimumWage : 0;
    // The yearly revenue decides the local tax base (bands of the
    // simplified base, or the revenue above 25 million).
    final yearRevenue = revenue;
    final localTaxBase = yearRevenue > 25000000
        ? yearRevenue
        : yearRevenue <= 12000000
        ? 2500000
        : yearRevenue <= 18000000
        ? 6000000
        : 8500000;

    var cumulativeIncome = 0.0;
    var taxableBefore = 0.0; // up to the previous quarter
    var contributionBefore = 0; // the bases of the previous quarters
    var szochoBefore = 0;
    quarters = [
      for (var q = 1; q <= 4; q++)
        () {
          var quarterRevenue = 0;
          var quarterIncome = 0.0;
          for (var m = (q - 1) * 3; m < q * 3; m++) {
            quarterRevenue += monthlyRevenue[m];
            quarterIncome += monthlyRevenue[m] * (100 - costRatio) / 100;
          }
          cumulativeIncome += quarterIncome;
          final cumulativeTaxable = max(0.0, cumulativeIncome - taxFree);
          final taxable = cumulativeTaxable - taxableBefore;
          taxableBefore = cumulativeTaxable;

          final contributionBase = max(
            minBase,
            max(0, cumulativeTaxable.round() - contributionBefore),
          );
          contributionBefore += contributionBase;
          final szochoBase = max(
            minBase,
            max(0, cumulativeTaxable.round() - szochoBefore),
          );
          szochoBefore += szochoBase;

          final year = taxYear.year;
          return FlatRateQuarter(
            quarter: q,
            revenue: quarterRevenue,
            income: quarterIncome.round(),
            taxableIncome: taxable.round(),
            contributionBase: contributionBase,
            szochoBase: szochoBase,
            szja: TaxYear.percent(taxable, TaxYear.szjaRate),
            tb: TaxYear.percent(contributionBase, TaxYear.tbRate),
            szocho: TaxYear.percent(szochoBase, TaxYear.szochoRate),
            localTax: TaxYear.percent(localTaxBase, TaxYear.localTaxRate) ~/ 4,
            chamberFee: q == 1 ? TaxYear.chamberFee : 0,
            deadline: workday(DateTime(year, q * 3 + 1, 12)),
          );
        }(),
    ];
  }

  /// What to pay for [quarter] (1-4).
  List<TaxPayment> payments(int quarter) {
    final q = quarters[quarter - 1];
    return [
      (kind: TaxKind.szja, amount: q.szja),
      (kind: TaxKind.szocho, amount: q.szocho),
      (kind: TaxKind.tb, amount: q.tb),
      (kind: TaxKind.localTax, amount: q.localTax),
      if (q.chamberFee > 0) (kind: TaxKind.chamberFee, amount: q.chamberFee),
    ];
  }
}
