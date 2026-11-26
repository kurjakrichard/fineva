import 'package:fineva/config/config.dart';
import 'package:fineva/data/data_export.dart';
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
    state = FinanceState(
      loaded: true,
      profiles: initial.profiles,
      profile: initial.profile,
      accounts: initial.accounts,
      invoices: [invoice, ...initial.invoices],
    );
    return true;
  }
}

const _ev = Profile(
  id: 1,
  name: 'Kiss Anna',
  taxNumber: '10773381-2-44',
  userType: UserType.soleProprietor,
  taxRegime: TaxRegime.flatRate,
  vatStatus: VatStatus.registered,
);

void main() {
  late _FakeFinance finance;

  Future<void> pumpApp(WidgetTester tester, {Profile profile = _ev}) async {
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
        accounts: const [Account(id: 1, userId: 1, name: 'Bank')],
        invoices: [
          Invoice(
            id: 1,
            userId: 1,
            direction: InvoiceDirection.outgoing,
            number: '2026/001',
            partnerName: 'Ügyfél Kft.',
            issueDate: DateTime(DateTime.now().year, 1, 5),
            fulfillmentDate: DateTime(DateTime.now().year, 1, 5),
            netAmount: 1000000,
            vatCode: VatCode.vat27,
            vatAmount: 270000,
            payments: [
              InvoicePayment(
                date: DateTime(DateTime.now().year, 1, 20),
                amount: 1270000,
              ),
            ],
          ),
        ],
      ),
    );
    final router = GoRouter(
      navigatorKey: navigationKey,
      initialLocation: Routes.business.path,
      routes: appRoutes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          financeProvider.overrideWith(() => finance),
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

  // Scrolls the page's list (built lazily) until [finder] is there.
  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await show(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String label, String text) async {
    final finder = find.widgetWithText(TextFormField, label);
    await show(tester, finder);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  testWidgets('the tabs follow the profile; flat-rate taxes of the year', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('Flat-rate tax'), findsOneWidget);
    expect(find.text('VAT'), findsOneWidget);
    expect(find.text('Ügyfél Kft.'), findsOneWidget);
    expect(find.textContaining('2026/001 · '), findsOneWidget);

    await tap(tester, find.text('Flat-rate tax'));
    // The flat-rate tax view: a quarter or the summary chosen, sent from
    // beside it.
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.byTooltip('Send or save'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Q1').last);
    await tester.pumpAndSettle();
    // Revenue of Q1: the paid net.
    expect(find.text(Currency.huf.format(1000000, 'en')), findsWidgets);
  });

  testWidgets('KATA: only the invoices, with the revenue limit', (
    tester,
  ) async {
    await pumpApp(
      tester,
      profile: _ev.copyWith(
        taxRegime: TaxRegime.kata,
        vatStatus: VatStatus.exempt,
      ),
    );
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('KATA revenue'), findsOneWidget);
  });

  testWidgets('a new EU invoice offers the EU VAT codes and is saved', (
    tester,
  ) async {
    await pumpApp(tester);
    await tap(tester, find.text('New invoice'));
    expect(find.text('Outgoing (revenue)'), findsOneWidget);

    await enter(tester, 'Invoice number', '2026/002');
    await tap(tester, find.text('EU'));
    // The service to an EU business is the default there.
    expect(
      find.text('EUFAD37 – service to an EU business (reverse charge)'),
      findsOneWidget,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Net'), '500000');
    await tester.pumpAndSettle();
    // No VAT field for a code without a rate.
    expect(find.widgetWithText(TextFormField, 'VAT'), findsNothing);
    await tap(tester, find.text('Save'));

    final saved = finance.saved!;
    expect(saved.number, '2026/002');
    expect(saved.partnerLocation, PartnerLocation.eu);
    expect(saved.vatCode, VatCode.eufad37);
    expect(saved.netAmount, 500000);
    expect(saved.vatAmount, 0);
  });

  testWidgets('a domestic invoice gets 27% VAT from the net', (tester) async {
    await pumpApp(tester);
    await tap(tester, find.text('New invoice'));
    await enter(tester, 'Invoice number', 'A-1');
    await enter(tester, 'Net', '1000');
    expect(find.text('270'), findsOneWidget);
    await tap(tester, find.text('Save'));
    expect(finance.saved?.vatCode, VatCode.vat27);
    expect(finance.saved?.gross, 1270);
  });

  testWidgets('itemized taxation: setup, the year and the assets', (
    tester,
  ) async {
    await pumpApp(
      tester,
      profile: _ev.copyWith(
        taxRegime: TaxRegime.itemized,
        vatStatus: VatStatus.exempt,
      ),
    );
    await tap(tester, find.text('Itemized tax'));
    // No category has a treatment yet.
    expect(find.text('Add the business categories'), findsOneWidget);
    expect(find.text('Entrepreneurial income tax (9%)'), findsWidgets);

    await tap(tester, find.text('Assets'));
    expect(find.text('No assets yet.'), findsOneWidget);
    await tap(tester, find.text('New asset'));
    expect(find.text('Yearly depreciation rate'), findsOneWidget);
  });
}
