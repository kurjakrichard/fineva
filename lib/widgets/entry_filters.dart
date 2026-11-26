import 'package:flutter/material.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'amount_text.dart';
import 'category_avatar.dart';
import 'max_width.dart';
import 'period_picker.dart';

/// The search field of an app bar with an entry list (the entries, an
/// account's page), in the app bar's colors.
class EntrySearchField extends StatelessWidget {
  const EntrySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final onBar =
        Theme.of(context).appBarTheme.foregroundColor ??
        Theme.of(context).colorScheme.onSurface;
    return TextField(
      controller: controller,
      autofocus: true,
      cursorColor: onBar,
      style: TextStyle(color: onBar),
      decoration: InputDecoration(
        hintText: context.l10n.searchEntries,
        hintStyle: TextStyle(color: onBar.withValues(alpha: 0.7)),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
    );
  }
}

/// The order of an entry list ([EntryFilter.sort]): a menu, the chosen one
/// checked.
class EntrySortButton extends StatelessWidget {
  const EntrySortButton({
    super.key,
    required this.sort,
    required this.onChanged,
  });

  final EntrySort sort;
  final ValueChanged<EntrySort> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<EntrySort>(
      tooltip: l10n.sort,
      icon: Badge(
        // Not the usual order.
        isLabelVisible: sort != EntrySort.newest,
        smallSize: 8,
        child: const Icon(Icons.sort),
      ),
      initialValue: sort,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final value in EntrySort.values)
          CheckedPopupMenuItem(
            value: value,
            checked: value == sort,
            child: Text(switch (value) {
              EntrySort.newest => l10n.sortNewest,
              EntrySort.oldest => l10n.sortOldest,
              EntrySort.largest => l10n.sortLargest,
              EntrySort.smallest => l10n.sortSmallest,
            }),
          ),
      ],
    );
  }
}

