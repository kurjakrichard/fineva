import 'package:intl/intl.dart';

/// How a column of a [Report] shows its values: text (a String), a date
/// (DateTime), a whole number (an int: forints, a count), one with decimals
/// (a double: an amount of another currency, a rate).
enum ReportType { text, date, integer, decimal }

class ReportColumn {
  const ReportColumn(this.label, this.type, {this.width = 1});

  final String label;
  final ReportType type;

  /// Relative width (the PDF's columns, the XLSX's in proportion).
  final double width;

  bool get isNumber => type == ReportType.integer || type == ReportType.decimal;
}

/// A line of the table, a subtotal (a month's) or the total.
enum ReportRowKind { line, subtotal, total }

class ReportRow {
  const ReportRow(this.cells, {this.kind = ReportRowKind.line});

  /// One a column, null for an empty one.
  final List<Object?> cells;
  final ReportRowKind kind;
}

/// A table of a [Report]: its [title] (none for a report's only table),
/// columns and rows.
class ReportTable {
  const ReportTable({this.title, required this.columns, required this.rows});

  final String? title;
  final List<ReportColumn> columns;
  final List<ReportRow> rows;
}

/// A record to send (PDF, XLSX: `reportPdf`, `reportXlsx`): a title, lines
/// about it (whose, when made), its tables one after the other, lines after
/// them. Numbers and dates in [locale]'s format in the PDF; numbers and
/// dates in the XLSX, to count with.
class Report {
  const Report({
    required this.title,
    this.header = const [],
    required this.tables,
    this.footer = const [],
    required this.locale,
    required this.fileName,
    this.landscape = true,
  });

  final String title;
  final List<String> header;
  final List<ReportTable> tables;
  final List<String> footer;

  /// Language code: 'hu', 'en'.
  final String locale;

  /// The file's name without its extension.
  final String fileName;

  /// The pages of the PDF (and the XLSX printed) landscape: for wide
  /// tables; portrait for a few columns.
  final bool landscape;

  /// [value] of a column of [type] as text, in [locale]'s format.
  static String text(Object? value, ReportType type, String locale) => switch ((
    value,
    type,
  )) {
    (null, _) => '',
    (final DateTime date, _) => DateFormat.yMd(locale).format(date),
    (final num number, ReportType.integer) => NumberFormat(
      '#,##0',
      locale,
    ).format(number),
    (final num number, _) => NumberFormat('#,##0.00##', locale).format(number),
    (final Object other, _) => '$other',
  };
}
