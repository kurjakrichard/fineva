import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'confirm_dialog.dart';
import 'responsive.dart';

/// The pages of the menu, in its order. They are shown in [MainShell] and
/// switched with `go`; other pages are pushed over them. [business] only
/// for a sole proprietor (see [visible]).
enum MainDestination {
  dashboard(Routes.dashboard, Icons.dashboard_outlined, Icons.dashboard),
  // An invoices only user's (Profile.invoicesOnly).
  invoices(Routes.invoices, Icons.request_quote_outlined, Icons.request_quote),
  revenueRecord(
    Routes.revenueRecord,
    Icons.menu_book_outlined,
    Icons.menu_book,
  ),
  flatRate(Routes.flatRate, Icons.percent_outlined, Icons.percent),
  // The others'.
  entries(Routes.entries, Icons.receipt_long_outlined, Icons.receipt_long),
  business(Routes.business, Icons.storefront_outlined, Icons.storefront),
  statistics(Routes.statistics, Icons.insights_outlined, Icons.insights),
  accounts(
    Routes.accounts,
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
  ),
  categories(Routes.categories, Icons.category_outlined, Icons.category),
  settings(Routes.settings, Icons.settings_outlined, Icons.settings);

  const MainDestination(this.route, this.icon, this.selectedIcon);

  final Routes route;
  final IconData icon;
  final IconData selectedIcon;

  /// The name in the menu; the invoices are the outgoing ones only for a
  /// [profile] without incoming invoices.
  String label(AppLocalizations l10n, Profile? profile) => switch (this) {
    dashboard => l10n.dashboard,
    invoices =>
      profile?.incomingInvoices ?? true ? l10n.invoices : l10n.outgoingInvoices,
    revenueRecord => l10n.revenueRecord,
    flatRate => l10n.taxRegimeFlatRate,
    entries => l10n.entries,
    business => l10n.business,
    statistics => l10n.statistics,
    accounts => l10n.accounts,
    categories => l10n.categories,
    settings => l10n.settings,
  };

  /// The destination of the page at [location]: its own page or one under
  /// it (an account under the accounts), the profile and the rates under
  /// the settings; null for the others (an entry, an invoice).
  static MainDestination? at(String location) {
    for (final destination in values) {
      final path = destination.route.path;
      if (location == path || location.startsWith('$path/')) {
        return destination;
      }
    }
    final settingsPages = {Routes.profile.path, Routes.rates.path};
    return settingsPages.contains(location) ? settings : null;
  }

  /// The destinations of [profile]'s menu: for an invoices only user
  /// (`Profile.invoicesOnly`) the invoices, the revenue record and the
  /// flat-rate tax instead of the entries, the accounts, the statistics and
  /// the categories; the business page only for the other sole
  /// proprietors.
  static List<MainDestination> visible(Profile? profile) {
    if (profile?.invoicesOnly ?? false) {
      return const [dashboard, invoices, revenueRecord, flatRate, settings];
    }
    return [
      for (final d in values)
        if (!_invoicesOnly.contains(d) &&
            (d != business || (profile?.isSoleProprietor ?? false)))
          d,
    ];
  }

  static const _invoicesOnly = {invoices, revenueRecord, flatRate};
}

/// The drawer of a page on a phone. Wider screens show the menu beside the
/// page instead (see [MainShell]). [current] is null on a page that isn't
/// under one of the menu's (an entry, an invoice).
Widget? mainDrawer(BuildContext context, MainDestination? current) =>
    ScreenSize.of(context).isCompact ? MainMenu(current: current) : null;

/// The app bar's leading on a page pushed over the menu's pages: the back
/// button (null: the drawer's button, if there is nothing to go back to).
/// The drawer ([mainDrawer]) still opens by swiping from the edge.
Widget? backButton(BuildContext context) =>
    (ModalRoute.of(context)?.canPop ?? false) ? const BackButton() : null;

