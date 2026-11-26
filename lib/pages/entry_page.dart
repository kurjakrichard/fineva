import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// New entry (route without `extra`, or on the [Account] passed as
/// `extra`), or the [Entry] passed as `extra`: to look at first (safer), its
/// edit button switches to editing (and deleting); with `?edit=1`
/// ([editEntryParameter]) right to editing.
class EntryPage extends ConsumerStatefulWidget {
  static EntryPage builder(BuildContext context, GoRouterState state) {
    final parameters = state.uri.queryParameters;
    final edit = parameters[editEntryParameter] == '1';
    return switch (state.extra) {
      final Entry entry => EntryPage(entry: entry, edit: edit),
      final Account account => EntryPage(
        account: account,
        opening: parameters[openingEntryParameter] == '1',
      ),
      _ => const EntryPage(),
    };
  }

  const EntryPage({
    super.key,
    this.entry,
    this.account,
    this.edit = false,
    this.opening = false,
  });

  /// A new entry is the opening one of [account] ([Entry.opening]): a
  /// signed amount, no type or category.
  final bool opening;

  final Entry? entry;

  /// [entry] opens to editing, not to looking at it.
  final bool edit;

  /// The account of a new entry; the first one if null.
  final Account? account;

  @override
  ConsumerState<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends ConsumerState<EntryPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late final TextEditingController _rate;
  late EntryType _type;
  int? _accountId;

  /// An opening entry ([Entry.opening]).
  late bool _opening;

  /// Where the rate in its field came from; manual once it is changed.
  RateSource? _rateSource;

  /// The rate exactly (the field shows it rounded).
  double? _rateValue;

  /// Shows [rate] (exactly [value]) from [source] in the rate field.
  void _setRate(double? value, RateSource? source) {
    _rateValue = value;
    _rateSource = value == null ? null : source;
    _rate.text = value == null ? '' : rateInput(value);
  }

  int? _categoryId;
  late DateTime _date;
  bool _saving = false;

  bool get _isNew => widget.entry == null;

  /// Opened to look at the entry: editing goes back to that.
  bool get _viewFirst => widget.entry != null && !widget.edit;