/// The filter sheet of [filter] over an entry list (see [EntryFilterSheet]).
Future<void> showEntryFilterSheet(
  BuildContext context,
  FinanceState state,
  EntryFilter filter,
  ValueChanged<EntryFilter> onChanged, {
  bool withAccount = true,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => EntryFilterSheet(
    state: state,
    filter: filter,
    onChanged: onChanged,
    withAccount: withAccount,
  ),
);

/// The filters set (each can be taken off), and how many entries they
/// show with their income and expenses by currency.
class ActiveEntryFilters extends StatelessWidget {
  const ActiveEntryFilters({
    super.key,
    required this.state,
    required this.filter,
    required this.entries,
    required this.onChanged,
  });

  final FinanceState state;
  final EntryFilter filter;
  final List<Entry> entries;
  final ValueChanged<EntryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final type = filter.type;
    final account = filter.accountId == null
        ? null
        : state.account(filter.accountId!);
    final category = state.category(filter.categoryId);
    final period = filter.period;
    Widget chip(String label, VoidCallback onDeleted, {Widget? avatar}) =>
        InputChip(
          label: Text(label),
          avatar: avatar,
          onDeleted: onDeleted,
          deleteButtonTooltipMessage: l10n.removeFilter,
        );

    final sums = <Currency, ({int income, int expense})>{};
    for (final entry in entries) {
      final currency = state.account(entry.accountId)?.currency;
      if (currency == null) continue;
      final (:income, :expense) = sums[currency] ?? (income: 0, expense: 0);
      sums[currency] = entry.type == EntryType.income
          ? (income: income + entry.amount, expense: expense)
          : (income: income, expense: expense + entry.amount);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (type != null)
                chip(
                  l10n.entryTypeName(type),
                  () => onChanged(filter.withType(null)),
                ),
              if (account != null)
                chip(account.name, () => onChanged(filter.withAccount(null))),
              if (category != null)
                chip(
                  l10n.categoryName(category),
                  () => onChanged(filter.withCategory(null)),
                  avatar: CategoryAvatar(category: category, radius: 12),
                ),
              if (filter.withoutCategory)
                chip(
                  l10n.noCategory,
                  () => onChanged(filter.withCategory(null)),
                ),
              if (period != null)
                chip(
                  periodName(context, period),
                  () => onChanged(filter.withPeriod(null)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.entryCount(entries.length),
                style: textTheme.bodyMedium,
              ),
              for (final MapEntry(key: currency, value: sum)
                  in sums.entries) ...[
                if (sum.income > 0)
                  AmountText(sum.income, currency, signed: true),
                if (sum.expense > 0)
                  AmountText(-sum.expense, currency, signed: true),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The filters in a bottom sheet; every change applies at once.
class EntryFilterSheet extends StatefulWidget {
  const EntryFilterSheet({
    super.key,
    this.withAccount = true,
    required this.state,
    required this.filter,
    required this.onChanged,
  });

  final FinanceState state;
  final EntryFilter filter;
  final ValueChanged<EntryFilter> onChanged;

  /// The account filter too (not on an account's page).
  final bool withAccount;

  @override
  State<EntryFilterSheet> createState() => _EntryFilterSheetState();
}

class _EntryFilterSheetState extends State<EntryFilterSheet> {
  /// The menu item of the entries without category (no real id).
  static const int _noCategory = -1;

  late EntryFilter _filter = widget.filter;

  void _set(EntryFilter filter) {
    setState(() => _filter = filter);
    widget.onChanged(filter);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    final period = _filter.period;
    final categories = [
      for (final c in state.visibleCategories)
        if (_filter.type == null || c.type == _filter.type) c,
    ];
    final categoryId = _filter.withoutCategory
        ? _noCategory
        : categories.any((c) => c.id == _filter.categoryId)
        ? _filter.categoryId
        : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: MaxWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(l10n.filters, style: Theme.of(context).textTheme.titleLarge),
              SegmentedButton<EntryType>(
                emptySelectionAllowed: true,
                segments: [
                  for (final type in EntryType.values)
                    ButtonSegment(
                      value: type,
                      label: Text(l10n.entryTypeName(type)),
                    ),
                ],
                selected: {?_filter.type},
                onSelectionChanged: (value) =>
                    _set(_filter.withType(value.firstOrNull)),
              ),
              if (widget.withAccount)
                DropdownButtonFormField<int?>(
                  key: ValueKey(('account', _filter.accountId)),
                  initialValue: _filter.accountId,
                  decoration: InputDecoration(labelText: l10n.account),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
                    for (final a in state.accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (id) => _set(_filter.withAccount(id)),
                ),
              DropdownButtonFormField<int?>(
                // Other choices for another type.
                key: ValueKey(('category', _filter.type, categoryId)),
                initialValue: categoryId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.category),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
                  DropdownMenuItem(
                    value: _noCategory,
                    child: Text(l10n.noCategory),
                  ),
                  for (final c in categories)
                    DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          CategoryAvatar(category: c, radius: 12),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.categoryName(c),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (id) => _set(
                  id == _noCategory
                      ? _filter.withCategory(null, none: true)
                      : _filter.withCategory(id),
                ),
              ),
              // Opens the period picker.
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () async {
                  final chosen = await showPeriodPicker(
                    context,
                    period ?? const DatePeriod.all(),
                  );
                  if (chosen != null) _set(_filter.withPeriod(chosen));
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.period,
                    suffixIcon: period == null
                        ? const Icon(Icons.date_range)
                        : IconButton(
                            tooltip: l10n.removeFilter,
                            onPressed: () => _set(_filter.withPeriod(null)),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  child: Text(
                    period == null ? l10n.allTime : periodName(context, period),
                  ),
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _filter.cleared() == _filter
                        ? null
                        : () => _set(_filter.cleared()),
                    icon: const Icon(Icons.filter_alt_off),
                    label: Text(l10n.clearFilters),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.done),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
