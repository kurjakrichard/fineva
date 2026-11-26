import 'package:fineva/data/data_export.dart';
import 'package:fineva/l10n/l10n.dart';
import 'package:fineva/pages/pages.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No database: the given state; remembers what was saved.
class _FakeFinance extends FinanceNotifier {
  _FakeFinance(this.initial);

  final FinanceState initial;
  final entries = <Entry>[];
  final rates = <ExchangeRate>[];

  @override
  FinanceState build() => initial;

  @override
  Future<bool> saveEntry(Entry entry) async {
    entries.add(entry);
    return true;
  }

  @override
  Future<bool> saveManualRate(ExchangeRate rate) async {
    rates.add(rate);
    return true;
  }
}

/// No network: counts the downloads asked for.
class _FakeRates extends RatesNotifier {
  int updates = 0;

  @override
  Future<void> update({bool atStart = false}) async => updates++;
}

const _anna = Profile(id: 1, name: 'Anna');
const _euro = Account(id: 2, userId: 1, name: 'Euro', currency: Currency.eur);

void main() {
  late _FakeFinance finance;
  late _FakeRates rates;

  /// A new entry on the euro account, opened from a button.
  Future<void> pumpEntry(WidgetTester tester, {bool withRates = true}) async {
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
        accounts: const [
          Account(id: 1, userId: 1, name: 'Bank'),
          _euro,
        ],
        rates: RateBook([
          if (withRates)
            ExchangeRate(
              source: RateSource.mnb,
              date: DateTime(2026, 11, 20),
              currency: Currency.eur,
              base: Currency.huf,
              rate: 380.1234,
            ),
        ]),
      ),
    );
    rates = _FakeRates();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          financeProvider.overrideWith(() => finance),
          ratesProvider.overrideWith(() => rates),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const EntryPage(account: _euro),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder rateField() => find.widgetWithText(TextFormField, 'Exchange rate');

  Future<void> save(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '10');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets("the day's downloaded rate is offered and saved exactly", (
    tester,
  ) async {
    await pumpEntry(tester);
    expect(
      find.descendant(of: rateField(), matching: find.text('380.12')),
      findsOneWidget,
    );
    expect(find.textContaining('Ft / 1 EUR on the day · MNB'), findsOneWidget);
    await save(tester);
    final entry = finance.entries.single;
    expect(entry.rate, 380.1234);
    expect(entry.rateSource, RateSource.mnb);
    expect(finance.rates, isEmpty);
  });

  testWidgets('a rate typed in is marked, can go back to the downloaded one, '
      "and is the day's rate when saved", (tester) async {
    await pumpEntry(tester);
    await tester.enterText(rateField(), '385,5');
    await tester.pumpAndSettle();
    expect(find.textContaining('· typed in'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to the downloaded rate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('· MNB'), findsOneWidget);
    expect(find.byTooltip('Back to the downloaded rate'), findsNothing);

    await tester.enterText(rateField(), '385,5');
    await tester.pumpAndSettle();
    await save(tester);
    final entry = finance.entries.single;
    expect(entry.rate, 385.5);
    expect(entry.rateSource, RateSource.manual);
    final rate = finance.rates.single;
    expect(rate.source, RateSource.manual);
    expect(rate.currency, Currency.eur);
    expect(rate.base, Currency.huf);
    expect(rate.rate, 385.5);
    expect(rate.date, entry.date);
  });

  testWidgets('without rates the field offers to download them', (
    tester,
  ) async {
    await pumpEntry(tester, withRates: false);
    expect(find.textContaining('no downloaded rate'), findsOneWidget);
    await tester.tap(find.byTooltip('Download the rates now'));
    await tester.pumpAndSettle();
    expect(rates.updates, 1);
    // A private person's rate isn't required.
    await save(tester);
    expect(finance.entries.single.rate, isNull);
  });
}
