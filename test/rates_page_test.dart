import 'package:fineva/data/data_export.dart';
import 'package:fineva/l10n/l10n.dart';
import 'package:fineva/pages/pages.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:fineva/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No database: the given state; remembers what was saved.
class _FakeFinance extends FinanceNotifier {
  _FakeFinance(this.initial);

  final FinanceState initial;
  final saved = <Object>[];

  @override
  FinanceState build() => initial;

  @override
  Future<bool> saveProfile(Profile profile, {bool select = false}) async {
    saved.add(profile);
    return true;
  }

  @override
  Future<bool> saveManualRate(ExchangeRate rate) async {
    saved.add(rate);
    return true;
  }
}

/// No network: counts the downloads asked for.
class _FakeRates extends RatesNotifier {
  int updates = 0;

  @override
  Future<void> update({bool atStart = false}) async => updates++;
}

void main() {
  late _FakeFinance finance;
  late _FakeRates rates;

  Future<void> pumpPage(WidgetTester tester, Profile profile) async {
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
        accounts: const [
          Account(id: 1, userId: 1, name: 'Bank'),
          Account(id: 2, userId: 1, name: 'Euro', currency: Currency.eur),
        ],
        rates: RateBook([
          ExchangeRate(
            source: RateSource.mnb,
            date: DateTime(2026, 11, 20),
            currency: Currency.eur,
            base: Currency.huf,
            rate: 380,
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
          home: const RatesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("today's rate of each other currency; another source "
      'downloads', (tester) async {
    await pumpPage(tester, const Profile(id: 1, name: 'Anna'));
    expect(find.text('1 EUR = 380.00 Ft'), findsOneWidget);
    expect(find.textContaining('MNB'), findsWidgets);
    // Chosen when the user was made: not here.
    expect(find.byType(MainCurrencyField), findsNothing);
    expect(find.text('HUF – Hungarian forint'), findsOneWidget);

    await tester.tap(find.text('ECB'));
    await tester.pumpAndSettle();
    expect((finance.saved.single as Profile).rateSource, RateSource.ecb);
    expect(rates.updates, 1);

    // Manual: nothing to download.
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    expect(rates.updates, 1);
  });

  testWidgets('a rate typed in, in the main currency', (tester) async {
    await pumpPage(tester, const Profile(id: 1, name: 'Anna'));
    await tester.tap(find.text('Manual rate'));
    await tester.pumpAndSettle();
    // The user's currency first.
    expect(find.text('EUR – Euro'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Give a positive number'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '385,5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final rate = finance.saved.single as ExchangeRate;
    expect(rate.source, RateSource.manual);
    expect(rate.currency, Currency.eur);
    expect(rate.base, Currency.huf);
    expect(rate.rate, 385.5);
    expect(rate.date, currentDay());
  });

  testWidgets("a sole proprietor's main currency is the forint", (
    tester,
  ) async {
    await pumpPage(
      tester,
      const Profile(
        id: 1,
        name: 'Béla',
        taxNumber: '10773381-2-44',
        userType: UserType.soleProprietor,
      ),
    );
    expect(find.byType(MainCurrencyField), findsNothing);
    expect(find.text('HUF – Hungarian forint'), findsOneWidget);
  });
}
