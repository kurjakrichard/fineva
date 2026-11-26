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
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No database: the given state.
class _FakeFinance extends FinanceNotifier {
  _FakeFinance(this.initial);

  final FinanceState initial;

  @override
  FinanceState build() => initial;

  /// The user switched to.
  Profile? selected;

  /// A new user saved becomes the current one.
  @override
  Future<bool> saveProfile(Profile profile, {bool select = false}) async {
    final saved = Profile(id: state.profiles.length + 1, name: profile.name);
    state = FinanceState(
      loaded: true,
      profiles: [...state.profiles, saved],
      profile: saved,
    );
    return true;
  }

  @override
  Future<void> selectProfile(Profile profile) async {
    selected = profile;
    state = FinanceState(
      loaded: true,
      profiles: state.profiles,
      profile: profile,
    );
  }

  /// Replaces the entry of the same id.
  @override
  Future<bool> saveEntry(Entry entry) async {
    state = FinanceState(
      loaded: true,
      profiles: state.profiles,
      profile: state.profile,
      accounts: state.accounts,
      categories: state.categories,
      entries: [for (final e in state.entries) e.id == entry.id ? entry : e],
    );
    return true;
  }
}

const _anna = Profile(id: 1, name: 'Kiss Anna');

FinanceState _state({int entries = 7}) {
  final today = DateTime.now();
  return FinanceState(
    loaded: true,
    profiles: const [_anna],
    profile: _anna,
    accounts: const [Account(id: 1, userId: 1, name: 'Wallet')],
    entries: [
      for (var i = 0; i < entries; i++)
        Entry(
          id: i + 1,
          accountId: 1,
          type: i == 0 ? EntryType.income : EntryType.expense,
          amount: i == 0 ? 10000 : 100,
          date: today,
        ),
    ],
  );
}

