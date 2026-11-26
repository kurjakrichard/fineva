import 'package:equatable/equatable.dart';

import '../../data/data_export.dart';
import '../../utils/utils.dart';
import 'date_period.dart';
import 'finance_state.dart';

/// The order of a filtered entry list.
enum EntrySort {
  /// By date, the newest first (as recorded on a day).
  newest,
  oldest,

  /// By amount (in the main currency) with its sign, the largest first:
  /// the largest income first, the largest expense last.
  largest,
  smallest,
}

/// Which entries the entries page shows: a text search and filters by type,
/// account, category and period, and their order ([sort]). Nothing set:
/// every entry, the newest first.
class EntryFilter extends Equatable {
  const EntryFilter({
    this.text = '',
    this.type,
    this.accountId,
    this.categoryId,
    this.withoutCategory = false,
    this.period,
    this.sort = EntrySort.newest,
  });

  /// Words to find in the note, the category's and the account's name, or
  /// the amount; every word must be found. Case and accents don't matter.
  final String text;
  final EntryType? type;
  final int? accountId;

  /// One category; see [withoutCategory] for the entries without one.
  final int? categoryId;
  final bool withoutCategory;

  /// Null for all time (never [DatePeriod.all]).
  final DatePeriod? period;

  /// Not a filter: [isActive] and [count] leave it out.
  final EntrySort sort;

  bool get isActive =>
      text.trim().isNotEmpty ||
      type != null ||
      accountId != null ||
      categoryId != null ||
      withoutCategory ||
      period != null;

  /// How many filters are set (the search not counted).
  int get count => [
    type != null,
    accountId != null,
    categoryId != null || withoutCategory,
    period != null,
  ].where((set) => set).length;

  EntryFilter withText(String text) => _copy(text: text);
  EntryFilter withType(EntryType? type) => _copy(type: () => type);
  EntryFilter withAccount(int? accountId) => _copy(accountId: () => accountId);

  /// One category, or [none] for the entries without category, or neither
  /// for every entry.
  EntryFilter withCategory(int? categoryId, {bool none = false}) =>
      _copy(categoryId: () => none ? null : categoryId, withoutCategory: none);
  EntryFilter withPeriod(DatePeriod? period) =>
      _copy(period: () => period == null || period.isAll ? null : period);

  EntryFilter withSort(EntrySort sort) => _copy(sort: sort);

  /// Only the text and the order kept.
  EntryFilter cleared() => EntryFilter(text: text, sort: sort);

  EntryFilter _copy({
    String? text,
    EntryType? Function()? type,
    int? Function()? accountId,
    int? Function()? categoryId,
    bool? withoutCategory,
    DatePeriod? Function()? period,
    EntrySort? sort,
  }) => EntryFilter(
    text: text ?? this.text,
    type: type == null ? this.type : type(),
    accountId: accountId == null ? this.accountId : accountId(),
    categoryId: categoryId == null ? this.categoryId : categoryId(),
    withoutCategory: withoutCategory ?? this.withoutCategory,
    period: period == null ? this.period : period(),
    sort: sort ?? this.sort,
  );

  /// [state]'s entries that pass, in the order of [sort]. [categoryName] gives a
  /// category's shown (translated) name for the search, [openingName] an
  /// opening entry's.
  List<Entry> apply(
    FinanceState state,
    String Function(EntryCategory category) categoryName, {
    String openingName = '',
    String transferName = '',
  }) {
    final words = foldForSearch(text)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final found = [
      for (final entry in state.entries)
        if (_passes(
          entry,
          state,
          words,
          categoryName,
          openingName,
          transferName,
        ))
          entry,
    ];
    // The state's order is the newest first.
    switch (sort) {
      case EntrySort.newest:
        break;
      case EntrySort.oldest:
        return found.reversed.toList();
      case EntrySort.largest || EntrySort.smallest:
        // With its sign: an expense is less than any income.
        int size(Entry entry) => state.entryInMain(entry) ?? entry.signedAmount;
        final sign = sort == EntrySort.largest ? -1 : 1;
        // Equal amounts stay the newest first.
        final indexed = found.indexed.toList()
          ..sort((a, b) {
            final bySize = sign * size(a.$2).compareTo(size(b.$2));
            return bySize != 0 ? bySize : a.$1.compareTo(b.$1);
          });
        return [for (final (_, entry) in indexed) entry];
    }
    return found;
  }

  bool _passes(
    Entry entry,
    FinanceState state,
    List<String> words,
    String Function(EntryCategory category) categoryName,
    String openingName,
    String transferName,
  ) {
    // An opening entry or a transfer is no income or expense.
    if (type != null &&
        (entry.type != type || entry.opening || entry.isTransfer)) {
      return false;
    }
    if (accountId != null && entry.accountId != accountId) return false;
    // An opening entry or a transfer has no category, but it isn't one
    // without.
    if (withoutCategory &&
        (entry.categoryId != null || entry.opening || entry.isTransfer)) {
      return false;
    }
    if (categoryId != null && entry.categoryId != categoryId) return false;
    if (!(period?.contains(entry.date) ?? true)) return false;
    if (words.isEmpty) return true;
    final account = state.account(entry.accountId);
    final category = state.category(entry.categoryId);
    final amount = _digits(
      (account?.currency ?? Currency.huf).toInput(entry.amount),
    );
    final haystack = foldForSearch(
      [
        entry.note,
        if (entry.opening) openingName,
        if (entry.isTransfer) ...[
          transferName,
          ?state.transferPeer(entry)?.name,
        ],
        if (category != null) categoryName(category),
        if (account != null) account.name,
      ].join(' '),
    );
    for (final word in words) {
      // A number is also looked for in the amount: "23 450", "12,50".
      final digits = _digits(word);
      final numeric = RegExp(r'^[\d.,]+$').hasMatch(word);
      final found =
          haystack.contains(word) || (numeric && amount.contains(digits));
      if (!found) return false;
    }
    return true;
  }

  static String _digits(String text) => text.replaceAll(RegExp(r'\D'), '');

  @override
  List<Object?> get props => [
    text,
    type,
    accountId,
    categoryId,
    withoutCategory,
    period,
    sort,
  ];
}

const Map<String, String> _accents = {
  'á': 'a',
  'é': 'e',
  'í': 'i',
  'ó': 'o',
  'ö': 'o',
  'ő': 'o',
  'ú': 'u',
  'ü': 'u',
  'ű': 'u',
  'ä': 'a',
  'à': 'a',
  'è': 'e',
  'ô': 'o',
};

/// [text] in lower case without accents, for searching: "Közlekedés" ->
/// "kozlekedes".
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}
