import 'package:fineva/config/config.dart';
import 'package:fineva/data/data_export.dart';
import 'package:fineva/export/export.dart';
import 'package:fineva/pages/business_tabs.dart';
import 'package:fineva/l10n/l10n.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No database: the given state; remembers the saved invoice.
class _FakeFinance extends FinanceNotifier {
  _FakeFinance(this.initial);

  final FinanceState initial;
  Invoice? saved;

  @override
  FinanceState build() => initial;

  @override
  Future<bool> saveInvoice(Invoice invoice) async {
    saved = invoice;
    return true;
  }

  /// A payment moved: (to, payment, from).
  (Invoice, InvoicePayment, Invoice)? moved;

  @override
  Future<bool> savePayment(
    Invoice invoice,
    InvoicePayment payment, {
    Invoice? from,
  }) async {
    if (from == null || from.id == invoice.id) {
      return super.savePayment(invoice, payment);
    }
    moved = (invoice, payment, from);
    return true;
  }
}

/// No network: every download fails; remembers what was asked.
class _OfflineRates extends RatesNotifier {
  static final asked = <(RateSource, Currency, int)>[];

  @override
  Future<bool> downloadYear(
    RateSource source,
    Currency currency,
    int year,
  ) async {
    asked.add((source, currency, year));
    return false;
  }
}

/// A flat-rate, VAT exempt sole proprietor: invoices only.
const _ev = Profile(
  id: 1,
  name: 'Kiss Anna',
  taxNumber: '10773381-1-44',
  userType: UserType.soleProprietor,
);

final _year = DateTime.now().year;

Invoice _sale(
  int id,
  String number,
  int month,
  int net, {
  int? paidMonth,
  int? paidAmount,
}) => Invoice(
  id: id,
  userId: 1,
  direction: InvoiceDirection.outgoing,
  number: number,
  partnerName: 'Ügyfél $id',
  issueDate: DateTime(_year, month),
  fulfillmentDate: DateTime(_year, month),
  netAmount: net,
  vatCode: VatCode.aam,
  payments: [
    if (paidMonth != null)
      // Saved: with an id.
      InvoicePayment(
        id: id * 10,
        invoiceId: id,
        date: DateTime(_year, paidMonth, 10),
        amount: paidAmount ?? net,
      ),
  ],
);

