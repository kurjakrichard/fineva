import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report.dart';

/// [report] as a PDF: A4 ([Report.landscape] or portrait), the title and its lines, then each
/// table under its title (its head on every page), subtotals and the total
/// in bold, the page number at the bottom. [regular] and [bold] have the Hungarian
/// letters (the PDF's own fonts don't: ő, ű).
Future<Uint8List> reportPdf(
  Report report, {
  required pw.Font regular,
  required pw.Font bold,
}) {
  final doc = pw.Document(
    title: report.title,
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  const small = pw.TextStyle(fontSize: 8);
  final boldSmall = small.copyWith(fontWeight: pw.FontWeight.bold);
  const line = PdfColors.grey400;

  pw.Widget cell(String text, ReportColumn column, pw.TextStyle style) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: pw.Text(
          text,
          style: style,
          textAlign: column.isNumber ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      );

  pw.Widget table(ReportTable table) {
    final columns = table.columns;
    return pw.Table(
      columnWidths: {
        for (final (i, column) in columns.indexed)
          i: pw.FlexColumnWidth(column.width),
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: line, width: 0.5),
        bottom: pw.BorderSide(color: line, width: 0.5),
      ),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            for (final column in columns) cell(column.label, column, boldSmall),
          ],
        ),
        for (final row in table.rows)
          pw.TableRow(
            decoration: row.kind == ReportRowKind.line
                ? null
                : const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              for (final (i, column) in columns.indexed)
                cell(
                  Report.text(row.cells[i], column.type, report.locale),
                  column,
                  row.kind == ReportRowKind.line ? small : boldSmall,
                ),
            ],
          ),
      ],
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: report.landscape
          ? PdfPageFormat.a4.landscape
          : PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${report.title} · ${context.pageNumber} / ${context.pagesCount}',
          style: small.copyWith(color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        pw.Text(
          report.title,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        for (final text in report.header)
          pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 10),
        for (final (i, t) in report.tables.indexed) ...[
          if (i > 0) pw.SizedBox(height: 14),
          if (t.title case final title?) ...[
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
          ],
          table(t),
        ],
        pw.SizedBox(height: 10),
        for (final text in report.footer)
          pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );
  return doc.save();
}
