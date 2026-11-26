import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'profile_header.dart';
import 'report.dart';

/// [quarter] (1-4) of flat-rate taxation as a [Report] to send: whose, when
/// made; the calculation (revenue, income, tax-free and taxable income,
/// each tax with its base, the total) and what to transfer (payee, tax
/// code, account number, amount); the deadline.
Report flatRateQuarterReport(
  FlatRateTax tax,
  int quarter,
  Profile profile,
  AppLocalizations l10n, {
  DateTime? madeOn,
}) {
  final q = tax.quarters[quarter - 1];
  final year = tax.taxYear.year;
  final locale = l10n.localeName;
  ReportRow row(String label, int amount, {int? base}) =>
      ReportRow([label, base, amount]);
  return Report(
    title: l10n.flatRateQuarterTitle(year, quarter),
    header: profileHeader(profile, l10n, madeOn: madeOn),
    tables: [
      ReportTable(
        columns: [
          ReportColumn(l10n.reportItem, ReportType.text, width: 3),
          ReportColumn(l10n.reportBase, ReportType.integer, width: 1.3),
          ReportColumn(l10n.reportAmount, ReportType.integer, width: 1.3),
        ],
        rows: [
          row(l10n.revenue, q.revenue),
          row(l10n.flatRateCost, q.cost),
          row(l10n.flatRateIncome, q.income),
          row(l10n.taxFreePart, q.taxFreeIncome),
          row(l10n.taxBase, q.taxableIncome),
          row(l10n.szja, q.szja, base: q.taxableIncome),
          row(l10n.tbContribution, q.tb, base: q.contributionBase),
          row(l10n.szocho, q.szocho, base: q.szochoBase),
          row(l10n.localTax, q.localTax),
          if (q.chamberFee > 0) row(l10n.chamberFee, q.chamberFee),
          ReportRow([l10n.total, null, q.total], kind: ReportRowKind.total),
        ],
      ),
      ReportTable(
        title: l10n.toTransfer,
        columns: [
          ReportColumn(l10n.reportPayee, ReportType.text, width: 3),
          ReportColumn(l10n.reportTaxCode, ReportType.text, width: 0.8),
          ReportColumn(l10n.reportAccount, ReportType.text, width: 1.8),
          ReportColumn(l10n.reportAmount, ReportType.integer, width: 1.3),
        ],
        rows: [
          for (final payment in tax.payments(quarter))
            if (payment.amount > 0)
              ReportRow([
                l10n.taxKindName(payment.kind),
                payment.kind.code,
                payment.kind.account ?? l10n.municipalityAccount,
                payment.amount,
              ]),
        ],
      ),
    ],
    footer: [
      l10n.deadline(DateFormat.yMMMd(locale).format(q.deadline)),
      if (!tax.taxYear.isKnown)
        l10n.taxYearUnknown(year, TaxYear.known.last.year),
    ],
    locale: locale,
    fileName: l10n.flatRateQuarterFile(year, quarter),
    // A few columns.
    landscape: false,
  );
}

/// The year of flat-rate taxation summed up as a [Report] to send: a
/// column a quarter and one for the year: revenue, income, taxable income,
/// each tax, the total, the deadline; the revenue limit and the tax-free
/// revenue below.
Report flatRateSummaryReport(
  FlatRateTax tax,
  Profile profile,
  AppLocalizations l10n, {
  DateTime? madeOn,
}) {
  final year = tax.taxYear.year;
  final locale = l10n.localeName;
  final quarters = tax.quarters;
  ReportRow row(
    String label,
    int Function(FlatRateQuarter q) of, {
    ReportRowKind kind = ReportRowKind.line,
  }) => ReportRow([
    label,
    for (final q in quarters) of(q),
    quarters.fold<int>(0, (sum, q) => sum + of(q)),
  ], kind: kind);
  final chamberFee = quarters.fold(0, (sum, q) => sum + q.chamberFee);
  return Report(
    title: l10n.flatRateSummaryTitle(year),
    header: profileHeader(profile, l10n, madeOn: madeOn),
    tables: [
      ReportTable(
        columns: [
          ReportColumn(l10n.reportItem, ReportType.text, width: 3),
          for (var q = 1; q <= 4; q++)
            ReportColumn(l10n.quarterName(q), ReportType.integer, width: 1.3),
          ReportColumn(l10n.periodYear, ReportType.integer, width: 1.3),
        ],
        rows: [
          row(l10n.revenue, (q) => q.revenue),
          row(l10n.flatRateCost, (q) => q.cost),
          row(l10n.flatRateIncome, (q) => q.income),
          row(l10n.taxFreePart, (q) => q.taxFreeIncome),
          row(l10n.taxBase, (q) => q.taxableIncome),
          row(l10n.szja, (q) => q.szja),
          row(l10n.tbContribution, (q) => q.tb),
          row(l10n.szocho, (q) => q.szocho),
          row(l10n.localTax, (q) => q.localTax),
          if (chamberFee > 0) row(l10n.chamberFee, (q) => q.chamberFee),
          row(l10n.total, (q) => q.total, kind: ReportRowKind.total),
          ReportRow([
            l10n.deadlineLabel,
            for (final q in quarters) q.deadline,
            null,
          ]),
        ],
      ),
    ],
    footer: [
      l10n.reportRevenueLimit(
        year,
        Currency.huf.format(tax.revenueLimit, locale),
      ),
      l10n.taxFreeRevenueNote(Currency.huf.format(tax.taxFreeRevenue, locale)),
      if (tax.overLimit) l10n.flatRateOverLimit,
      if (!tax.taxYear.isKnown)
        l10n.taxYearUnknown(year, TaxYear.known.last.year),
    ],
    locale: locale,
    fileName: l10n.flatRateSummaryFile(year),
  );
}
