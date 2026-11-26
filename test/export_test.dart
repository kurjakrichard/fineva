import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fineva/data/data_export.dart';
import 'package:fineva/export/export.dart';
import 'package:fineva/l10n/l10n.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

const _ev = Profile(
  name: 'Kiss Anna',
  address: '1111 Budapest, Fő utca 1.',
  taxNumber: '10773381-1-44',
  userType: UserType.soleProprietor,
);

Invoice _sale(
  String number,
  DateTime paid,
  int amount, {
  Currency currency = Currency.huf,
  int rate = Invoice.rateScale,
}) => Invoice(
  direction: InvoiceDirection.outgoing,
  number: number,
  partnerName: 'Partner $number',
  description: 'Munka',
  issueDate: paid,
  fulfillmentDate: paid,
  currency: currency,
  exchangeRate: rate,
  netAmount: amount,
  vatCode: VatCode.aam,
  payments: [InvoicePayment(date: paid, amount: amount, recordNumber: null)],
);

void main() {
  setUpAll(() => initializeDateFormatting('hu'));
  final l10n = lookupAppLocalizations(const Locale('hu'));
  final huf = [
    _sale('A-1', DateTime(2026, 1, 20), 650000),
    _sale('A-2', DateTime(2026, 1, 28), 280000),
    _sale('A-3', DateTime(2026, 3, 5), 720000),
  ];
  // 1500.00 EUR at 386.41.
  final euro = _sale(
    'D-1',
    DateTime(2026, 2, 10),
    150000,
    currency: Currency.eur,
    rate: 3864100,
  );

  Report report(List<Invoice> invoices) => revenueRecordReport(
    RevenueRecord(invoices, 2026),
    _ev,
    l10n,
    madeOn: DateTime(2026, 11, 23),
  );

  test('the revenue record to send: whose, a line a revenue with the month '
      "of its return, the year's total (no months'); the columns of another "
      'currency only with one', () {
    final forints = report(huf);
    expect(forints.title, 'Bevételi nyilvántartás 2026');
    expect(forints.header.first, contains('Kiss Anna'));
    expect(forints.header.first, contains('Adószám: 10773381-1-44'));
    expect(forints.header, contains('1111 Budapest, Fő utca 1.'));
    expect(forints.header.last, 'Készült: 2026. nov. 23.');
    expect(forints.fileName, 'beveteli-nyilvantartas-2026');
    expect(forints.tables.single.columns.map((c) => c.label), [
      'Sorszám',
      'Bizonylat sorszáma',
      'Befolyás napja',
      'Partner',
      'Gazdasági esemény leírása',
      'Fizetési mód',
      'Bevétel (Ft)',
      'Halmozott (Ft)',
      'Bevallás hónapja',
    ]);
    expect(forints.tables.single.rows.map((r) => r.kind), [
      ReportRowKind.line,
      ReportRowKind.line,
      ReportRowKind.line,
      ReportRowKind.total,
    ]);
    expect(forints.tables.single.rows[1].cells, [
      2,
      'A-2',
      DateTime(2026, 1, 28),
      'Partner A-2',
      'Munka',
      'Átutalás',
      280000,
      930000,
      1,
    ]);
    expect(forints.tables.single.rows[2].cells.last, 3);
    expect(forints.tables.single.rows.last.cells[3], 'Összesen');
    expect(forints.tables.single.rows.last.cells[6], 1650000);
    expect(forints.footer.first, contains('Bevételi határ 2026'));

    final withEuro = report([...huf, euro]);
    expect(
      withEuro.tables.single.columns.map((c) => c.label),
      contains('Devizaösszeg'),
    );
    final line = withEuro.tables.single.rows.firstWhere(
      (r) => r.cells[1] == 'D-1',
    );
    expect(line.cells.sublist(6), ['EUR', 1500.0, 386.41, 579615, 1509615, 2]);
    expect(withEuro.tables.single.rows.last.cells[9], 2229615);
    expect(withEuro.footer.last, contains('árfolyam'));
  });

  test('XLSX: well formed, the title, head and lines where they belong, '
      'dates and numbers real ones', () {
    final bytes = reportXlsx(report([...huf, euro]));
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive.files) {
      // Every part parses.
      XmlDocument.parse(utf8.decode(file.content));
    }
    final sheet = XmlDocument.parse(
      utf8.decode(archive.findFile('xl/worksheets/sheet1.xml')!.content),
    );
    final cells = {
      for (final c in sheet.findAllElements('c')) c.getAttribute('r')!: c,
    };
    String text(String ref) => cells[ref]!.innerText;
    expect(text('A1'), 'Bevételi nyilvántartás 2026');
    // Title, three lines, an empty row: the head in row 6.
    expect(text('A6'), 'Sorszám');
    expect(text('B7'), 'A-1');
    // A date as its serial number, with the date style.
    expect(cells['C7']!.getAttribute('t'), isNull);
    expect(int.parse(text('C7')), 46042);
    // Forints as numbers.
    expect(text('J7'), '650000');
    expect(cells['J7']!.getAttribute('t'), isNull);
    // Every row's number is its cells'.
    for (final row in sheet.findAllElements('row')) {
      final number = row.getAttribute('r');
      for (final cell in row.findElements('c')) {
        expect(cell.getAttribute('r')!.replaceAll(RegExp('[A-Z]'), ''), number);
      }
    }
    expect(sheet.findAllElements('pane').single.getAttribute('ySplit'), '6');
  });

  test('PDF: made with the bundled font', () async {
    pw.Font font(String name) => pw.Font.ttf(
      ByteData.view(
        File('assets/fonts/Roboto-$name.ttf').readAsBytesSync().buffer,
      ),
    );
    final bytes = await reportPdf(
      report([...huf, euro]),
      regular: font('Regular'),
      bold: font('Bold'),
    );
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
  });

  group('flat-rate tax', () {
    final tax = FlatRateTax([...huf, euro], _ev, 2026);

    test('a quarter: the calculation, what to transfer, the deadline', () {
      final report = flatRateQuarterReport(
        tax,
        1,
        _ev,
        l10n,
        madeOn: DateTime(2026, 11, 23),
      );
      expect(report.title, 'Átalányadó 2026 – 1. negyedév');
      expect(report.fileName, 'atalanyado-2026-1-negyedev');
      expect(report.header.first, contains('Kiss Anna'));
      final (calculation, transfer) = (report.tables[0], report.tables[1]);
      expect(calculation.title, isNull);
      expect(calculation.columns.map((c) => c.label), [
        'Megnevezés',
        'Alap (Ft)',
        'Összeg (Ft)',
      ]);
      final q1 = tax.quarters.first;
      Object? amount(String label) =>
          calculation.rows.firstWhere((r) => r.cells[0] == label).cells[2];
      expect(amount('Bevétel'), q1.revenue);
      expect(amount('Bevétel'), 650000 + 280000 + 579615 + 720000);
      // The costs: the cost ratio of the revenue; the income the rest.
      expect(amount('Költség'), q1.revenue - q1.income);
      // Revenue - costs = income - tax-free part = tax base.
      expect(calculation.rows.map((r) => r.cells[0]).take(5), [
        'Bevétel',
        'Költség',
        'Jövedelem',
        'Adómentes rész',
        'Adóalap',
      ]);
      expect(amount('Jövedelem'), q1.revenue - q1.cost);
      expect(amount('Adóalap'), q1.income - q1.taxFreeIncome);
      expect(
        calculation.rows
            .firstWhere((r) => r.cells[0] == 'TB-járulék (18,5%)')
            .cells,
        ['TB-járulék (18,5%)', q1.contributionBase, q1.tb],
      );
      expect(calculation.rows.last.kind, ReportRowKind.total);
      expect(calculation.rows.last.cells[2], q1.total);

      expect(transfer.title, 'Utalandó');
      expect(transfer.rows.first.cells, [
        'NAV Szociális hozzájárulási adó',
        '258',
        '10032000-06055912',
        q1.szocho,
      ]);
      expect(
        transfer.rows.fold(0, (sum, r) => sum + (r.cells[3]! as int)),
        q1.total,
      );
      expect(report.footer.first, 'Határidő: 2026. ápr. 13.');
    });

    test('the summary: a column a quarter and the year', () {
      final report = flatRateSummaryReport(tax, _ev, l10n);
      expect(report.title, 'Átalányadó 2026 – éves összesítő');
      final table = report.tables.single;
      expect(table.columns.map((c) => c.label), [
        'Megnevezés',
        '1. negyedév',
        '2. negyedév',
        '3. negyedév',
        '4. negyedév',
        'Év',
      ]);
      final total = table.rows.firstWhere((r) => r.kind == ReportRowKind.total);
      expect(total.cells, [
        'Összesen',
        for (final q in tax.quarters) q.total,
        tax.total,
      ]);
      expect(table.rows.last.cells, [
        'Határidő',
        for (final q in tax.quarters) q.deadline,
        null,
      ]);
      // The year's tax base: its income - its tax-free part.
      int sum(int Function(FlatRateQuarter q) of) =>
          tax.quarters.fold(0, (total, q) => total + of(q));
      final base = table.rows.firstWhere((r) => r.cells[0] == 'Adóalap');
      expect(
        base.cells.last,
        sum((q) => q.income) - sum((q) => q.taxFreeIncome),
      );
      expect(table.rows[1].cells, [
        'Költség',
        for (final q in tax.quarters) q.revenue - q.income,
        tax.revenue - tax.quarters.fold(0, (sum, q) => sum + q.income),
      ]);
      expect(report.footer.first, contains('Bevételi határ 2026'));
    });

    test('XLSX of two tables: well formed, each under its title, no head '
        'frozen', () {
      final bytes = reportXlsx(flatRateQuarterReport(tax, 1, _ev, l10n));
      final archive = ZipDecoder().decodeBytes(bytes);
      final sheet = XmlDocument.parse(
        utf8.decode(archive.findFile('xl/worksheets/sheet1.xml')!.content),
      );
      final texts = [
        for (final c in sheet.findAllElements('c'))
          if (c.getAttribute('t') == 'inlineStr') c.innerText,
      ];
      expect(
        texts,
        containsAllInOrder(['Megnevezés', 'Utalandó', 'Kedvezményezett']),
      );
      expect(sheet.findAllElements('pane'), isEmpty);
    });
  });
}