  late bool _editing = !_viewFirst;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController();
    _note = TextEditingController();
    _rate = TextEditingController();
    _load(widget.entry);
  }

  /// The form's fields from [entry] (a new one's if null).
  void _load(Entry? entry) {
    final state = ref.read(financeProvider);
    final now = DateTime.now();
    _type = entry?.type ?? EntryType.expense;
    _opening = entry?.opening ?? widget.opening;
    _accountId =
        entry?.accountId ??
        widget.account?.id ??
        state.openAccounts().firstOrNull?.id;
    _categoryId = entry?.categoryId;
    _date = entry?.date ?? DateTime(now.year, now.month, now.day);
    final account = _accountId == null ? null : state.account(_accountId!);
    _amount.text = entry == null || account == null
        ? ''
        // An opening one with its sign.
        : account.currency.toInput(
            entry.opening ? entry.signedAmount : entry.amount,
          );
    _note.text = entry?.note ?? '';
    _setRate(entry?.rate, entry?.rateSource);
    if (entry?.rate == null) _offerRate();
  }

  /// The rate of the account's currency on the day, unless one was typed
  /// in: the day's last typed in, otherwise the downloaded one.
  void _offerRate() {
    if (_rateSource == RateSource.manual) return;
    final offer = ref.read(financeProvider).offeredRate(_currency, _date);
    _setRate(offer?.rate, offer?.source);
  }

  /// Back to the downloaded rate of the day.
  void _useDownloadedRate() => setState(() {
    final state = ref.read(financeProvider);
    final rate = state.rates.downloaded(
      _currency,
      state.mainCurrency,
      _date,
      state.rateSource,
    );
    _setRate(rate?.rate, rate?.source);
  });

  /// Downloads the rates (none for the day yet), then offers the day's.
  Future<void> _downloadRates() async {
    await ref.read(ratesProvider.notifier).update();
    if (mounted) setState(_offerRate);
  }

  /// The entry as saved now (it may have been edited since it was opened).
  Entry? get _current {
    final entry = widget.entry;
    if (entry == null) return null;
    return ref
            .read(financeProvider)
            .entries
            .where((e) => e.id == entry.id)
            .firstOrNull ??
        entry;
  }

  void _startEditing() => setState(() {
    _load(_current);
    _editing = true;
  });

  /// Back to looking at the entry, the changes dropped.
  void _stopEditing() => setState(() => _editing = false);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _rate.dispose();
    super.dispose();
  }

  // Currency of the chosen account: the amount is typed in it.
  Currency get _currency {
    final id = _accountId;
    final account = id == null ? null : ref.read(financeProvider).account(id);
    return account?.currency ?? Currency.huf;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _offerRate();
      });
    }
  }

  /// The closing day the entry's day is after, on a closed account; null if
  /// it isn't.
  DateTime? get _afterClosing {
    final closed = _account(_accountId)?.closedDate;
    return closed != null && _date.isAfter(closed) ? closed : null;
  }

  Account? _account(int? id) =>
      id == null ? null : ref.read(financeProvider).account(id);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _afterClosing != null) return;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final amount = _currency.parse(_amount.text)!;
    final foreign = _currency != ref.read(financeProvider).mainCurrency;
    final rate = foreign ? _rateValue : null;
    final entry = Entry(
      id: widget.entry?.id,
      accountId: _accountId!,
      // An opening entry: its sign gives the type, no category.
      categoryId: _opening ? null : _categoryId,
      type: _opening
          ? (amount > 0 ? EntryType.income : EntryType.expense)
          : _type,
      amount: amount.abs(),
      date: _date,
      note: _note.text.trim(),
      rate: rate,
      rateSource: rate == null ? null : _rateSource ?? RateSource.manual,
      opening: _opening,
    );
    setState(() => _saving = true);
    final notifier = ref.read(financeProvider.notifier);
    // A rate typed in is the day's rate from now on.
    if (rate != null && entry.rateSource == RateSource.manual) {
      await notifier.saveManualRate(
        ExchangeRate(
          source: RateSource.manual,
          date: _date,
          currency: _currency,
          base: ref.read(financeProvider).mainCurrency,
          rate: rate,
        ),
      );
    }
    final ok = await notifier.saveEntry(entry);
    if (!mounted) return;
    if (ok && _viewFirst) {
      setState(() {
        _saving = false;
        _editing = false;
      });
    } else if (ok) {
      nav.pop();
    } else {
      setState(() => _saving = false);
      showMessage(context, l10n.saveError);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    if (!await showConfirmDialog(context, l10n.deleteEntryConfirm)) return;
    final ok = await ref
        .read(financeProvider.notifier)
        .deleteEntry(widget.entry!);
    if (!mounted) return;
    if (ok) {
      nav.pop();
    } else {
      showMessage(context, l10n.deleteError);
    }
  }

  /// "Ft / 1 EUR on the day · MNB, 20 Nov" or "· manual": the rate's
  /// unit and where it came from.
  String _rateHelper(BuildContext context, FinanceState state) {
    final l10n = context.l10n;
    final unit = l10n.entryExchangeRateHelper(
      state.mainCurrency.symbol,
      _currency.code,
    );
    final source = _rateSource;
    if (source == RateSource.manual) return '$unit · ${l10n.rateManual}';
    if (source == null || _rate.text.isEmpty) {
      return '$unit · ${l10n.noDownloadedRate}';
    }
    final offer = state.offeredRate(_currency, _date);
    final day = offer == null
        ? ''
        : ', ${DateFormat.MMMd(context.localeName).format(offer.date)}';
    return '$unit · ${l10n.rateSourceName(source)}$day';
  }

  /// Back to the downloaded rate after typing one in; download if there is
  /// none.
  Widget? _rateButton(BuildContext context, FinanceState state) {
    final l10n = context.l10n;
    final downloaded = state.rates.downloaded(
      _currency,
      state.mainCurrency,
      _date,
      state.rateSource,
    );
    if (downloaded == null) {
      return IconButton(
        tooltip: l10n.updateRates,
        onPressed: _downloadRates,
        icon: const Icon(Icons.download),
      );
    }
    if (_rateSource != RateSource.manual) return null;
    return IconButton(
      tooltip: l10n.useDownloadedRate,
      onPressed: _useDownloadedRate,
      icon: const Icon(Icons.restore),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeProvider);
    final current = _current;
    if (!_editing && current != null) {
      return EntryView(
        state: state,
        entry: current,
        // An invoice's payment is changed on the invoice.
        onEdit: current.invoiceId == null
            ? _startEditing
            : () => openEntry(context, state, current, edit: true),
      );
    }
    // The user's kind of categories, and the entry's own if it is of the
    // other kind (saved before the user's kind changed).
    final categories = [
      for (final category in state.categories)
        if (category.type == _type &&
            (category.scope == state.categoryScope ||
                category.id == _categoryId))
          category,
    ];

    return PopScope(
      // Back from editing goes back to looking at it.
      canPop: !_viewFirst,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopEditing();
      },
      child: _form(context, state, categories),
    );
  }

  Widget _form(
    BuildContext context,
    FinanceState state,
    List<EntryCategory> categories,
  ) {
    final l10n = context.l10n;
    return Scaffold(
      drawer: mainDrawer(context, null),
      appBar: AppBar(
        leading: _viewFirst
            ? IconButton(
                tooltip: l10n.discardChanges,
                onPressed: _stopEditing,
                icon: const Icon(Icons.close),
              )
            : backButton(context),
        title: Text(
          _opening
              ? (_isNew ? l10n.newOpeningEntry : l10n.openingEntry)
              : _isNew
              ? l10n.addEntry
              : l10n.editEntry,
        ),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: l10n.delete,
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete),
            ),
        ],
      ),
      body: MaxWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_opening) ...[
                // A new one can be a transfer too: its own page.
                SegmentedButton<EntryType?>(
                  segments: [
                    for (final type in EntryType.values)
                      ButtonSegment(
                        value: type,
                        label: Text(l10n.entryTypeName(type)),
                      ),
                    if (_isNew)
                      ButtonSegment(value: null, label: Text(l10n.transfer)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) {
                    final type = value.first;
                    if (type == null) {
                      context.pushReplacementNamed(
                        Routes.transfer.name,
                        extra: state.account(_accountId ?? -1),
                      );
                      return;
                    }
                    setState(() {
                      _type = type;
                      // A category of the other type doesn't fit any more.
                      if (state.category(_categoryId)?.type != _type) {
                        _categoryId = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _amount,
                autofocus: _isNew,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: true,
                  signed: _opening,
                ),
                decoration: InputDecoration(
                  labelText: _opening ? l10n.initialBalance : l10n.amount,
                  suffixText: _currency.symbol,
                ),
                // An opening balance may be negative (overdrawn), not 0.
                validator: (value) {
                  final amount = _currency.parse(value ?? '');
                  if (_opening) {
                    return amount == null || amount == 0
                        ? l10n.openingAmountInvalid
                        : null;
                  }
                  return amount == null || amount <= 0
                      ? l10n.amountInvalid
                      : null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _accountId,
                decoration: InputDecoration(labelText: l10n.account),
                items: [
                  // A closed one only if it's the entry's.
                  for (final account in state.openAccounts(
                    keep: widget.entry?.accountId,
                  ))
                    DropdownMenuItem(
                      value: account.id,
                      child: Text('${account.name} (${account.currency.code})'),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _accountId = value;
                  _offerRate();
                }),
              ),
              if (!_opening) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  // A new field when the type changes: the choices change too.
                  key: ValueKey(_type),
                  initialValue: _categoryId,
                  // The items' Expanded names need the field's width.
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.category),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.noCategory)),
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Row(
                          children: [
                            CategoryAvatar(category: category, radius: 12),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.categoryName(category),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
              ],
              // Another currency than the main one: the day's rate.
              if (_currency != state.mainCurrency) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.exchangeRate,
                    helperText: _rateHelper(context, state),
                    helperMaxLines: 2,
                    suffixIcon: _rateButton(context, state),
                  ),
                  // Typed in: manual, the day's rate when saved.
                  onChanged: (text) => setState(() {
                    _rateValue = parseRate(text);
                    _rateSource = RateSource.manual;
                  }),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    // Needed for the business taxes in forints.
                    final taxed =
                        (state.category(_categoryId)?.taxTreatment ??
                            TaxTreatment.none) !=
                        TaxTreatment.none;
                    if (text.isEmpty) {
                      return taxed ? l10n.exchangeRateInvalid : null;
                    }
                    return parseRate(text) == null
                        ? l10n.exchangeRateInvalid
                        : null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.date,
                    // A closed account has no entries after it closed.
                    errorText: switch (_afterClosing) {
                      final closed? => l10n.closedOn(
                        DateFormat.yMMMd(context.localeName).format(closed),
                      ),
                      null => null,
                    },
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat.yMMMd(context.localeName).format(_date),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.note),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An entry to look at: what, how much, on which account, when, the note,
/// the invoice it pays. The app bar's [onEdit] switches to editing, the
/// button below closes it.
class EntryView extends StatelessWidget {
  const EntryView({
    super.key,
    required this.state,
    required this.entry,
    required this.onEdit,
  });

  final FinanceState state;
  final Entry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final account = state.account(entry.accountId);
    final category = state.category(entry.categoryId);
    final currency = account?.currency ?? state.mainCurrency;
    final main = state.mainCurrency;
    final inMain = currency == main ? null : state.entryInMain(entry);
    final invoiceId = entry.invoiceId;
    final invoice = invoiceId == null
        ? null
        : state.invoices.where((i) => i.id == invoiceId).firstOrNull;
    final rate = entry.rate;
    Widget detail(IconData icon, String label, String value) => ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      subtitle: Text(value, style: textTheme.bodyLarge),
    );
    return Scaffold(
      drawer: mainDrawer(context, null),
      appBar: AppBar(
        leading: backButton(context),
        title: Text(l10n.entry),
        actions: [
          IconButton(
            tooltip: l10n.edit,
            onPressed: onEdit,
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CategoryAvatar(
                      category: category,
                      type: entry.type,
                      radius: 24,
                      opening: entry.opening,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.opening
                                ? l10n.openingEntry
                                : category == null
                                ? l10n.noCategory
                                : l10n.categoryName(category),
                            style: textTheme.titleLarge,
                          ),
                          if (!entry.opening)
                            Text(
                              l10n.entryTypeName(entry.type),
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AmountText(
                          entry.signedAmount,
                          currency,
                          signed: true,
                          style: textTheme.headlineSmall,
                        ),
                        if (inMain != null)
                          Text(
                            '≈ ${main.format(inMain, locale)}',
                            style: textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  detail(
                    Icons.account_balance_wallet_outlined,
                    l10n.account,
                    account == null
                        ? '–'
                        : '${account.name} (${account.currency.code})',
                  ),
                  // Updated when it is changed: from the saved entries.
                  if ((account, state.balanceAfter(entry)) case (
                    final account?,
                    final balance?,
                  ))
                    detail(
                      Icons.account_balance_outlined,
                      l10n.balanceAfterEntry,
                      account.currency.format(balance, locale),
                    ),
                  detail(
                    Icons.event,
                    l10n.date,
                    DateFormat.yMMMMEEEEd(locale).format(entry.date),
                  ),
                  if (entry.note.isNotEmpty)
                    detail(Icons.notes, l10n.note, entry.note),
                  if (rate != null)
                    detail(
                      Icons.currency_exchange,
                      l10n.exchangeRate,
                      [
                        '${rateInput(rate)} ${main.symbol} / 1 ${currency.code}',
                        if (entry.rateSource case final source?)
                          source == RateSource.manual
                              ? l10n.rateManual
                              : l10n.rateSourceName(source),
                      ].join(' · '),
                    ),
                  if (invoice != null)
                    ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(
                        l10n.paysInvoice,
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      subtitle: Text(
                        [
                          invoice.number,
                          if (invoice.partnerName.isNotEmpty)
                            invoice.partnerName,
                        ].join(' · '),
                        style: textTheme.bodyLarge,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.pushNamed<Invoice>(
                        Routes.invoice.name,
                        extra: invoice,
                      ),
                    ),
                ],
              ),
            ),
            if (invoice != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.bookedEntryText,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            // Editing is in the app bar.
            FilledButton.tonal(
              onPressed: () => Navigator.maybePop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      ),
    );
  }
}
