import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';
import 'entries_page.dart';
import 'invoices_only_pages.dart';

/// The start page: for the period chosen in the app bar (this month at
/// first; the statistics show the same) the balances at its end, its income
/// and expenses and its latest entries; for a sole proprietor the open
/// invoices. Side by side on wider screens. (The user's name is in the
/// menu's header.) An invoices only user's (`Profile.invoicesOnly`) has no
/// balances: see [_InvoicesOnlyDashboard].
class DashboardPage extends ConsumerWidget {
  static DashboardPage builder(BuildContext context, GoRouterState state) =>
      const DashboardPage();

  const DashboardPage({super.key});

  /// How many of the newest entries are shown.
  static const int latestCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(financeProvider);
    if (state.profile?.invoicesOnly ?? false) {
      return const _InvoicesOnlyDashboard();
    }
    final period = ref.watch(periodProvider);
    final onBar =
        Theme.of(context).appBarTheme.foregroundColor ??
        Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          PeriodBar(
            period: period,
            color: onBar,
            dense: true,
            onChanged: ref.read(periodProvider.notifier).set,
          ),
        ],
      ),
      drawer: mainDrawer(context, MainDestination.dashboard),
      floatingActionButton: state.accounts.isEmpty
          ? null
          : const AddEntryButton(),
      body: FinanceContent(
        state: state,
        builder: (context) => MaxWidth(
          child: ListView(
            // Room for the + button at the bottom.
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            children: [
              ResponsiveRow(
                children: [
                  // At the end of the period; now for all time.
                  BalanceCard(state: state, date: period.last),
                  _PeriodCard(state: state, period: period),
                ],
              ),
              if (state.profile?.isSoleProprietor ?? false) ...[
                const SizedBox(height: 12),
                _OpenInvoices(state: state, route: Routes.business),
              ],
              const SizedBox(height: 12),
              _LatestEntries(state: state, period: period),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card with [title] and an optional [action] button in its header.
class _Section extends StatelessWidget {
  const _Section({required this.title, this.action, required this.child});

  final String title;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Income and expenses of [period] in the main currency.
class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.state, required this.period});

  final FinanceState state;
  final DatePeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final totals = state.periodTotals(period);
    final change = state.periodChange(period);
    // The period before, to compare with (not for all time).
    final before = period.isAll ? null : state.periodTotals(period.previous);
    final main = state.mainCurrency;
    Widget amount(
      String label,
      Color color,
      int value,
      int? then, {
      bool higherIsBetter = true,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodySmall),
        AmountText(
          value,
          main,
          style: textTheme.titleMedium?.copyWith(color: color),
        ),
        if (then != null)
          PeriodComparison(
            current: value,
            previous: then,
            currency: main,
            higherIsBetter: higherIsBetter,
          ),
      ],
    );
    return _Section(
      title: periodName(context, period),
      action: TextButton(
        onPressed: () => context.go(Routes.statistics.path),
        child: Text(l10n.statistics),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: amount(
                    l10n.income,
                    incomeColor,
                    totals.income,
                    before?.income,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: amount(
                    l10n.expense,
                    expenseColor,
                    totals.expense,
                    before?.expense,
                    higherIsBetter: false,
                  ),
                ),
              ],
            ),
            // With another currency than the main one, or an opening entry:
            // what else changed the balance.
            for (final (label, value) in [
              (l10n.openingEntries, change.openings),
              (l10n.revaluation, change.revaluation),
            ])
              if (value != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(label, style: textTheme.bodySmall)),
                      AmountText(value, main, signed: true),
                    ],
                  ),
                ),
            MissingRatesNote(currencies: totals.missing),
          ],
        ),
      ),
    );
  }
}

/// The newest entries and a button to all of them.
class _LatestEntries extends StatelessWidget {
  const _LatestEntries({required this.state, required this.period});

  final FinanceState state;
  final DatePeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inPeriod = [
      for (final entry in state.entries)
        if (period.contains(entry.date)) entry,
    ];
    final entries = inPeriod.take(DashboardPage.latestCount);
    return _Section(
      title: l10n.latestEntries,
      action: inPeriod.isEmpty
          ? null
          : TextButton(
              // The entries page, filtered to the period.
              onPressed: () => context.go(EntriesPage.location(period)),
              child: Text(l10n.allEntriesCount(inPeriod.length)),
            ),
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                state.entries.isEmpty ? l10n.noEntries : l10n.noEntriesInPeriod,
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              children: [
                for (final entry in entries)
                  if (state.account(entry.accountId) case final account?)
                    EntryTile(
                      entry: entry,
                      account: account,
                      category: state.category(entry.categoryId),
                      transferPeer: state.transferPeer(entry),
                      onTap: () => openEntry(context, state, entry),
                      onEdit: () =>
                          openEntry(context, state, entry, edit: true),
                    ),
              ],
            ),
    );
  }
}

/// A sole proprietor's invoices not paid (fully) yet: what the customers
/// owe and (if they have incoming invoices) what is owed to the suppliers,
/// by currency. Its button goes to the invoices on [route].
class _OpenInvoices extends StatelessWidget {
  const _OpenInvoices({required this.state, required this.route});

