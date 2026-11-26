import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';
import 'account_page.dart';

/// Every account with its balance; tap one for its entries and daily
/// balances ([AccountPage]), long press it to edit it.
class AccountsPage extends ConsumerWidget {
  static AccountsPage builder(BuildContext context, GoRouterState state) =>
      const AccountsPage();

  const AccountsPage({super.key});

  static IconData icon(AccountType type) => switch (type) {
    AccountType.cash => Icons.payments,
    AccountType.bank => Icons.account_balance,
    AccountType.card => Icons.credit_card,
    AccountType.savings => Icons.savings,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(financeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accounts)),
      drawer: mainDrawer(context, MainDestination.accounts),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addAccount,
        onPressed: () => showAccountDialog(context),
        child: const Icon(Icons.add),
      ),
      body: state.accounts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noAccounts, textAlign: TextAlign.center),
              ),
            )
          : MaxWidth(
              child: ListView(
                children: [
                  for (final account in state.accounts)
                    if (!account.isClosed) _tile(context, state, account),
                  // Closed ones apart, below.
                  if (state.accounts.any((a) => a.isClosed)) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        l10n.closedAccounts,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final account in state.accounts)
                      if (account.isClosed) _tile(context, state, account),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _tile(BuildContext context, FinanceState state, Account account) {
    final l10n = context.l10n;
    final closed = account.closedDate;
    final tile = ListTile(
      leading: Icon(icon(account.type)),
      title: Text(account.name),
      subtitle: Text(
        [
          l10n.accountTypeName(account.type),
          account.currency.code,
          if (closed != null)
            l10n.closedOn(DateFormat.yMMMd(context.localeName).format(closed)),
        ].join(' · '),
      ),
      trailing: AmountText(
        state.balanceOf(account),
        account.currency,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      onTap: () => context.go(AccountPage.location(account)),
      onLongPress: () => showAccountDialog(context, account: account),
    );
    // A closed one paler.
    return closed == null ? tile : Opacity(opacity: 0.6, child: tile);
  }
}
