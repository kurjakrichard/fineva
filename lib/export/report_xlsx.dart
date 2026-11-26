import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'report.dart';

/// [report] as an XLSX workbook of one sheet: the title (bold) and its
/// lines, each table (its title and head bold, its rows; subtotals and the
/// total bold; the only table's head frozen), the lines after them. Numbers and dates are real ones (with formats), to
/// count with in Excel or LibreOffice. Written by hand (the XML of the
/// format in a zip): the excel package doesn't go with the app's packages.
Uint8List reportXlsx(Report report) {
  // As wide as the widest of the tables' column there.
  final widths = <double>[];
  for (final table in report.tables) {
    for (final (i, column) in table.columns.indexed) {
      if (i < widths.length) {
        if (column.width > widths[i]) widths[i] = column.width;
      } else {
        widths.add(column.width);
      }
    }
  }
  final rows = <String>[];
  var r = 0;
  // The next row: its number first, then its cells (their references).
  String row(List<String> Function() cells) {
    r++;
    return '<row r="$r">${cells().join()}</row>';
  }

  String ref(int column) => '${_column(column)}$r';
  String text(int column, String value, {bool bold = false}) =>
      '<c r="${ref(column)}" t="inlineStr"${bold ? ' s="1"' : ''}>'
      '<is><t xml:space="preserve">${_escape(value)}</t></is></c>';
  String cell(int column, Object? value, ReportType type, bool bold) {
    if (value == null) return '';
    final b = bold ? 1 : 0;
    return switch ((value, type)) {
      (final DateTime date, _) =>
        '<c r="${ref(column)}" s="${2 + b * 3}"><v>${_serial(date)}</v></c>',
      (final num number, ReportType.integer) =>
        '<c r="${ref(column)}" s="${3 + b * 3}"><v>$number</v></c>',
      (final num number, _) =>
        '<c r="${ref(column)}" s="${4 + b * 3}"><v>$number</v></c>',
      (final Object other, _) => text(column, '$other', bold: bold),
    };
  }

  rows.add(row(() => [text(0, report.title, bold: true)]));
  for (final line in report.header) {
    rows.add(row(() => [text(0, line)]));
  }
  int? head;
  for (final table in report.tables) {
    final columns = table.columns;
    rows.add(row(() => []));
    if (table.title case final title?) {
      rows.add(row(() => [text(0, title, bold: true)]));
    }
    rows.add(
      row(
        () => [
          for (final (i, column) in columns.indexed)
            text(i, column.label, bold: true),
        ],
      ),
    );
    head ??= r;
    for (final line in table.rows) {
      final bold = line.kind != ReportRowKind.line;
      rows.add(
        row(
          () => [
            for (final (i, column) in columns.indexed)
              cell(i, line.cells[i], column.type, bold),
          ],
        ),
      );
    }
  }
  // A single table's head stays when scrolling.
  final freeze = report.tables.length == 1 ? head : null;
  if (report.footer.isNotEmpty) rows.add(row(() => []));
  for (final line in report.footer) {
    rows.add(row(() => [text(0, line)]));
  }

  final dateFormat = report.locale == 'hu' ? 'yyyy.mm.dd.' : 'yyyy-mm-dd';
  final sheet =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="$_main" xmlns:r="$_rel">'
      '${freeze == null ? '' : '<sheetViews><sheetView workbookViewId="0"><pane ySplit="$freeze" topLeftCell="A${freeze + 1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'}'
      '<cols>${[for (final (i, width) in widths.indexed) '<col min="${i + 1}" max="${i + 1}" width="${(width * 9).toStringAsFixed(1)}" customWidth="1"/>'].join()}</cols>'
      '<sheetData>${rows.join()}</sheetData>'
      '<pageSetup orientation="${report.landscape ? 'landscape' : 'portrait'}" paperSize="9"/>'
      '</worksheet>';
  final styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="$_main">'
      '<numFmts count="2">'
      '<numFmt numFmtId="164" formatCode="${_escape(dateFormat)}"/>'
      '<numFmt numFmtId="165" formatCode="#,##0.00##"/>'
      '</numFmts>'
      '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/>'
      '</border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" '
      'borderId="0"/></cellStyleXfs>'
      // 0 plain, 1 bold, 2 date, 3 forints, 4 decimals, 5-7 the same bold.
      '<cellXfs count="8">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" '
      'applyFont="1"/>'
      '${_numberStyle(164, 0)}${_numberStyle(3, 0)}${_numberStyle(165, 0)}'
      '${_numberStyle(164, 1)}${_numberStyle(3, 1)}${_numberStyle(165, 1)}'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" '
      'builtinId="0"/></cellStyles>'
      '</styleSheet>';
  final sheetName = _escape(
    report.title.length > 31 ? report.title.substring(0, 31) : report.title,
  );
  final files = {
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>',
    '_rels/.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$_package">'
        '<Relationship Id="rId1" Type="$_rel/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
    'xl/workbook.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="$_main" xmlns:r="$_rel">'
        '<sheets><sheet name="$sheetName" sheetId="1" r:id="rId1"/></sheets>'
        '</workbook>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$_package">'
        '<Relationship Id="rId1" Type="$_rel/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="$_rel/styles" Target="styles.xml"/>'
        '</Relationships>',
    'xl/worksheets/sheet1.xml': sheet,
    'xl/styles.xml': styles,
  };
  final archive = Archive();
  for (final MapEntry(key: name, value: content) in files.entries) {
    archive.addFile(ArchiveFile.bytes(name, utf8.encode(content)));
  }
  return ZipEncoder().encodeBytes(archive);
}

const _main = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _rel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _package = 'http://schemas.openxmlformats.org/package/2006/relationships';

String _numberStyle(int format, int font) =>
    '<xf numFmtId="$format" fontId="$font" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1"${font == 1 ? ' applyFont="1"' : ''}/>';

/// The column's letters: 0 is A, 26 is AA.
String _column(int index) {
  var n = index + 1;
  var letters = '';
  while (n > 0) {
    final rest = (n - 1) % 26;
    letters = String.fromCharCode(65 + rest) + letters;
    n = (n - 1) ~/ 26;
  }
  return letters;
}

/// Days since 30 December 1899: a date in a spreadsheet.
int _serial(DateTime date) => DateTime.utc(
  date.year,
  date.month,
  date.day,
).difference(DateTime.utc(1899, 12, 30)).inDays;

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
