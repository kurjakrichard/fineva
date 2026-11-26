import 'package:fineva/data/data_export.dart';
import 'package:fineva/l10n/l10n.dart';
import 'package:fineva/pages/pages.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:fineva/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No database: [users] at start, the first one current. Remembers the
/// saved and the selected profile.
class _FakeFinance extends FinanceNotifier {
  _FakeFinance(this.users);

  final List<Profile> users;
  Profile? saved;
  bool? savedSelected;
  Profile? selected;

  @override
  FinanceState build() =>
      FinanceState(profiles: users, profile: users.firstOrNull, loaded: true);

  @override
  Future<bool> saveProfile(Profile profile, {bool select = false}) async {
    saved = profile;
    savedSelected = select;
    state = FinanceState(profiles: [profile], profile: profile, loaded: true);
    return true;
  }

  @override
  Future<void> selectProfile(Profile profile) async => selected = profile;
}

void main() {
  late _FakeFinance finance;

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    List<Profile> users = const [],
  }) async {
    // A phone screen.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({shareLocaleKey: 'en'});
    final prefs = await SharedPreferences.getInstance();
    finance = _FakeFinance(users);
    final router = GoRouter(
      initialLocation: Routes.onboarding.path,
      routes: [
        GoRoute(path: Routes.onboarding.path, builder: OnboardingPage.builder),
        GoRoute(
          path: Routes.dashboard.path,
          builder: (context, state) => const Text('HOME'),
        ),
      ],
    );
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

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enterText(WidgetTester tester, String label, String text) async {
    final finder = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  testWidgets('a sole proprietor gives the details and the taxation', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    expect(find.text('Welcome to Fineva!'), findsOneWidget);

    await tapText(tester, 'Next');
    expect(find.text('What will you use Fineva for?'), findsOneWidget);
    await tapText(tester, 'Sole proprietor finances');
    await enterText(tester, 'Tax number', '10773381244');

    await tapText(tester, 'Next');
    expect(find.text('Your details'), findsOneWidget);
    await enterText(tester, 'Name', ' Kiss Anna ');
    await enterText(tester, 'Address', '1234 Budapest, Fő utca 1.');
    await enterText(tester, 'Tax identification number', '8391920003');

    await tapText(tester, 'Next');
    expect(find.text('Your business'), findsOneWidget);
    await tapText(tester, 'KATA');
    await tapText(tester, 'VAT registered');
    await tapText(tester, 'EU reporting');
    // Filled in from the tax number.
    expect(find.text('HU10773381'), findsOneWidget);

    await tapText(tester, 'Get started');
    expect(
      finance.saved,
      const Profile(
        name: 'Kiss Anna',
        address: '1234 Budapest, Fő utca 1.',
        taxId: '8391920003',
        taxNumber: '10773381-2-44',
        userType: UserType.soleProprietor,
        taxRegime: TaxRegime.kata,
        vatStatus: VatStatus.registered,
        euReporting: true,
        euVatNumber: 'HU10773381',
      ),
    );
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('personal finances finish with the details, without tax number', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await tapText(tester, 'Next');
    // Personal is the default.
    await tapText(tester, 'Next');

    expect(find.text('Your details'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Tax number'), findsNothing);
    // The last step.
    expect(find.text('Get started'), findsOneWidget);
    await enterText(tester, 'Name', 'Kiss Anna');
    await tapText(tester, 'Get started');
    expect(finance.saved?.userType, UserType.personal);
    expect(finance.saved?.name, 'Kiss Anna');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets("a sole proprietor can't go on without a valid tax number", (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await tapText(tester, 'Next');
    await tapText(tester, 'Sole proprietor finances');

    await tapText(tester, 'Next');
    expect(
      find.text('A sole proprietor needs a Hungarian tax number'),
      findsOneWidget,
    );
    expect(find.text('What will you use Fineva for?'), findsOneWidget);

    // The dashes come by themselves.
    await enterText(tester, 'Tax number', '107733822');
    expect(find.text('10773382-2'), findsOneWidget);
    await enterText(tester, 'Tax number', '10773382244');
    expect(find.text('10773382-2-44'), findsOneWidget);
    await tapText(tester, 'Next');
    expect(find.text('Not a valid tax number (12345678-1-12)'), findsOneWidget);
    expect(find.text('What will you use Fineva for?'), findsOneWidget);

    // Swiping doesn't skip the check.
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('What will you use Fineva for?'), findsOneWidget);

    await enterText(tester, 'Tax number', '10773381-2-44');
    await tapText(tester, 'Next');
    expect(find.text('Your details'), findsOneWidget);
  });

  testWidgets('the details step needs a name and a valid tax id', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await tapText(tester, 'Next');
    await tapText(tester, 'Next');

    await tapText(tester, 'Get started');
    expect(find.text('Name is required'), findsOneWidget);

    await enterText(tester, 'Name', 'Kiss Anna');
    await enterText(tester, 'Tax identification number', '8391920004');
    await tapText(tester, 'Get started');
    expect(find.text('Name is required'), findsNothing);
    expect(find.text('Not a valid tax identification number'), findsOneWidget);
    expect(finance.saved, isNull);

    await enterText(tester, 'Tax identification number', '8391920003');
    await tapText(tester, 'Get started');
    expect(finance.saved?.taxId, '8391920003');
  });

  testWidgets('EU reporting needs an EU VAT number that matches the tax '
      'number', (tester) async {
    await pumpOnboarding(tester);
    await tapText(tester, 'Next');
    await tapText(tester, 'Sole proprietor finances');
    await enterText(tester, 'Tax number', '10773381-2-44');
    await tapText(tester, 'Next');
    await enterText(tester, 'Name', 'Kiss Anna');
    await tapText(tester, 'Next');

    await tapText(tester, 'EU reporting');
    await enterText(tester, 'EU VAT number', '');
    await tapText(tester, 'Get started');
    expect(find.text('EU reporting needs your EU VAT number'), findsOneWidget);
    expect(finance.saved, isNull);

    await enterText(tester, 'EU VAT number', 'HU10773382');
    await tapText(tester, 'Get started');
    expect(find.text('Not a valid EU VAT number (HU12345678)'), findsOneWidget);

    // Valid, but another taxpayer's.
    await enterText(tester, 'EU VAT number', 'HU12345676');
    await tapText(tester, 'Get started');
    expect(
      find.text("It doesn't match your tax number: HU and its first 8 digits"),
      findsOneWidget,
    );
    expect(finance.saved, isNull);

    await enterText(tester, 'EU VAT number', 'hu 10773381');
    await tapText(tester, 'Get started');
    expect(finance.saved?.euVatNumber, 'HU10773381');
  });

  testWidgets('without EU reporting no EU VAT number is asked', (tester) async {
    await pumpOnboarding(tester);
    await tapText(tester, 'Next');
    await tapText(tester, 'Sole proprietor finances');
    await enterText(tester, 'Tax number', '10773381-2-44');
    await tapText(tester, 'Next');
    await enterText(tester, 'Name', 'Kiss Anna');
    await tapText(tester, 'Next');

    expect(find.widgetWithText(TextFormField, 'EU VAT number'), findsNothing);
    await tapText(tester, 'Get started');
    expect(finance.saved?.euReporting, isFalse);
    expect(finance.saved?.euVatNumber, '');
  });

  group('with users', () {
    const anna = Profile(id: 1, name: 'Kiss Anna');
    const bela = Profile(
      id: 2,
      name: 'Nagy Béla',
      taxNumber: '10773381-2-44',
      userType: UserType.soleProprietor,
    );

    testWidgets('the current user can skip the rest', (tester) async {
      await pumpOnboarding(tester, users: [anna, bela]);
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Kiss Anna'), findsOneWidget);
      expect(find.text('Nagy Béla'), findsOneWidget);

      await tapText(tester, 'Skip');
      expect(finance.selected, anna);
      expect(finance.saved, isNull);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets("another user's details are filled in and saved", (
      tester,
    ) async {
      await pumpOnboarding(tester, users: [anna, bela]);
      await tapText(tester, 'Nagy Béla');
      await tapText(tester, 'Next');
      // Their user type is chosen.
      await tapText(tester, 'Next');
      expect(find.text('Your details'), findsOneWidget);
      expect(find.text('Nagy Béla'), findsOneWidget);
      // The main currency was chosen when the user was made.
      expect(find.byType(MainCurrencyField), findsNothing);
      await enterText(tester, 'Address', 'Szeged');
      await tapText(tester, 'Next');
      expect(find.text('Your business'), findsOneWidget);
      await tapText(tester, 'Get started');

      expect(finance.saved, bela.copyWith(address: 'Szeged'));
      expect(finance.savedSelected, isTrue);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets("an existing user's kind can't change", (tester) async {
      await pumpOnboarding(tester, users: [anna, bela]);
      await tapText(tester, 'Next');
      expect(
        find.text("A user's kind can't change after it is created."),
        findsOneWidget,
      );
      await tapText(tester, 'Sole proprietor finances');
      // Still personal: no tax number asked, the details come next.
      expect(find.text('Tax number'), findsNothing);
      await tapText(tester, 'Next');
      expect(find.text('Your details'), findsOneWidget);
      await tapText(tester, 'Get started');
      expect(finance.saved?.userType, UserType.personal);
    });

    testWidgets('a new user starts empty and has nothing to skip', (
      tester,
    ) async {
      await pumpOnboarding(tester, users: [anna]);
      await tapText(tester, 'New user');
      expect(find.text('Skip'), findsNothing);
      await tapText(tester, 'Next');
      await tapText(tester, 'Next');
      expect(find.text('Kiss Anna'), findsNothing);
      // A new personal user chooses the main currency, once.
      expect(find.byType(MainCurrencyField), findsOneWidget);
      await enterText(tester, 'Name', 'Új Ember');
      await tapText(tester, 'Get started');

      expect(finance.saved?.id, isNull);
      expect(finance.saved?.name, 'Új Ember');
    });
  });
}