  final FinanceState state;
  final Routes route;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final open = {
      for (final direction in InvoiceDirection.values)
        direction: <Currency, int>{},
    };
    final counts = {
      for (final direction in InvoiceDirection.values) direction: 0,
    };
    for (final invoice in state.invoices) {
      if (invoice.openAmount == 0) continue;
      open[invoice.direction]!.update(
        invoice.currency,
        (sum) => sum + invoice.openAmount,
        ifAbsent: () => invoice.openAmount,
      );
      counts[invoice.direction] = counts[invoice.direction]! + 1;
    }
    Widget column(InvoiceDirection direction, String label, Color color) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label (${counts[direction]})', style: textTheme.bodySmall),
            if (open[direction]!.isEmpty)
              AmountText(
                0,
                Currency.huf,
                style: textTheme.titleMedium?.copyWith(color: color),
              ),
            for (final MapEntry(key: currency, value: amount)
                in open[direction]!.entries)
              AmountText(
                amount,
                currency,
                style: textTheme.titleMedium?.copyWith(color: color),
              ),
          ],
        );
    return _Section(
      title: l10n.openInvoices,
      action: TextButton(
        onPressed: () => context.go(route.path),
        child: Text(l10n.invoices),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: column(
                InvoiceDirection.outgoing,
                l10n.receivables,
                incomeColor,
              ),
            ),
            if (state.profile?.incomingInvoices ?? true)
              Expanded(
                child: column(
                  InvoiceDirection.incoming,
                  l10n.payables,
                  expenseColor,
                ),
              )
            else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// An invoices only user's (`Profile.invoicesOnly`) start page, without
/// balances: this year's revenue with its limit, the next tax payment, the
/// open invoices and this year's latest invoices.
class _InvoicesOnlyDashboard extends ConsumerWidget {
  const _InvoicesOnlyDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(financeProvider);
    final year = currentDay().year;
    // The pages of the menu show the year chosen there: this one from here.
    void open(Routes route) {
      ref.read(businessYearProvider.notifier).set(year);
      context.go(route.path);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      drawer: mainDrawer(context, MainDestination.dashboard),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(
          Routes.invoice.name,
          extra: InvoiceDirection.outgoing,
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.addInvoice),
      ),
      body: FinanceContent(
        state: state,
        builder: (context) {
          final profile = state.profile!;
          return MaxWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              children: [
                ResponsiveRow(
                  children: [
                    _RevenueCard(
                      record: RevenueRecord(state.invoices, year),
                      onOpen: () => open(Routes.revenueRecord),
                    ),
                    _NextTaxCard(
                      invoices: state.invoices,
                      profile: profile,
                      // That quarter of its year.
                      onOpen: (year, quarter) {
                        ref.read(businessYearProvider.notifier).set(year);
                        context.go(FlatRateTaxPage.location(quarter));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _OpenInvoices(state: state, route: Routes.invoices),
                const SizedBox(height: 12),
                _LatestInvoices(
                  state: state,
                  year: year,
                  onOpen: () => open(Routes.invoices),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The revenue of the year so far and the revenue limit.
class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.record, required this.onOpen});

  final RevenueRecord record;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Section(
      title: l10n.revenueOfYear(record.year),
      action: TextButton(onPressed: onOpen, child: Text(l10n.revenueRecord)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AmountText(
              record.total,
              Currency.huf,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            LimitBar(
              label: l10n.flatRateRevenue,
              used: record.total,
              limit: TaxYear.of(record.year).flatRateRevenueLimit,
            ),
          ],
        ),
      ),
    );
  }
}

/// The flat-rate taxes of the quarter to pay next: the last quarter of last
/// year until its deadline in January, then this quarter's (so far).
class _NextTaxCard extends StatelessWidget {
  const _NextTaxCard({
    required this.invoices,
    required this.profile,
    required this.onOpen,
  });

  final List<Invoice> invoices;
  final Profile profile;

  /// Opens the quarter of the year.
  final void Function(int year, int quarter) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final today = currentDay();
    var year = today.year - 1;
    var quarter = FlatRateTax(invoices, profile, year).quarters.last;
    if (today.isAfter(quarter.deadline)) {
      year = today.year;
      quarter = FlatRateTax(
        invoices,
        profile,
        year,
      ).quarters[(today.month - 1) ~/ 3];
    }
    return _Section(
      title: l10n.nextTaxPayment,
      action: TextButton(
        onPressed: () => onOpen(year, quarter.quarter),
        child: Text(l10n.taxRegimeFlatRate),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.quarterOfYear(quarter.quarter, year),
              style: textTheme.bodySmall,
            ),
            AmountText(
              quarter.total,
              Currency.huf,
              style: textTheme.headlineSmall,
            ),
            Text(
              l10n.deadline(
                DateFormat.yMMMd(context.localeName).format(quarter.deadline),
              ),
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The newest invoices of [year] and a button to all of them.
class _LatestInvoices extends StatelessWidget {
  const _LatestInvoices({
    required this.state,
    required this.year,
    required this.onOpen,
  });

  final FinanceState state;
  final int year;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ofYear = [
      for (final invoice in state.invoices)
        if (invoice.fulfillmentDate.year == year) invoice,
    ];
    return _Section(
      title: l10n.latestInvoices,
      action: ofYear.isEmpty
          ? null
          : TextButton(
              onPressed: onOpen,
              child: Text(l10n.allEntriesCount(ofYear.length)),
            ),
      child: ofYear.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.noInvoices, textAlign: TextAlign.center),
            )
          : Column(
              children: [
                for (final invoice in ofYear.take(DashboardPage.latestCount))
                  InvoiceTile(invoice: invoice),
              ],
            ),
    );
  }
}
