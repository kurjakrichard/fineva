import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// The current user's entries, the newest first. The app bar has the search
/// (its icon opens the field in place of the title) and the filters by
/// type, account, category and period (a bottom sheet); the filters set are
/// chips above the list. The route's `from` and `to` parameters (first and
/// last day, 2026-11-01) set the period filter, e.g. from the dashboard.
class EntriesPage extends ConsumerStatefulWidget {
  static EntriesPage builder(BuildContext context, GoRouterState state) =>
      EntriesPage(period: parsePeriod(state.uri.queryParameters));

  const EntriesPage({super.key, this.period});

  /// The period shown at first; all time if null.
  final DatePeriod? period;

  /// The `from` and `to` route parameters, both needed: "2026-11-01" and
  /// "2026-11-30" -> November 2026.
  static DatePeriod? parsePeriod(Map<String, String> parameters) {
    DateTime? day(String? text) =>
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text ?? '')
        ? DateTime.tryParse(text!)
        : null;
    final from = day(parameters['from']);
    final to = day(parameters['to']);
    return from == null || to == null ? null : DatePeriod.range(from, to);
  }

  /// The route of [period]'s entries.
  static String location(DatePeriod period) {
    final start = period.start;
    final last = period.last;
    if (start == null || last == null) return Routes.entries.path;
    return '${Routes.entries.path}?from=${Entry.dateText(start)}'
        '&to=${Entry.dateText(last)}';
  }

  @override
  ConsumerState<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends ConsumerState<EntriesPage> {
  late EntryFilter _filter;
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _filter = EntryFilter(period: widget.period);
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(financeProvider);
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? EntrySearchField(
                controller: _search,
                onChanged: (text) => _setFilter(_filter.withText(text)),
              )
            : Text(l10n.entries),
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
          EntrySortButton(
            sort: _filter.sort,
            onChanged: (sort) => _setFilter(_filter.withSort(sort)),
          ),
          IconButton(
            tooltip: l10n.filters,
            onPressed: state.loaded
                ? () =>
                      showEntryFilterSheet(context, state, _filter, _setFilter)
                : null,
            icon: Badge(
              isLabelVisible: _filter.count > 0,
              label: Text('${_filter.count}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      drawer: mainDrawer(context, MainDestination.entries),
      floatingActionButton: state.accounts.isEmpty
          ? null
          : const AddEntryButton(),
      body: FinanceContent(
        state: state,
        builder: (context) {
          final entries = _filter.apply(
            state,
            l10n.categoryName,
            openingName: l10n.openingEntry,
            transferName: l10n.transfer,
          );
          return MaxWidth(
            child: CustomScrollView(
              slivers: [
                if (_filter.isActive)
                  SliverToBoxAdapter(
                    child: ActiveEntryFilters(
                      state: state,
                      filter: _filter,
                      entries: entries,
                      onChanged: _setFilter,
                    ),
                  ),
                if (entries.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        state.entries.isEmpty
                            ? l10n.noEntries
                            : l10n.noMatchingEntries,
                        textAlign: TextAlign.center,
                      ),
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
                        final account = state.account(entry.accountId);
                        if (account == null) return const SizedBox.shrink();
                        return EntryTile(
                          entry: entry,
                          account: account,
                          category: state.category(entry.categoryId),
                          transferPeer: state.transferPeer(entry),
                          onTap: () => openEntry(context, state, entry),
                          onEdit: () =>
                              openEntry(context, state, entry, edit: true),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
