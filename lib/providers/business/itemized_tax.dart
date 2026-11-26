import 'dart:math' show min;

import '../../data/data_export.dart';
import '../../utils/utils.dart';
import 'tax_year.dart';

/// Depreciation (értékcsökkenés) of [asset] in each quarter of [year], in
/// forints: the yearly rate of the cost, by day from the purchase day,
/// until the cost is used up (as the ÉCS sheet of the workbook, a year
/// counted as 365 days). [Asset.writeOffAtOnce] writes it off in the
/// purchase quarter.
///
/// Rounded so that the quarters always add up to the cost.
List<int> quarterlyDepreciation(Asset asset, int year) {
  final result = List.filled(4, 0);
  final purchase = asset.purchaseDate;
  if (purchase.year > year) return result;
  if (asset.rate >= Asset.writeOffAtOnce) {
    if (purchase.year == year) {
      result[(purchase.month - 1) ~/ 3] = asset.amount;
    }
    return result;
  }
  final daily = asset.amount * asset.rate / 10000 / 365;
  var total = 0.0; // depreciated up to the quarter
  var roundedBefore = 0;
  var quarterStart = DateTime(purchase.year, (purchase.month - 1) ~/ 3 * 3 + 1);
  while (quarterStart.year <= year && total < asset.amount) {
    final next = DateTime(quarterStart.year, quarterStart.month + 3);
    final from = purchase.isAfter(quarterStart) ? purchase : quarterStart;
    // Calendar days, from the first day to the last one of the quarter.
    final days = DateTime.utc(
      next.year,
      next.month,
      next.day,
    ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
    total = min(asset.amount.toDouble(), total + daily * days);
    final rounded = total.round();
    if (quarterStart.year == year) {
      result[(quarterStart.month - 1) ~/ 3] = rounded - roundedBefore;
    }
    roundedBefore = rounded;
    quarterStart = next;
  }
  return result;
}

/// The written-off part of [asset]'s cost by the end of [year].
int depreciatedBy(Asset asset, int year) {
  var sum = 0;
  for (var y = asset.purchaseDate.year; y <= year; y++) {
    sum += quarterlyDepreciation(asset, y).fold(0, (a, b) => a + b);
  }
  return sum;
}

/// One quarter of itemized taxation (vállalkozói SZJA). Amounts in forints.
class ItemizedQuarter {
  const ItemizedQuarter({
    required this.quarter,
    required this.revenue,
    required this.costs,
    required this.depreciation,
    required this.lossCarried,
    required this.deadline,
  });

  /// 1-4.
  final int quarter;

  /// Taxable revenue.
  final int revenue;

  /// The costs, [depreciation] included.
  final int costs;
  final int depreciation;

  /// The loss of the previous quarters (0 or negative).
  final int lossCarried;

  /// When the advances are due: the 12th of the next month.
  final DateTime deadline;

  /// Revenue - costs + the loss carried; negative is a loss.
  int get base => revenue - costs + lossCarried;

  /// Vállalkozói személyi jövedelemadó (9%).
  int get vszja => ItemizedTax.vszjaOf(base);

  /// Vállalkozói osztalékalap: the base after the VSZJA.
  int get dividendBase => base > 0 ? base - vszja : 0;

  /// SZJA on the dividend base (15%).
  int get szja => TaxYear.percent(dividendBase, TaxYear.szjaRate);

  int get total => vszja + szja;
}

/// Itemized taxation (vállalkozói SZJA) of [year] from the entries, as the
/// cash-flow ledger workbook calculates it: the entries count on their date,
/// in forints, by the [TaxTreatment] of their category; the costs include
/// the depreciation of the assets. Every quarter: revenue - costs (+ the
/// loss of the quarter before) is the base, 9% of it the VSZJA, the rest the
/// dividend base with 15% SZJA. For the year also the SZOCHO due on the
/// dividend base (up to the yearly cap) and the local business tax.
class ItemizedTax {
  ItemizedTax({
    required List<Entry> entries,
    required List<EntryCategory> categories,
    required List<Account> accounts,
    required List<int> depreciation,
    required this.year,
  }) : taxYear = TaxYear.of(year) {
    final treatments = {for (final c in categories) ?c.id: c.taxTreatment};
    final types = {for (final c in categories) ?c.id: c.type};
    final currencies = {for (final a in accounts) ?a.id: a.currency};
    final byQuarter = List.generate(4, (_) => <TaxTreatment, int>{});
    for (final entry in entries) {
      if (entry.date.year != year) continue;
      final treatment = treatments[entry.categoryId] ?? TaxTreatment.none;
      if (treatment == TaxTreatment.none) continue;
      final huf = entry.huf(currencies[entry.accountId] ?? Currency.huf);
      if (huf == null) {
        missingRates++;
        continue;
      }
      // An entry of the other type (a refund of a cost) takes it back.
      final amount = types[entry.categoryId] == entry.type ? huf : -huf;
      byQuarter[(entry.date.month - 1) ~/ 3].update(
        treatment,
        (sum) => sum + amount,
        ifAbsent: () => amount,
      );
    }
    quarterTotals = byQuarter;

    var loss = 0;
    quarters = [
      for (var q = 0; q < 4; q++)
        () {
          final totals = byQuarter[q];
          final quarter = ItemizedQuarter(
            quarter: q + 1,
            revenue: totals[TaxTreatment.revenue] ?? 0,
            costs: _costs(totals) + depreciation[q],
            depreciation: depreciation[q],
            lossCarried: loss,
            deadline: workday(DateTime(year, q * 3 + 4, 12)),
          );
          loss = quarter.base < 0 ? quarter.base : 0;
          return quarter;
        }(),
    ];
  }

  static const int vszjaRate = 900;

  /// SZOCHO is due up to 24 times the monthly minimum wage a year.
  static const int szochoCapMonths = 24;

  final int year;
  final TaxYear taxYear;

  /// Entries of foreign currency accounts left out for lack of an exchange
  /// rate.
  int missingRates = 0;

  /// The sum of each treatment in each quarter.
  late final List<Map<TaxTreatment, int>> quarterTotals;
  late final List<ItemizedQuarter> quarters;

  static int vszjaOf(int base) =>
      base > 0 ? TaxYear.percent(base, vszjaRate) : 0;

  static int _costs(Map<TaxTreatment, int> totals) => [
    for (final MapEntry(key: t, value: amount) in totals.entries)
      if (t.isCost) amount,
  ].fold(0, (a, b) => a + b);

  /// The sum of [treatment] in the year.
  int total(TaxTreatment treatment) =>
      quarterTotals.fold(0, (sum, q) => sum + (q[treatment] ?? 0));

  int get revenue => quarters.fold(0, (sum, q) => sum + q.revenue);
  int get costs => quarters.fold(0, (sum, q) => sum + q.costs);
  int get depreciation => quarters.fold(0, (sum, q) => sum + q.depreciation);

  /// The yearly base (losses of the quarters offset by the others).
  int get base => revenue - costs;
  int get vszja => vszjaOf(base);
  int get dividendBase => base > 0 ? base - vszja : 0;
  int get szja => TaxYear.percent(dividendBase, TaxYear.szjaRate);

  /// The most SZOCHO of the year: 13% of 24 monthly minimum wages.
  int get szochoCap => TaxYear.percent(
    taxYear.minimumWage * szochoCapMonths,
    TaxYear.szochoRate,
  );

  /// SZOCHO paid on the withdrawal.
  int get szochoPaid => total(TaxTreatment.szocho);

  /// SZOCHO on the dividend base, up to what the cap leaves; settled after
  /// the year.
  int get szochoOnDividend {
    final left = szochoCap - szochoPaid;
    if (left <= 0) return 0;
    return min(TaxYear.percent(dividendBase, TaxYear.szochoRate), left);
  }

  /// Local business tax base: revenue - material costs.
  int get localTaxBase => revenue - total(TaxTreatment.materialCost);
  int get localTax => TaxYear.percent(localTaxBase, TaxYear.localTaxRate);
}
