import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Statistics of a period (week, month, quarter, year, any days or all
/// time; the same as the dashboard's), in the user's main currency (the
/// others converted): summary, categories, balance, cash flow. The period is
/// chosen in the app bar.
class StatisticsPage extends ConsumerStatefulWidget {
  static StatisticsPage builder(BuildContext context, GoRouterState state) =>
      const StatisticsPage();

  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  EntryType _categoryType = EntryType.expense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final onBar =
        Theme.of(context).appBarTheme.foregroundColor ?? scheme.onSurface;
    final state = ref.watch(financeProvider);
    final period = ref.watch(periodProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          // Smaller on a narrow phone with a long period name.
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(l10n.statistics),
          ),
          actions: [
            if (state.accounts.isNotEmpty)
              PeriodBar(
                period: period,
                color: onBar,
                dense: true,
                onChanged: ref.read(periodProvider.notifier).set,
              ),
          ],
          // On the app bar's primary color.
          bottom: TabBar(
            isScrollable: ScreenSize.of(context).isCompact,
            tabAlignment: ScreenSize.of(context).isCompact
                ? TabAlignment.start
                : TabAlignment.center,
            labelColor: scheme.onPrimary,
            unselectedLabelColor: scheme.onPrimary.withValues(alpha: 0.7),
            indicatorColor: scheme.onPrimary,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: l10n.summary),
              Tab(text: l10n.categories),
              Tab(text: l10n.balance),
              Tab(text: l10n.cashFlow),
            ],
          ),
        ),
        drawer: mainDrawer(context, MainDestination.statistics),
        body: FinanceContent(
          state: state,
          builder: (context) {
            final stats = Statistics(state, period);
            return Column(
              children: [
                if (stats.missing.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
                    child: MaxWidth(
                      child: MissingRatesNote(currencies: stats.missing),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _SummaryTab(stats: stats),
                      _CategoriesTab(
                        stats: stats,
                        type: _categoryType,
                        onTypeChanged: (type) =>
                            setState(() => _categoryType = type),
                      ),
                      _BalanceTab(stats: stats),
                      _CashFlowTab(stats: stats),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A scrolling tab, at most [maxWidth] wide.
class _Tab extends StatelessWidget {
  const _Tab({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MaxWidth(
    child: ListView(padding: const EdgeInsets.all(12), children: children),
  );
}

/// A card with a title.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _NoEntries extends StatelessWidget {
  const _NoEntries();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(context.l10n.noEntriesInPeriod, textAlign: TextAlign.center),
  );
}

/// Income, expenses, net result and savings rate.
class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.stats});

  final Statistics stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final currency = stats.currency;
    final net = currency.format(stats.net, locale);
    final rate = stats.savingsRate;
    // With the period before (not for all time).
    final previous = stats.previous;
    Widget? compare(int current, int? then, {bool higherIsBetter = true}) =>
        then == null
        ? null
        : PeriodComparison(
            current: current,
            previous: then,
            currency: currency,
            higherIsBetter: higherIsBetter,
          );
    return _Tab(
      children: [
        ResponsiveRow(
          children: [
            StatTile(
              label: l10n.income,
              value: currency.format(stats.income, locale),
              icon: Icons.arrow_downward,
              iconColor: incomeColor,
              footer: compare(stats.income, previous?.income),
            ),
            StatTile(
              label: l10n.expense,
              value: currency.format(stats.expense, locale),
              icon: Icons.arrow_upward,
              iconColor: expenseColor,
              footer: compare(
                stats.expense,
                previous?.expense,
                higherIsBetter: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ResponsiveRow(
          children: [
            StatTile(
              label: l10n.netResult,
              value: stats.net > 0 ? '+$net' : net,
              icon: Icons.account_balance_wallet_outlined,
              footer: compare(stats.net, previous?.net),
            ),
            StatTile(
              label: l10n.savingsRate,
              value: rate == null
                  ? '–'
                  : NumberFormat.percentPattern(locale).format(rate),
              icon: Icons.savings_outlined,
            ),
          ],
        ),
        if (stats.isEmpty) const _NoEntries(),
      ],
    );
  }
}

/// How the expenses (or income) split between the categories.
class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({
    required this.stats,
    required this.type,
    required this.onTypeChanged,
  });

  final Statistics stats;
  final EntryType type;
  final ValueChanged<EntryType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totals = stats.categoryTotals(type);
    final sum = type == EntryType.income ? stats.income : stats.expense;
    return _Tab(
      children: [
        Center(
          child: SegmentedButton<EntryType>(
            segments: [
              ButtonSegment(
                value: EntryType.expense,
                label: Text(l10n.expense),
              ),
              ButtonSegment(value: EntryType.income, label: Text(l10n.income)),
            ],
            selected: {type},
            onSelectionChanged: (value) => onTypeChanged(value.first),
          ),
        ),
        const SizedBox(height: 12),
        if (totals.isEmpty)
          const _NoEntries()
        else
          _ChartCard(
            title: l10n.categoryTotal(
              stats.currency.format(sum, context.localeName),
            ),
            child: CategoryBreakdown(totals: totals, currency: stats.currency),
          ),
      ],
    );
  }
}

/// The balance at the end of the period and its line through the period.
class _BalanceTab extends StatelessWidget {
  const _BalanceTab({required this.stats});

  final Statistics stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final points = stats.balanceSeries();
    if (points.isEmpty) return const _Tab(children: [_NoEntries()]);
    final change = stats.change;
    return _Tab(
      children: [
        _ChartCard(
          title: l10n.closingBalance,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // At the end of the period, as the dashboard's (the line
              // stops today).
              AmountText(
                change.closing,
                stats.currency,
                style: textTheme.headlineMedium,
              ),
              // The change, and what made it.
              for (final (label, amount, always) in [
                (l10n.changeInPeriod, change.closing - change.opening, true),
                (l10n.netResult, change.result, false),
                (l10n.openingEntries, change.openings, false),
                (l10n.revaluation, change.revaluation, false),
              ])
                if (always || amount != 0)
                  Padding(
                    padding: EdgeInsets.only(left: always ? 0 : 12),
                    child: Row(
                      children: [
                        Text('$label ', style: textTheme.bodySmall),
                        AmountText(
                          amount,
                          stats.currency,
                          signed: true,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 24),
              SizedBox(
                height: 240,
                child: BalanceLineChart(
                  points: points,
                  currency: stats.currency,
                  monthly: stats.monthlyBalance,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Income and expenses by day, week, month or year: bars, then the same as
/// a table.
class _CashFlowTab extends StatelessWidget {
  const _CashFlowTab({required this.stats});

  final Statistics stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final buckets = stats.cashFlow();
    final period = stats.period;
    final oneYear =
        period.start != null && period.start!.year == period.last!.year;
    String label(CashFlowBucket bucket) => switch (stats.cashFlowStep) {
      CashFlowStep.day => DateFormat.MMMd(locale).format(bucket.start),
      // A month's weeks: 1–7., 8–14., ...
      CashFlowStep.week =>
        period.kind == PeriodKind.month
            ? '${bucket.start.day}–${bucket.last.day}.'
            : DateFormat.MMMd(locale).format(bucket.start),
      CashFlowStep.month =>
        (oneYear ? DateFormat.MMM(locale) : DateFormat.yMMM(locale)).format(
          bucket.start,
        ),
      CashFlowStep.year => '${bucket.start.year}',
    };
    final bold = textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    Widget cell(String text, {TextStyle? style, bool start = false}) =>
        Expanded(
          flex: start ? 2 : 3,
          child: Text(
            text,
            textAlign: start ? TextAlign.start : TextAlign.end,
            style: style,
          ),
        );

    return _Tab(
      children: [
        _ChartCard(
          title: l10n.cashFlow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChartLegend(
                items: [
                  (incomeColor, l10n.income),
                  (expenseColor, l10n.expense),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: CashFlowBarChart(
                  buckets: buckets,
                  currency: stats.currency,
                  label: label,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    cell('', start: true),
                    cell(l10n.income, style: textTheme.labelMedium),
                    cell(l10n.expense, style: textTheme.labelMedium),
                    cell(l10n.netResult, style: textTheme.labelMedium),
                  ],
                ),
                const Divider(),
                for (final bucket in buckets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        cell(label(bucket), start: true),
                        cell(stats.currency.format(bucket.income, locale)),
                        cell(stats.currency.format(bucket.expense, locale)),
                        cell(
                          stats.currency.format(
                            bucket.income - bucket.expense,
                            locale,
                          ),
                          style: bold,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
