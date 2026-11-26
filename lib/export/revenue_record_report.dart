import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'profile_header.dart';
import 'report.dart';

/// The revenue record of [record]'s year as a [Report] to send: whose
/// (name, tax number, tax identification number, address), when made; a
/// line for each revenue received (sorszám, the document's number, the day
/// received, partner, description, payment method, in another currency its
/// amount and rate, the revenue in forints, the running total, the month
/// of the return: the month received, as in the workbook), the year's
/// total; the revenue limit. The columns of another currency only if there
/// is one. No months' totals (the app shows them).
Report revenueRecordReport(
  RevenueRecord record,
  Profile profile,
  AppLocalizations l10n, {
  DateTime? madeOn,
}) {
  final locale = l10n.localeName;
  final year = record.year;
  final foreign = record.lines.any(
    (line) => line.invoice.currency != Currency.huf,
  );
  final columns = [
    ReportColumn(l10n.reportRecordNumber, ReportType.integer, width: 1),
    ReportColumn(l10n.reportDocument, ReportType.text, width: 1.4),
    ReportColumn(l10n.reportReceived, ReportType.date, width: 1.1),
    ReportColumn(l10n.partner, ReportType.text, width: 1.8),
    ReportColumn(l10n.invoiceDescription, ReportType.text, width: 1.8),
    ReportColumn(l10n.paymentMethod, ReportType.text, width: 1.1),
    if (foreign) ...[
      ReportColumn(l10n.currency, ReportType.text, width: 0.8),
      ReportColumn(l10n.reportForeignAmount, ReportType.decimal, width: 1.2),
      ReportColumn(l10n.exchangeRate, ReportType.decimal, width: 1),
    ],
    ReportColumn(l10n.reportRevenue, ReportType.integer, width: 1.3),
    ReportColumn(l10n.reportCumulative, ReportType.integer, width: 1.3),
    ReportColumn(l10n.reportReturnMonth, ReportType.integer, width: 1),
  ];
  final rows = [
    for (final line in record.lines)
      ReportRow([
        line.number,
        line.invoice.number,
        line.date,
        line.invoice.partnerName,
        line.invoice.description,
        l10n.paymentMethodName(line.payment.method),
        if (foreign) ...[
          ...switch (line.invoice) {
            final invoice when invoice.currency != Currency.huf => [
              invoice.currency.code,
              line.payment.amount / pow10(invoice.currency.decimals),
              invoice.exchangeRate / Invoice.rateScale,
            ],
            _ => [null, null, null],
          },
        ],
        line.amount,
        line.cumulative,
        line.date.month,
      ]),
  ];
  // The year's: its label in the partner's (wide) column, the amount in
  // the revenue's (the third from the end).
  rows.add(
    ReportRow([
      for (var i = 0; i < columns.length; i++)
        i == 3
            ? l10n.total
            : i == columns.length - 3
            ? record.total
            : null,
    ], kind: ReportRowKind.total),
  );

  return Report(
    title: l10n.incomeRecord(year),
    header: profileHeader(profile, l10n, madeOn: madeOn),
    tables: [ReportTable(columns: columns, rows: rows)],
    footer: [
      l10n.reportRevenueLimit(
        year,
        Currency.huf.format(TaxYear.of(year).flatRateRevenueLimit, locale),
      ),
      l10n.revenueRecordText,
      if (foreign) l10n.reportRateNote,
    ],
    locale: locale,
    fileName: l10n.reportFileName(year),
  );
}

/// 10 to the [exponent].
int pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
