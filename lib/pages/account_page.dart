import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';
import 'accounts_page.dart';

/// An account's entries like a bank statement, for recording and checking
/// them: by day, the newest first, each day with the balance at its end;
/// the opening entry is one of them (without one, a button below gives
/// it). Tap an entry to look at it, its edit button to edit it; the +
/// button adds one on this account; the balance card edits the account.
class AccountPage extends ConsumerStatefulWidget {
  static AccountPage builder(BuildContext context, GoRouterState state) =>
      AccountPage(accountId: int.tryParse(state.pathParameters['id'] ?? ''));

  const AccountPage({super.key, required this.accountId});

  /// Null for a route that isn't an account's.
  final int? accountId;

  /// The route of [account]'s page.
  static String location(Account account) =>
      '${Routes.accounts.path}/${account.id}';

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  /// The search and the filters (the account is this one).
  EntryFilter _filter = const EntryFilter();
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setFilter(EntryFilter filter) => setState(() => _filter = filter);

  void _closeSearch() => setState(() {
    _searching = false;
    _search.clear();
    _filter = _filter.withText('');
  });

  Future<void> _editAccount(Account account) async {
    await showAccountDialog(context, account: account);
    // Deleted: back to the accounts.
    if (mounted && ref.read(financeProvider).account(account.id!) == null) {
      context.go(Routes.accounts.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accountId = widget.accountId;
    final state = ref.watch(financeProvider);
    final account = accountId == null ? null : state.account(accountId);
    if (account == null) {
      // Deleted, or another user's.
      return Scaffold(
        drawer: mainDrawer(context, MainDestination.accounts),
        appBar: AppBar(
          leading: backButton(context),
          title: Text(l10n.accounts),
        ),
        body: state.loaded
            ? Center(child: Text(l10n.accountNotFound))
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final days = state.ledger(account);
    // Filtered: the entries found, without the balances (they wouldn't add
    // up).
    final found = _filter.isActive
        ? _filter
              .withAccount(account.id)
              .apply(
                state,
                l10n.categoryName,
                openingName: l10n.openingEntry,
                transferName: l10n.transfer,
              )
        : null;
    return Scaffold(
      drawer: mainDrawer(context, MainDestination.accounts),
      appBar: AppBar(
        leading: backButton(context),
        title: _searching
            ? EntrySearchField(
                controller: _search,
                onChanged: (text) => _setFilter(_filter.withText(text)),
              )
            : Text(account.name),
        actions: [
          if (_searching)
            IconButton(
              tooltip: l10n.clearSearch,
              onPressed: _closeSearch,
              icon: const Icon(Icons.close),
            )
          else
            IconButton(
              tooltip: l10n.search,
              onPressed: () => setState(() => _searching = true),
              icon: const Icon(Icons.search),
            ),
          // The statement's order is the days'; a filtered list can be
          // sorted.
          if (found != null)
            EntrySortButton(
              sort: _filter.sort,
              onChanged: (sort) => _setFilter(_filter.withSort(sort)),
            ),
          IconButton(
            tooltip: l10n.filters,
            onPressed: () => showEntryFilterSheet(
              context,
              state,
              _filter,
              _setFilter,
              withAccount: false,
            ),
            icon: Badge(
              isLabelVisible: _filter.count > 0,
              label: Text('${_filter.count}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      // Closed: nothing new on it.
      floatingActionButton: account.isClosed
          ? null
          : AddEntryButton(account: account),
      body: MaxWidth(
        child: found != null
            ? _Found(
                state: state,
                account: account,
                filter: _filter,
                entries: found,
                onChanged: _setFilter,
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      state: state,
                      account: account,
                      onEdit: () => _editAccount(account),
                    ),
                  ),
                  if (days.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.noAccountEntries,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  for (final day in days) ...[
                    SliverToBoxAdapter(
                      child: _DayHeader(
                        day: day.day,
                        balance: day.balance,
                        account: account,
                      ),
                    ),
                    SliverList.builder(
                      itemCount: day.entries.length,
                      itemBuilder: (context, index) {
                        final entry = day.entries[index];
                        return EntryTile(
                          entry: entry,
                          account: account,
                          category: state.category(entry.categoryId),
                          transferPeer: state.transferPeer(entry),
                          showDate: false,
                          showAccount: false,
                          onTap: () => openEntry(context, state, entry),
                          onEdit: () =>
                              openEntry(context, state, entry, edit: true),
                        );
                      },
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      // Room for the + button.
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      child:
                          state.openingsOf(account).isEmpty && !account.isClosed
                          ? Center(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    openNewOpening(context, account),
                                icon: const Icon(Icons.flag),
                                label: Text(l10n.newOpeningEntry),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The entries of the account the search and the filters found, the
/// newest first, with their dates; the filters set and their totals above,
/// no balances.
class _Found extends StatelessWidget {
  const _Found({
    required this.state,
    required this.account,
    required this.filter,
    required this.entries,
    required this.onChanged,
  });

  final FinanceState state;
  final Account account;
  final EntryFilter filter;
  final List<Entry> entries;
  final ValueChanged<EntryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ActiveEntryFilters(
            state: state,
            filter: filter,
            entries: entries,
            onChanged: onChanged,
          ),
        ),
        if (entries.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.noMatchingEntries, textAlign: TextAlign.center),
            ),
          )
        else
          SliverPadding(
            // Room for the + button.
            padding: const EdgeInsets.only(bottom: 80),
            sliver: SliverList.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return EntryTile(
                  entry: entry,
                  account: account,
                  category: state.category(entry.categoryId),
                  transferPeer: state.transferPeer(entry),
                  showAccount: false,
                  onTap: () => openEntry(context, state, entry),
                  onEdit: () => openEntry(context, state, entry, edit: true),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// The account's kind, currency and balance now (≈ in the main currency if
/// it's another), and its edit button.
class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.account,
    required this.onEdit,
  });

  final FinanceState state;
  final Account account;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final balance = state.balanceOf(account);
    final main = state.mainCurrency;
    final inMain = account.currency == main
        ? null
        : state.toMain(balance, account.currency, currentDay());
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Icon(AccountsPage.icon(account.type)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.balance, style: textTheme.titleMedium),
                    Text(
                      '${l10n.accountTypeName(account.type)}'
                      ' · ${l10n.currencyLabel(account.currency)}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // The details given, and the closing.
                    for (final detail in [
                      account.bankAccount,
                      account.swift,
                      account.description,
                      if (account.closedDate case final closed?)
                        l10n.closedOn(
                          DateFormat.yMMMd(context.localeName).format(closed),
                        ),
                    ])
                      if (detail.isNotEmpty)
                        Text(detail, style: textTheme.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(
                    balance,
                    account.currency,
                    style: textTheme.titleLarge,
                  ),
                  if (inMain != null)
                    Text(
                      '≈ ${main.format(inMain, context.localeName)}',
                      style: textTheme.bodySmall,
                    ),
                ],
              ),
              // Seldom needed: not in the app bar.
              IconButton(
                tooltip: l10n.editAccount,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A day: its date, and the account's balance at its end.
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.balance,
    required this.account,
  });

  final DateTime day;
  final int balance;
  final Account account;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat.yMMMMEEEEd(context.localeName).format(day),
              style: textTheme.titleSmall,
            ),
          ),
          Text(
            '${l10n.dayBalance} ',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          AmountText(balance, account.currency, style: textTheme.titleSmall),
        ],
      ),
    );
  }
}