void main() {
  late _FakeFinance finance;

  // Newest first, as loaded.
  final invoices = [
    _sale(3, '$_year/003', 2, 300000),
    _sale(2, '$_year/002', 1, 900000, paidMonth: 2, paidAmount: 500000),
    _sale(1, '$_year/001', 1, 650000, paidMonth: 1),
  ];

  Future<void> pumpApp(
    WidgetTester tester, {
    Profile profile = _ev,
    String location = '/dashboard',
    List<Invoice>? withInvoices,
    RateBook rates = const RateBook.empty(),
  }) async {
    // A phone: the menu is a drawer.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({shareLocaleKey: 'en'});
    final prefs = await SharedPreferences.getInstance();
    finance = _FakeFinance(
      FinanceState(
        loaded: true,
        profiles: [profile],
        profile: profile,
        invoices: withInvoices ?? invoices,
        rates: rates,
      ),
    );
    final router = GoRouter(
      navigatorKey: navigationKey,
      initialLocation: location,
      routes: appRoutes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          financeProvider.overrideWith(() => finance),
          ratesProvider.overrideWith(_OfflineRates.new),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    // The test font's letters are 1 em wide: "Outgoing invoices" would be
    // twice as wide as with a real font, wider than the drawer.
    tester.platformDispatcher.textScaleFactorTestValue = 0.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String label, String text) async {
    final finder = find.widgetWithText(TextFormField, label);
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  String huf(int amount) => Currency.huf.format(amount, 'en');

  testWidgets('the menu: invoices, revenue record, flat-rate tax; no '
      'accounts, entries, statistics or categories', (tester) async {
    await pumpApp(tester);
    await openMenu(tester);
    final menu = find.byType(NavigationDrawer);
    for (final item in [
      'Dashboard',
      'Outgoing invoices',
      'Revenue record',
      'Flat-rate tax',
      'Settings',
    ]) {
      expect(
        find.descendant(of: menu, matching: find.text(item)),
        findsOneWidget,
        reason: item,
      );
    }
    for (final item in ['Entries', 'Accounts', 'Statistics', 'Categories']) {
      expect(
        find.descendant(of: menu, matching: find.text(item)),
        findsNothing,
        reason: item,
      );
    }

    await tester.tap(
      find.descendant(of: menu, matching: find.text('Revenue record')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Revenue record'), findsOneWidget);
    expect(find.text('Ügyfél 1'), findsOneWidget);
  });

  testWidgets('the dashboard: no balances, no account needed; the revenue, '
      'the next tax, what is owed and the latest invoices', (tester) async {
    await pumpApp(tester);
    expect(
      find.text('Add an account first to record income and expenses.'),
      findsNothing,
    );
    expect(find.text('Revenue $_year'), findsOneWidget);
    expect(find.text(huf(1150000)), findsOneWidget);
    expect(find.text('Next tax payment'), findsOneWidget);
    expect(find.text('Owed to you (2)'), findsOneWidget);
    expect(find.textContaining('You owe'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Ügyfél 1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Latest invoices'), findsOneWidget);
    expect(find.text('New invoice'), findsOneWidget);
  });

  testWidgets('the revenue record: what came in, in the order received, '
      'with the running total', (tester) async {
    await pumpApp(tester, location: Routes.revenueRecord.path);
    expect(find.text('Income record $_year'), findsOneWidget);
    expect(find.text(huf(1150000)), findsWidgets);
    expect(find.text('Ügyfél 1'), findsOneWidget);
    expect(find.text('Ügyfél 2'), findsOneWidget);
    // Unpaid: not revenue.
    expect(find.text('Ügyfél 3'), findsNothing);
    expect(find.text(huf(500000)), findsWidgets);
    expect(find.text('Cumulative ${huf(1150000)}'), findsOneWidget);
    expect(find.text('January'), findsOneWidget);
    expect(find.text('February'), findsOneWidget);
  });

  testWidgets('the revenue record is sent or saved as PDF or XLSX', (
    tester,
  ) async {
    await pumpApp(tester, location: Routes.revenueRecord.path);
    await tester.tap(find.byTooltip('Send or save'));
    await tester.pumpAndSettle();
    for (final format in ['PDF', 'XLSX']) {
      expect(find.text('Save as $format'), findsOneWidget);
      // The share sheet sends a file everywhere but on Linux.
      expect(
        find.text('Send as $format'),
        canShareFiles ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('a new invoice: outgoing, without booking on an account; '
      'paid in parts, paid when they add up to it', (tester) async {
    await pumpApp(tester, location: Routes.invoices.path);
    expect(find.text('Outgoing invoices $_year'), findsOneWidget);
    // No direction to choose.
    expect(find.byType(SegmentedButton<InvoiceDirection>), findsNothing);

    await tap(tester, find.text('New invoice'));
    expect(find.text('Outgoing (revenue)'), findsNothing);
    await enter(tester, 'Invoice number', '$_year/004');
    await enter(tester, 'Net', '1000');
    expect(find.text('Not paid yet.'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    Finder inDialog(String text) =>
        find.descendant(of: dialog, matching: find.text(text));
    Future<void> pay(String amount) async {
      await tap(tester, find.text('Payment'));
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextFormField)).first,
        amount,
      );
      await tester.tap(inDialog('Save'));
      await tester.pumpAndSettle();
    }

    await pay('400');
    expect(find.text('Booked on'), findsNothing);
    expect(
      find.textContaining('Paid ${huf(400)} of ${huf(1000)}'),
      findsOneWidget,
    );
    // Not more than what is open.
    await pay('700');
    expect(inDialog('At most ${huf(600)}'), findsOneWidget);
    await tester.tap(inDialog('Cancel'));
    await tester.pumpAndSettle();
    await pay('600');
    expect(find.text('Paid'), findsOneWidget);

    await tap(tester, find.text('Save'));
    final saved = finance.saved!;
    expect(saved.direction, InvoiceDirection.outgoing);
    expect(saved.vatCode, VatCode.aam);
    expect(saved.payments.map((p) => p.amount), [400, 600]);
    expect(saved.isPaid, isTrue);
    expect(saved.paidAccountId, isNull);
  });

  testWidgets('the revenue record: a new revenue is a payment of an open '
      'invoice chosen, or a new invoice paid the whole', (tester) async {
    await pumpApp(tester, location: Routes.revenueRecord.path);
    await tester.tap(find.text('New revenue'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    // The open ones, with what is open: the unpaid and the partly paid.
    expect(
      find.descendant(of: sheet, matching: find.text('Ügyfél 3')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text(huf(400000))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Ügyfél 1')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Ügyfél 2')),
    );
    await tester.pumpAndSettle();
    // What is still open, today.
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextFormField, '400000'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await tester.pumpAndSettle();
    final saved = finance.saved!;
    expect(saved.id, 2);
    expect(saved.payments.map((p) => p.amount), [500000, 400000]);
    expect(saved.isPaid, isTrue);

    // A new invoice: paid the whole today.
    await tester.tap(find.text('New revenue'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('New invoice')),
    );
    await tester.pumpAndSettle();
    await enter(tester, 'Net', '2000');
    await tester.scrollUntilVisible(
      find.text('the whole amount'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('a revenue chosen for the wrong invoice: another one chosen '
      'instead, another partner\'s, its day and amount kept', (tester) async {
    await pumpApp(tester, location: Routes.revenueRecord.path);
    await tester.tap(find.text('Ügyfél 1'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextFormField, '650000'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: dialog, matching: find.textContaining('Ügyfél 1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Which invoice was paid?'), findsOneWidget);
    // The open ones: the unpaid and the partly paid; this one marked.
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Ügyfél 3')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Ügyfél 3')),
    );
    await tester.pumpAndSettle();
    // 650 000 is more than its 300 000 open.
    await tester.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('At most ${huf(300000)}'),
      ),
      findsOneWidget,
    );
    expect(finance.moved, isNull);

    // Back to its own: saved there, nothing moved.
    await tester.tap(
      find.descendant(of: dialog, matching: find.textContaining('Ügyfél 3')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Ügyfél 1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await tester.pumpAndSettle();
    expect(finance.moved, isNull);
    expect(finance.saved!.id, 1);
    expect(finance.saved!.payments.single.amount, 650000);
  });

  testWidgets('a revenue moved to another invoice', (tester) async {
    await pumpApp(tester, location: Routes.revenueRecord.path);
    // The partly paid one's 500 000.
    await tester.tap(find.text('Ügyfél 2'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    // Deleting it is beside the title.
    expect(
      find.descendant(of: dialog, matching: find.byTooltip('Delete')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: dialog, matching: find.textContaining('Ügyfél 2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Ügyfél 3'),
      ),
    );
    await tester.pumpAndSettle();
    // It is 300 000: what came in for it.
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextFormField)).first,
      '300000',
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await tester.pumpAndSettle();
    final (to, payment, from) = finance.moved!;
    expect(to.id, 3);
    expect(from.id, 2);
    expect(payment.amount, 300000);
    expect(payment.date, DateTime(_year, 2, 10));
    expect(payment.invoiceId, 3);
  });

  testWidgets('the flat-rate tax: the current quarter first; another one or '
      'the year summary chosen, a quarter opened from it', (tester) async {
    await pumpApp(tester, location: Routes.flatRate.path);
    final current = (DateTime.now().month - 1) ~/ 3 + 1;
    FlatRateQuarterView view() =>
        tester.widget<FlatRateQuarterView>(find.byType(FlatRateQuarterView));
    expect(view().quarter, current);
    expect(find.byType(Tab), findsNothing);
    expect(find.text('To transfer'), findsOneWidget);

    Future<void> choose(String item) async {
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item).last);
      await tester.pumpAndSettle();
    }

    await choose('Year summary');
    expect(find.byType(FlatRateSummaryView), findsOneWidget);
    expect(find.text('Taxes of the year'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Quarters'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // A quarter of the summary opens it.
    await tester.ensureVisible(find.text('Q1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Q1').last);
    await tester.pumpAndSettle();
    expect(view().quarter, 1);

    await choose('Q3');
    expect(view().quarter, 3);

    // The one shown sent or saved.
    await tester.tap(find.byTooltip('Send or save'));
    await tester.pumpAndSettle();
    expect(find.text('Save as PDF'), findsOneWidget);
    expect(find.text('Save as XLSX'), findsOneWidget);
  });

  testWidgets("the dashboard's next tax payment opens that quarter", (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Flat-rate tax'));
    await tester.pumpAndSettle();
    final today = DateTime.now();
    final lastQ4 = FlatRateTax(
      const [],
      _ev,
      today.year - 1,
    ).quarters.last.deadline;
    final next = today.isAfter(lastQ4) ? (today.month - 1) ~/ 3 + 1 : 4;
    expect(
      tester
          .widget<FlatRateQuarterView>(find.byType(FlatRateQuarterView))
          .quarter,
      next,
    );
  });

  testWidgets('with EU reporting: the incoming invoices too, and the VAT', (
    tester,
  ) async {
    final eu = _ev.copyWith(euReporting: true, euVatNumber: 'HU10773381');
    await pumpApp(tester, profile: eu, location: Routes.invoices.path);
    expect(find.byType(SegmentedButton<InvoiceDirection>), findsOneWidget);
    await openMenu(tester);
    final menu = find.byType(NavigationDrawer);
    expect(
      find.descendant(of: menu, matching: find.text('Invoices')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: menu, matching: find.text('Flat-rate tax')),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, 'VAT'), findsOneWidget);
  });

  testWidgets('another currency: the MNB rate of the issue day (before the '
      'fulfillment) if reported to NAV; downloaded if missing', (tester) async {
    final euro = Invoice(
      id: 9,
      userId: 1,
      direction: InvoiceDirection.outgoing,
      number: 'E-1',
      partnerName: 'Kunde GmbH',
      partnerLocation: PartnerLocation.eu,
      issueDate: DateTime(_year, 3, 2),
      fulfillmentDate: DateTime(_year, 3, 5),
      currency: Currency.eur,
      exchangeRate: 3800000,
      netAmount: 100000,
      vatCode: VatCode.eufad37,
    );
    ExchangeRate mnb(int day, double rate) => ExchangeRate(
      source: RateSource.mnb,
      date: DateTime(_year, 3, day),
      currency: Currency.eur,
      base: Currency.huf,
      rate: rate,
    );
    await pumpApp(
      tester,
      profile: _ev.copyWith(rateSourceReported: true),
      location: Routes.invoices.path,
      withInvoices: [euro],
      rates: RateBook([mnb(2, 390), mnb(5, 395)]),
    );
    await tester.tap(find.text('Kunde GmbH'));
    await tester.pumpAndSettle();
    final rate = find.widgetWithText(InputDecorator, '390');
    await tester.scrollUntilVisible(
      rate,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('MNB'), findsWidgets);
    expect(find.textContaining('(issue)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(finance.saved!.exchangeRate, 3900000);
  });

  testWidgets('the ECB reported but no rate yet: downloaded, the failure '
      'shown, not saved', (tester) async {
    final euro = Invoice(
      id: 9,
      userId: 1,
      direction: InvoiceDirection.outgoing,
      number: 'E-1',
      partnerName: 'Kunde GmbH',
      issueDate: DateTime(_year, 3, 5),
      fulfillmentDate: DateTime(_year, 3, 5),
      currency: Currency.eur,
      exchangeRate: 3800000,
      netAmount: 100000,
      vatCode: VatCode.aam,
    );
    await pumpApp(
      tester,
      profile: _ev.copyWith(
        rateSource: RateSource.ecb,
        rateSourceReported: true,
      ),
      location: Routes.invoices.path,
      withInvoices: [euro],
    );
    await tester.tap(find.text('Kunde GmbH'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('The download failed'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byTooltip('Download the rates now'), findsOneWidget);
    // The ECB's EUR rates of the invoice's year, once by itself.
    expect(_OfflineRates.asked, [(RateSource.ecb, Currency.eur, _year)]);
    await tester.scrollUntilVisible(
      find.text('Save'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(finance.saved, isNull);
  });
}