/// Frame of the pages: on a phone the page alone (with its [mainDrawer]);
/// wider a navigation rail, on wide screens the menu always open beside it,
/// also beside the pages pushed over the menu's (an entry, an account).
/// Back on a menu page other than the dashboard goes to the dashboard.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = MainDestination.at(location);
    final page = PopScope(
      canPop: current == MainDestination.dashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.dashboard.path);
      },
      child: child,
    );
    final Widget menu;
    switch (ScreenSize.of(context)) {
      case ScreenSize.compact:
        return page;
      case ScreenSize.medium:
        menu = _MainRail(current: current);
      case ScreenSize.expanded:
        menu = MainMenu(current: current, permanent: true);
    }
    return Scaffold(
      body: Row(
        children: [
          menu,
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}

/// The menu as a navigation drawer: a drawer on phones ([mainDrawer]), always
/// open on wide screens ([permanent]).
class MainMenu extends ConsumerWidget {
  const MainMenu({super.key, required this.current, this.permanent = false});

  final MainDestination? current;
  final bool permanent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(financeProvider.select((s) => s.profile));
    final destinations = MainDestination.visible(profile);
    final selected = destinations.indexOf(current ?? MainDestination.dashboard);

    // A drawer closes before going on.
    void close() {
      if (!permanent) Scaffold.maybeOf(context)?.closeDrawer();
    }

    return NavigationDrawer(
      selectedIndex: current == null || selected < 0 ? null : selected,
      onDestinationSelected: (index) {
        close();
        context.go(destinations[index].route.path);
      },
      children: [
        _MenuHeader(profile: profile, onLeave: close),
        const SizedBox(height: 12),
        for (final destination in destinations)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label(l10n, profile)),
          ),
      ],
    );
  }
}

/// Logo, app name, and the current user, who can be switched
/// ([UserSwitchButton]).
class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.profile, required this.onLeave});

  final Profile? profile;

  /// Closes the drawer before switching.
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = this.profile;
    return Container(
      color: splashColor,
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(logoMarkAsset, height: 48),
              const SizedBox(width: 16),
              Text(
                l10n.appTitle,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (profile != null) ...[
            const SizedBox(height: 16),
            Material(
              type: MaterialType.transparency,
              child: UserSwitchButton(
                onLeave: onLeave,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      UserAvatar(profile: profile, radius: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.userName(profile),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Icon(Icons.unfold_more, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The menu as a navigation rail, with the current user on top. Scrolls if
/// the window is too low for it.
class _MainRail extends ConsumerWidget {
  const _MainRail({required this.current});

  final MainDestination? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(financeProvider.select((s) => s.profile));
    final destinations = MainDestination.visible(profile);
    final selected = destinations.indexOf(current ?? MainDestination.dashboard);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: current == null || selected < 0 ? null : selected,
              labelType: NavigationRailLabelType.all,
              leading: profile == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: UserSwitchButton(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: UserAvatar(profile: profile),
                        ),
                      ),
                    ),
              onDestinationSelected: (index) =>
                  context.go(destinations[index].route.path),
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label(l10n, profile)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [child] (the current user) opens a menu of the users: choosing another
/// one asks first, then switches to them and their dashboard; the last item
/// makes a new user ([ProfilePage] with a new [Profile]). There is no
/// managing the users: the user isn't an admin.
class UserSwitchButton extends ConsumerWidget {
  const UserSwitchButton({super.key, required this.child, this.onLeave});

  final Widget child;

  /// Closes the drawer before switching or making a new user.
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(financeProvider);
    final current = state.profile;
    return PopupMenuButton<Profile>(
      tooltip: l10n.switchUser,
      itemBuilder: (context) => [
        for (final profile in state.profiles)
          PopupMenuItem(
            value: profile,
            child: Row(
              children: [
                UserAvatar(profile: profile, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.userName(profile),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (profile.id == current?.id) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check),
                ],
              ],
            ),
          ),
        const PopupMenuDivider(),
        // A new one: no id.
        PopupMenuItem(
          value: const Profile(),
          child: Row(
            children: [
              const Icon(Icons.person_add),
              const SizedBox(width: 12),
              Text(l10n.newUser),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        final router = GoRouter.of(context);
        if (value.id == null) {
          onLeave?.call();
          router.pushNamed(Routes.profile.name, extra: value);
          return;
        }
        if (value.id == current?.id) return;
        final notifier = ref.read(financeProvider.notifier);
        final sure = await showConfirmDialog(
          context,
          l10n.switchUserConfirm(l10n.userName(value)),
          confirmText: l10n.switchUserAction,
        );
        if (!sure) return;
        onLeave?.call();
        await notifier.selectProfile(value);
        // Their data: the dashboard.
        router.go(Routes.dashboard.path);
      },
      child: child,
    );
  }
}

/// The first letter of the user's name in a circle.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.profile, this.radius = 20});

  final Profile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = profile.name.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: name.isEmpty
          ? Icon(Icons.person, size: radius)
          : Text(
              name.characters.first.toUpperCase(),
              style: TextStyle(fontSize: radius * 0.9),
            ),
    );
  }
}