void main() {
  /// The app's routes at the dashboard, on a screen [width] logical pixels
  /// wide.
  Future<void> pumpApp(
    WidgetTester tester, {
    required double width,
    FinanceState? state,
  }) async {
    tester.view.physicalSize = Size(width * 2, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({shareLocaleKey: 'en'});
    final prefs = await SharedPreferences.getInstance();
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
          financeProvider.overrideWith(() => _FakeFinance(state ?? _state())),
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

  String? title(WidgetTester tester) {
    final appBars = tester.widgetList<AppBar>(find.byType(AppBar));
    var title = appBars.last.title;
    // The statistics' title fits beside the period.
    if (title is FittedBox) title = title.child;
    return (title as Text?)?.data;
  }

  group('phone', () {
    testWidgets('the dashboard shows the balance and the latest entries', (
      tester,
    ) async {
      await pumpApp(tester, width: 400);
      expect(find.byType(BalanceCard), findsOneWidget);
      expect(find.byType(EntryTile), findsNWidgets(5));

      // The entries page, filtered to the month.
      await tester.tap(find.text('All (7)'));
      await tester.pumpAndSettle();
      expect(title(tester), 'Entries');
      expect(find.byType(EntryTile), findsNWidgets(7));
      expect(find.text('7 entries'), findsOneWidget);
      expect(
        find.text(DateFormat.yMMMM('en').format(DateTime.now())),
        findsOneWidget,
      );
    });

    testWidgets('the dashboard shows the period chosen in the app bar, '
        'and the statistics the same', (tester) async {
      await pumpApp(tester, width: 400);
      final now = DateTime.now();
      final thisMonth = DateFormat.yMMMM('en').format(now);
      final thisMonthShort = DateFormat.yMMM('en').format(now);
      // Short in the app bar, whole on the card.
      expect(find.text(thisMonthShort), findsOneWidget);
      expect(find.text(thisMonth), findsOneWidget);
      // No next month: it is the future.
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(next.onPressed, isNull);

      await tester.tap(find.byTooltip('Previous'));
      await tester.pumpAndSettle();
      final before = DateTime(now.year, now.month - 1);
      expect(find.text(DateFormat.yMMM('en').format(before)), findsOneWidget);
      expect(find.text(DateFormat.yMMMM('en').format(before)), findsOneWidget);
      // Every entry is in this month.
      expect(find.text('No entries in this period.'), findsOneWidget);
      expect(find.byType(EntryTile), findsNothing);

      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryTile), findsNWidgets(5));

      // Another kind of period in the picker.
      await tester.tap(
        find.descendant(
          of: find.byType(PeriodBar),
          matching: find.text(thisMonthShort),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose period'), findsOneWidget);
      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      expect(find.text('${now.year}'), findsNWidgets(2));
      expect(find.byType(EntryTile), findsNWidgets(5));

      await tester.tap(
        find.descendant(
          of: find.byType(PeriodBar),
          matching: find.text('${now.year}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();
      expect(find.text('All time'), findsNWidgets(2));
      final previous = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );
      expect(previous.onPressed, isNull);
      // The balances of now.
      expect(find.text('Balance'), findsOneWidget);

      // The statistics show the same period.
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();
      expect(title(tester), 'Statistics');
      expect(find.text('All time'), findsOneWidget);
    });

    testWidgets('the entries can be searched and filtered', (tester) async {
      await pumpApp(tester, width: 400);
      await tester.tap(find.text('All (7)'));
      await tester.pumpAndSettle();
      // The month filter from the dashboard: a chip, and one on the badge.
      final month = DateFormat.yMMMM('en').format(DateTime.now());
      expect(find.widgetWithText(InputChip, month), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove the filter'));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(find.byType(EntryTile), findsNWidgets(7));

      // The filters in the bottom sheet: the one income.
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Income').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryTile), findsOneWidget);
      expect(find.text('1 entry'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Income'), findsOneWidget);

      // The search in the app bar: nothing found.
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '9999');
      await tester.pumpAndSettle();
      expect(find.text('No entries match the search and filters.'), findsOne);

      // Closing the search gives back the filtered list.
      await tester.tap(find.byTooltip('Clear the search'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(EntryTile), findsOneWidget);

      // The order: the oldest first, then back.
      await tester.tap(find.byTooltip('Order'));
      await tester.pumpAndSettle();
      Finder sortItem(String label) =>
          find.widgetWithText(CheckedPopupMenuItem<EntrySort>, label);
      await tester.tap(sortItem('The oldest first'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Order'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckedPopupMenuItem<EntrySort>>(
              sortItem('The oldest first'),
            )
            .checked,
        isTrue,
      );
      await tester.tap(sortItem('The newest first'));
      await tester.pumpAndSettle();

      // Clearing the filters in the sheet.
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryTile), findsNWidgets(7));

      // A period from the picker of the sheet.
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsOneWidget);
      expect(find.byType(EntryTile), findsNWidgets(7));
    });

    testWidgets('an entry of the dashboard opens with its category', (
      tester,
    ) async {
      const food = EntryCategory(
        id: 1,
        userId: 1,
        name: 'Food',
        type: EntryType.expense,
      );
      final state = _state();
      await pumpApp(
        tester,
        width: 400,
        state: FinanceState(
          loaded: true,
          profiles: state.profiles,
          profile: state.profile,
          accounts: state.accounts,
          categories: const [food],
          entries: [
            Entry(
              id: 1,
              accountId: 1,
              categoryId: 1,
              type: EntryType.expense,
              amount: 100,
              date: DateTime.now(),
            ),
          ],
        ),
      );
      // To look at it first.
      await tester.tap(find.byType(EntryTile));
      await tester.pumpAndSettle();
      expect(title(tester), 'Entry');
      expect(find.text('Food'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      // One edit button, in the app bar; the button below closes it.
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(BalanceCard), findsOneWidget);
      await tester.tap(find.byType(EntryTile));
      await tester.pumpAndSettle();
      // The app bar's edit button switches to editing.
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(title(tester), 'Edit entry');
      // The category field, as wide as the form.
      expect(
        find.descendant(
          of: find.byType(DropdownButtonFormField<int?>),
          matching: find.text('Food'),
        ),
        findsOneWidget,
      );

      // Dropping the changes goes back to looking at it, saving too.
      await tester.enterText(find.byType(TextFormField).first, '250');
      await tester.tap(find.byTooltip('Discard the changes'));
      await tester.pumpAndSettle();
      expect(title(tester), 'Entry');
      // The amount, and the account's balance after it (its only entry).
      expect(find.text('Balance after it'), findsOneWidget);
      expect(find.text('-Ft100'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '250');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(title(tester), 'Entry');
      // The balance after it changed too.
      expect(find.text('-Ft250'), findsNWidgets(2));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(BalanceCard), findsOneWidget);

      // The list's edit button: right to editing, back to the list.
      await tester.tap(find.byTooltip('Edit entry'));
      await tester.pumpAndSettle();
      expect(title(tester), 'Edit entry');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(BalanceCard), findsOneWidget);
    });

    testWidgets('the drawer switches pages; back goes to the dashboard', (
      tester,
    ) async {
      await pumpApp(tester, width: 400);
      expect(find.byType(NavigationRail), findsNothing);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      final drawer = find.byType(NavigationDrawer);
      expect(tester.widget<NavigationDrawer>(drawer).selectedIndex, 0);
      expect(
        find.descendant(of: drawer, matching: find.text('Kiss Anna')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: drawer, matching: find.text('Statistics')),
      );
      await tester.pumpAndSettle();
      expect(title(tester), 'Statistics');
      expect(drawer, findsNothing);
      // The month's figures.
      expect(find.text('Savings rate'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BalanceCard), findsOneWidget);
    });

    testWidgets('without accounts the dashboard asks for one', (tester) async {
      await pumpApp(
        tester,
        width: 400,
        state: const FinanceState(
          loaded: true,
          profiles: [_anna],
          profile: _anna,
        ),
      );
      expect(find.text('New account'), findsOneWidget);
    });
  });

  testWidgets("an account opens with its entries by day, beside the menu", (
    tester,
  ) async {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    await pumpApp(
      tester,
      width: 1400,
      state: FinanceState(
        loaded: true,
        profiles: const [_anna],
        profile: _anna,
        accounts: const [
          Account(id: 1, userId: 1, name: 'Wallet'),
          Account(id: 2, userId: 1, name: 'Bank'),
        ],
        balances: const {1: 900, 2: 5000},
        entries: [
          Entry(
            id: 3,
            accountId: 1,
            type: EntryType.expense,
            amount: 300,
            date: DateTime(today.year, today.month, today.day),
          ),
          Entry(
            id: 2,
            accountId: 2,
            type: EntryType.income,
            amount: 5000,
            date: yesterday,
          ),
          Entry(
            id: 1,
            accountId: 1,
            type: EntryType.income,
            amount: 200,
            date: yesterday,
          ),
          Entry(
            id: 4,
            accountId: 1,
            type: EntryType.income,
            amount: 1000,
            date: DateTime(today.year, today.month, today.day - 2),
            opening: true,
          ),
        ],
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.text('Accounts'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(title(tester), 'Wallet');
    // The menu stays, with the accounts chosen.
    final menu = tester.widget<NavigationDrawer>(find.byType(NavigationDrawer));
    expect(
      menu.selectedIndex,
      MainDestination.visible(_anna).indexOf(MainDestination.accounts),
    );
    // Three days of the wallet only, each with its closing balance; the
    // first one the opening entry's.
    expect(find.byType(EntryTile), findsNWidgets(3));
    expect(find.text('Ft900'), findsWidgets); // today, and now
    expect(find.text('Ft1,200'), findsOneWidget); // yesterday
    expect(find.text('Ft1,000'), findsWidgets); // the opening day
    expect(find.text('Opening balance'), findsOneWidget);
    // It has one: nothing to give.
    expect(find.text('Give the opening balance'), findsNothing);

    // Searched or filtered: the entries found, no balances.
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    // No account to choose: it's this one.
    expect(
      find.widgetWithText(DropdownButtonFormField<int?>, 'Account'),
      findsNothing,
    );
    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryTile), findsOneWidget);
    expect(find.text('1 entry'), findsOneWidget);
    expect(find.text('Ft1,200'), findsNothing);
    expect(find.byTooltip('Edit account'), findsNothing);
    // A filtered list can be sorted; the statement can't.
    expect(find.byTooltip('Order'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove the filter'));
    await tester.pumpAndSettle();
    expect(find.text('Ft1,200'), findsOneWidget);
    expect(find.byTooltip('Order'), findsNothing);

    // An entry: a tap to look at it, its edit button to edit it.
    await tester.tap(find.byType(EntryTile).first);
    await tester.pumpAndSettle();
    expect(title(tester), 'Entry');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit entry').first);
    await tester.pumpAndSettle();
    expect(title(tester), 'Edit entry');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(title(tester), 'Wallet');

    // The account is edited from its balance; with entries it can't be
    // deleted.
    await tester.tap(find.byTooltip('Edit account'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('It has 3 entries'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // A new entry is on this account.
    await tester.tap(find.byTooltip('New entry'));
    await tester.pumpAndSettle();
    expect(title(tester), 'New entry');
    expect(find.byType(NavigationDrawer), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DropdownButtonFormField<int>),
        matching: find.text('Wallet (HUF)'),
      ),
      findsOneWidget,
    );

    // Back: the account again, then the accounts.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(title(tester), 'Wallet');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(title(tester), 'Accounts');
  });

  testWidgets('an account without an opening entry offers to give one', (
    tester,
  ) async {
    await pumpApp(tester, width: 1400);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.text('Accounts'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give the opening balance'));
    await tester.pumpAndSettle();
    expect(title(tester), 'Give the opening balance');
    // A signed amount, no type or category.
    expect(find.byType(SegmentedButton<EntryType>), findsNothing);
    expect(find.byType(DropdownButtonFormField<int?>), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('other than 0'), findsOneWidget);
  });

  testWidgets('on a phone the back button stays, the menu opens by swiping', (
    tester,
  ) async {
    await pumpApp(tester, width: 400);
    await tester.tap(find.byType(EntryTile).first);
    await tester.pumpAndSettle();
    expect(title(tester), 'Entry');
    expect(find.byType(BackButton), findsOneWidget);
    await tester.dragFrom(const Offset(2, 300), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDrawer), findsOneWidget);
  });

  testWidgets("the user is switched in the menu's dropdown, after asking", (
    tester,
  ) async {
    const bela = Profile(id: 2, name: 'Nagy Béla');
    final state = _state();
    await pumpApp(
      tester,
      width: 400,
      state: FinanceState(
        loaded: true,
        profiles: const [_anna, bela],
        profile: _anna,
        accounts: state.accounts,
        entries: state.entries,
      ),
    );
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch user'));
    await tester.pumpAndSettle();
    // The users.
    expect(find.text('Nagy Béla'), findsOneWidget);

    // Asked first: cancelled, nothing changes.
    await tester.tap(find.text('Nagy Béla'));
    await tester.pumpAndSettle();
    expect(find.text('Switch to Nagy Béla?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final finance = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    ).read(financeProvider.notifier) as _FakeFinance;
    expect(finance.selected, isNull);

    // Switched: their dashboard.
    await tester.tap(find.byTooltip('Switch user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nagy Béla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();
    expect(finance.selected, bela);
    expect(find.byType(NavigationDrawer), findsNothing);
    expect(title(tester), 'Fineva');

    // A new user, from the same menu: their kind, details, then theirs.
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New user'));
    await tester.pumpAndSettle();
    expect(title(tester), 'New user');
    expect(find.byType(UserTypeChoice), findsOneWidget);
    // Given up: back, nothing saved.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(title(tester), 'Fineva');
    expect(finance.state.profiles, hasLength(2));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New user'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Új Ember',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(title(tester), 'Fineva');
    expect(finance.state.profile?.name, 'Új Ember');
  });

  testWidgets("the settings have the user's profile, no managing the users; "
      'the profile no kind to choose', (tester) async {
    await pumpApp(tester, width: 1400);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Users'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Kiss Anna'),
      ),
    );
    await tester.pumpAndSettle();
    expect(title(tester), 'Profile');
    expect(find.byType(UserTypeChoice), findsNothing);
    expect(find.byType(UserDataForm), findsOneWidget);
    // Left without saving.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(title(tester), 'Settings');
  });

  testWidgets('a closed account is apart; an account with money can not be '
      'closed', (tester) async {
    final state = _state();
    await pumpApp(
      tester,
      width: 1400,
      state: FinanceState(
        loaded: true,
        profiles: state.profiles,
        profile: state.profile,
        accounts: [
          ...state.accounts,
          Account(
            id: 2,
            userId: 1,
            name: 'Old bank',
            type: AccountType.bank,
            closedDate: DateTime(2026, 6, 30),
          ),
        ],
        entries: state.entries,
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.text('Accounts'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Closed accounts'), findsOneWidget);
    expect(find.textContaining('Closed on'), findsOneWidget);

    // The wallet has money: closing it is refused, with the reason.
    await tester.longPress(find.text('Wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account closed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('only a 0 balance can be closed'), findsOne);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    // A cash account has no number.
    expect(
      find.widgetWithText(TextFormField, 'Account number or IBAN'),
      findsNothing,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // A bank account's details are optional, but checked when given.
    await tester.longPress(find.text('Old bank'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account number or IBAN'),
      '12345',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Not a valid account number or IBAN'), findsOneWidget);
  });

  testWidgets('a tablet has a navigation rail', (tester) async {
    await pumpApp(tester, width: 900);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsNothing);

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(title(tester), 'Accounts');
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      // No business page for personal finances.
      MainDestination.visible(_anna).indexOf(MainDestination.accounts),
    );
  });

  testWidgets('the statistics have the period in the app bar and note a '
      'currency without exchange rate', (tester) async {
    final state = _state();
    await pumpApp(
      tester,
      width: 1400,
      state: FinanceState(
        loaded: true,
        profiles: state.profiles,
        profile: state.profile,
        accounts: const [
          Account(id: 1, userId: 1, name: 'Wallet'),
          Account(id: 2, userId: 1, name: 'Euro', currency: Currency.eur),
        ],
        entries: state.entries,
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.text('Statistics'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(PeriodBar),
      ),
      findsOneWidget,
    );
    expect(find.text('No exchange rate: EUR'), findsOneWidget);

    // The rates page from the note.
    await tester.tap(find.text('Exchange rates'));
    await tester.pumpAndSettle();
    expect(title(tester), 'Exchange rates');
    expect(find.text('1 EUR'), findsOneWidget);
  });

  testWidgets('one currency: nothing to note', (tester) async {
    await pumpApp(tester, width: 1400);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.text('Statistics'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MissingRatesNote), findsNothing);
  });

  testWidgets('a wide screen has the menu always open', (tester) async {
    await pumpApp(tester, width: 1400);
    expect(find.byType(NavigationDrawer), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byTooltip('Open navigation menu'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.text('Statistics'),
      ),
    );
    await tester.pumpAndSettle();
    expect(title(tester), 'Statistics');
    // The tabs.
    await tester.tap(find.text('Cash flow'));
    await tester.pumpAndSettle();
    expect(find.text('Net'), findsWidgets);
    await tester.tap(find.text('Balance'));
    await tester.pumpAndSettle();
    expect(find.text('Closing balance'), findsOneWidget);
    await tester.tap(find.text('Categories').last);
    await tester.pumpAndSettle();
    expect(find.text('No category'), findsOneWidget);
  });
}
