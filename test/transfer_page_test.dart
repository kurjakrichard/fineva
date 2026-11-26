import 'package:fineva/config/config.dart';
import 'package:fineva/data/data_export.dart';
import 'package:fineva/l10n/l10n.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:fineva/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No database: the given state; remembers the transfer saved.
class _FakeFinance extends FinanceNotifier {
  _FakeFinance(this.initial);

  final FinanceState initial;
  ({Entry from, Entry to, List<ExchangeRate> dayRates})? saved;

  @override
  FinanceState build() => initial;

  @override
  Future<bool> saveTransfer(
    int? id,
    Entry from,
    Entry to, {
    List<ExchangeRate> dayRates = const [],
  }) async {
    saved = (from: from, to: to, dayRates: dayRates);
    return true;
  }
}

const _anna = Profile(id: 1, name: 'Anna');
const _accounts = [
  Account(id: 1, userId: 1, name: 'Bank'),
  Account(id: 2, userId: 1, name: 'Euro', currency: Currency.eur),
];

void main() {
  late _FakeFinance finance;

  Future<void> pumpApp(
    WidgetTester tester, {
    List<Entry> entries = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({shareLocaleKey: 'en'});
    final prefs = await SharedPreferences.getInstance();
    finance = _FakeFinance(
      FinanceState(
        loaded: true,
        profiles: const [_anna],
        profile: _anna,
        accounts: _accounts,
        entries: entries,
      ),
    );
    final router = GoRouter(
      navigatorKey: navigationKey,
      initialLocation: Routes.dashboard.path,
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

  testWidgets('a new entry can be a transfer: forints to euros, the rate '
      'made from the two amounts', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('New entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(find.text('New transfer'), findsOneWidget);

    // From the bank (the entry's account) to the euro account.
    await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Euro (EUR)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '390000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Received'),
      '1000',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 EUR = 390 Ft: made from the two amounts'), findsOne);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = finance.saved!;
    expect(saved.from.accountId, 1);
    expect(saved.from.amount, 390000);
    expect(saved.to.accountId, 2);
    expect(saved.to.amount, 100000);
    expect(saved.to.rate, 390);
    expect(saved.dayRates.single.rate, 390);
  });

  testWidgets('the same account on both sides is refused', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('New entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank (HUF)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Choose another account'), findsWidgets);
    expect(finance.saved, isNull);
  });

  testWidgets('a side of a transfer opens the transfer to look at, then to '
      'edit', (tester) async {
    final day = DateTime.now();
    await pumpApp(
      tester,
      entries: [
        Entry(
          id: 2,
          accountId: 2,
          type: EntryType.income,
          amount: 100000,
          date: day,
          rate: 390,
          rateSource: RateSource.manual,
          transferId: 7,
        ),
        Entry(
          id: 1,
          accountId: 1,
          type: EntryType.expense,
          amount: 390000,
          date: day,
          transferId: 7,
        ),
      ],
    );
    // Both sides, each with the other account; no income or expense.
    expect(find.text('Transfer'), findsNWidgets(2));
    expect(find.textContaining('To Euro'), findsOneWidget);
    expect(find.textContaining('From Bank'), findsOneWidget);

    await tester.tap(find.byType(EntryTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Worth'), findsOneWidget);
    expect(find.text('Ft390,000'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit transfer'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Received'),
        matching: find.text('1000.00'),
      ),
      findsOneWidget,
    );
    // Back to looking at it.
    await tester.tap(find.byTooltip('Discard the changes'));
    await tester.pumpAndSettle();
    expect(find.text('Worth'), findsOneWidget);
  });
}
