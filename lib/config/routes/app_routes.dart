import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../data/data_export.dart';
import '../../pages/pages.dart';
import '../../utils/utils.dart';
import '../../widgets/widgets.dart';
import 'routes_provider.dart';

/// A page of the menu: inside [MainShell], switched without animation.
GoRoute _mainRoute(Routes route, Widget page) => GoRoute(
  name: route.name,
  path: route.path,
  pageBuilder: (context, state) => NoTransitionPage(child: page),
);

final List<RouteBase> appRoutes = [
  GoRoute(
    name: Routes.splash.name,
    path: Routes.splash.path,
    parentNavigatorKey: navigationKey,
    builder: SplashPage.builder,
  ),
  GoRoute(
    name: Routes.onboarding.name,
    path: Routes.onboarding.path,
    parentNavigatorKey: navigationKey,
    builder: OnboardingPage.builder,
  ),
  ShellRoute(
    builder: (context, state, child) =>
        MainShell(location: state.uri.path, child: child),
    routes: [
      _mainRoute(Routes.dashboard, const DashboardPage()),
      GoRoute(
        // `?from=2026-11-01&to=2026-11-30` filters the entries to a period.
        name: Routes.entries.name,
        path: Routes.entries.path,
        pageBuilder: (context, state) => NoTransitionPage(
          child: EntriesPage(
            // A new page for another period.
            key: ValueKey(state.uri.query),
            period: EntriesPage.parsePeriod(state.uri.queryParameters),
          ),
        ),
      ),
      _mainRoute(Routes.business, const BusinessPage()),
      // An invoices only user's (Profile.invoicesOnly).
      _mainRoute(Routes.invoices, const InvoicesPage()),
      _mainRoute(Routes.revenueRecord, const RevenueRecordPage()),
      GoRoute(
        // `?quarter=2` shows that quarter first (the dashboard's next
        // payment).
        name: Routes.flatRate.name,
        path: Routes.flatRate.path,
        pageBuilder: (context, state) => NoTransitionPage(
          child: FlatRateTaxPage(
            key: ValueKey(state.uri.query),
            quarter: int.tryParse(state.uri.queryParameters['quarter'] ?? ''),
          ),
        ),
      ),
      _mainRoute(Routes.statistics, const StatisticsPage()),
      GoRoute(
        name: Routes.accounts.name,
        path: Routes.accounts.path,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AccountsPage()),
        routes: [
          // An account's entries with the daily balances: /accounts/3.
          GoRoute(
            name: Routes.account.name,
            path: ':id',
            builder: AccountPage.builder,
          ),
        ],
      ),
      _mainRoute(Routes.categories, const CategoriesPage()),
      _mainRoute(Routes.settings, const SettingsPage()),
      // Pushed over the menu's pages, beside the menu (wider screens).
      GoRoute(
        // New entry without `extra` (on the [Account] passed as `extra`),
        // edit with the [Entry] as `extra`.
        name: Routes.entry.name,
        path: Routes.entry.path,
        builder: EntryPage.builder,
      ),
      GoRoute(
        // A new transfer without `extra` (from the [Account] passed), or the
        // one whose id is passed.
        name: Routes.transfer.name,
        path: Routes.transfer.path,
        builder: TransferPage.builder,
      ),
      GoRoute(
        // Edit the [Invoice] passed as `extra`, or a new one of the
        // [InvoiceDirection] passed (outgoing without `extra`).
        name: Routes.invoice.name,
        path: Routes.invoice.path,
        builder: InvoicePage.builder,
      ),
      GoRoute(
        name: Routes.rates.name,
        path: Routes.rates.path,
        builder: RatesPage.builder,
      ),
      GoRoute(
        // The current user without `extra`, another or a new one (without id)
        // with the [Profile] as `extra`.
        name: Routes.profile.name,
        path: Routes.profile.path,
        builder: (context, state) =>
            ProfilePage(profile: state.extra as Profile?),
      ),
    ],
  ),
];
