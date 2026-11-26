import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// A transfer (átvezetés) between two of the user's accounts: no income or
/// expense, the same worth on both sides (`transferSides`). New (route
/// without `extra`, or from the [Account] passed as `extra`), or the one
/// whose id is passed as `extra`: to look at first, its edit button
/// switches to editing (and deleting); with `?edit=1` right to editing.
class TransferPage extends ConsumerStatefulWidget {
  static TransferPage builder(BuildContext context, GoRouterState state) {
    final edit = state.uri.queryParameters[editEntryParameter] == '1';
    return switch (state.extra) {
      final int id => TransferPage(transferId: id, edit: edit),
      final Account account => TransferPage(from: account),
      _ => const TransferPage(),
    };
  }

  const TransferPage({
    super.key,
    this.transferId,
    this.from,
    this.edit = false,
  });

  /// Null for a new transfer.
  final int? transferId;

  /// A new transfer's account to go from; the first one if null.
  final Account? from;

  /// [transferId] opens to editing, not to looking at it.
  final bool edit;

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _received = TextEditingController();
  final _rate = TextEditingController();
  final _note = TextEditingController();
  int? _fromId;
  int? _toId;
  late DateTime _date;
  bool _saving = false;

  /// The rate of the account it goes from, needed when neither account is
  /// of the main currency; exactly (the field shows it rounded).
  double? _rateValue;
  RateSource? _rateSource;

  bool get _isNew => widget.transferId == null;

  /// Opened to look at the transfer: editing goes back to that.
  bool get _viewFirst => !_isNew && !widget.edit;

  late bool _editing = !_viewFirst;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _received.dispose();
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  ({Entry from, Entry to})? get _sides {
    final id = widget.transferId;
    return id == null ? null : ref.read(financeProvider).transferSides(id);
  }

  Account? _account(int? id) =>
      id == null ? null : ref.read(financeProvider).account(id);

  Currency get _main => ref.read(financeProvider).mainCurrency;
  Currency get _fromCurrency => _account(_fromId)?.currency ?? _main;
  Currency get _toCurrency => _account(_toId)?.currency ?? _main;

  /// Neither account is of the main currency: the worth needs a rate.
  bool get _needsRate => _fromCurrency != _main && _toCurrency != _main;

  /// The form's fields from the saved transfer, or a new one's.
  void _load() {
    final state = ref.read(financeProvider);
    final sides = _sides;
    if (sides != null) {
      _fromId = sides.from.accountId;
      _toId = sides.to.accountId;
      _date = sides.from.date;
      _amount.text = _fromCurrency.toInput(sides.from.amount);
      _received.text = _toCurrency.toInput(sides.to.amount);
      _note.text = sides.from.note;
      _setRate(sides.from.rate, sides.from.rateSource);
    } else {
      final accounts = state.openAccounts();
      _fromId = widget.from?.id ?? accounts.firstOrNull?.id;
      _toId = accounts.where((a) => a.id != _fromId).firstOrNull?.id;
      _date = currentDay();
      _amount.text = '';
      _received.text = '';
      _note.text = '';
      _setRate(null, null);
    }
    _offerRate();
  }

  void _setRate(double? value, RateSource? source) {
    _rateValue = value;
    _rateSource = value == null ? null : source;
    _rate.text = value == null ? '' : rateInput(value);
  }

  /// The day's rate of the account it goes from, unless one was typed in.
  void _offerRate() {
    if (!_needsRate || _rateSource == RateSource.manual) return;
    final offer = ref.read(financeProvider).offeredRate(_fromCurrency, _date);
    _setRate(offer?.rate, offer?.source);
  }

  ({Entry from, Entry to, List<ExchangeRate> dayRates})? _made() {
    final from = _account(_fromId);
    final to = _account(_toId);
    if (from == null || to == null) return null;
    return transferSides(
      from: from,
      to: to,
      fromAmount: from.currency.parse(_amount.text) ?? 0,
      toAmount: to.currency.parse(_received.text),
      date: _date,
      note: _note.text.trim(),
      main: _main,
      fromRate: _rateValue,
      fromRateSource: _rateSource,
    );
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    // A closed account has no entries after it closed.
    for (final account in [_account(_fromId), _account(_toId)]) {
      final closed = account?.closedDate;
      if (closed != null && _date.isAfter(closed)) {
        showMessage(
          context,
          '${account!.name}: '
          '${l10n.closedOn(DateFormat.yMMMd(context.localeName).format(closed))}',
        );
        return;
      }
    }
    final made = _made();
    if (made == null) {
      showMessage(context, l10n.saveError);
      return;
    }
    setState(() => _saving = true);
    final ok = await ref
        .read(financeProvider.notifier)
        .saveTransfer(
          widget.transferId,
          made.from,
          made.to,
          dayRates: made.dayRates,
        );
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
    if (!await showConfirmDialog(context, l10n.deleteTransferConfirm)) return;
    final ok = await ref
        .read(financeProvider.notifier)
        .deleteTransfer(widget.transferId!);
    if (!mounted) return;
    if (ok) {
      nav.pop();
    } else {
      showMessage(context, l10n.deleteError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(financeProvider);
    final id = widget.transferId;
    final sides = id == null ? null : state.transferSides(id);
    if (id != null && sides == null) {
      // Deleted meanwhile.
      return Scaffold(
        drawer: mainDrawer(context, null),
        appBar: AppBar(
          leading: backButton(context),
          title: Text(l10n.transfer),
        ),
        body: Center(child: Text(l10n.transferNotFound)),
      );
    }
    if (!_editing && sides != null) {
      return _TransferView(
        state: state,
        from: sides.from,
        to: sides.to,
        onEdit: () => setState(() {
          _load();
          _editing = true;
        }),
      );
    }
    return PopScope(
      // Back from editing goes back to looking at it.
      canPop: !_viewFirst,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _editing = false);
      },
      child: _form(context, state),
    );
  }

  Widget _form(BuildContext context, FinanceState state) {
    final l10n = context.l10n;
    final main = state.mainCurrency;
    final fromCurrency = _fromCurrency;
    final toCurrency = _toCurrency;
    final made = _made();
    // The rate the amounts make, of the side that isn't the main currency.
    final madeRate = made == null
        ? null
        : fromCurrency != main
        ? (fromCurrency, made.from.rate)
        : toCurrency != main
        ? (toCurrency, made.to.rate)
        : null;
    DropdownButtonFormField<int> accountField(
      String label,
      int? value,
      ValueChanged<int?> onChanged,
    ) => DropdownButtonFormField<int>(
      key: ValueKey((label, value)),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        // A closed one only if it's a side already.
        for (final account in state.accounts)
          if (!account.isClosed ||
              account.id == _sides?.from.accountId ||
              account.id == _sides?.to.accountId)
            DropdownMenuItem(
              value: account.id,
              child: Text(
                '${account.name} (${account.currency.code})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ],
      validator: (_) => _fromId == _toId ? l10n.transferSameAccount : null,
      onChanged: onChanged,
    );
    return Scaffold(
      drawer: mainDrawer(context, null),
      appBar: AppBar(
        leading: _viewFirst
            ? IconButton(
                tooltip: l10n.discardChanges,
                onPressed: () => setState(() => _editing = false),
                icon: const Icon(Icons.close),
              )
            : backButton(context),
        title: Text(_isNew ? l10n.newTransfer : l10n.editTransfer),
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
              Text(
                l10n.transferText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              accountField(
                l10n.transferFrom,
                _fromId,
                (value) => setState(() {
                  _fromId = value;
                  _offerRate();
                }),
              ),
              const SizedBox(height: 16),
              accountField(
                l10n.transferTo,
                _toId,
                (value) => setState(() {
                  _toId = value;
                  _offerRate();
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: _isNew,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.amount,
                  suffixText: fromCurrency.symbol,
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final amount = fromCurrency.parse(value ?? '');
                  return amount == null || amount <= 0
                      ? l10n.amountInvalid
                      : null;
                },
              ),
              // Another currency arrives: how much.
              if (toCurrency != fromCurrency) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _received,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.transferReceived,
                    suffixText: toCurrency.symbol,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final amount = toCurrency.parse(value ?? '');
                    return amount == null || amount <= 0
                        ? l10n.amountInvalid
                        : null;
                  },
                ),
              ],
              // Neither is the main currency: the worth is at a rate.
              if (_needsRate) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.exchangeRate,
                    helperText:
                        '${l10n.entryExchangeRateHelper(main.symbol, fromCurrency.code)}'
                        ' · ${_rateSource == null
                            ? l10n.noDownloadedRate
                            : _rateSource == RateSource.manual
                            ? l10n.rateManual
                            : l10n.rateSourceName(_rateSource!)}',
                    helperMaxLines: 2,
                  ),
                  onChanged: (text) => setState(() {
                    _rateValue = parseRate(text);
                    _rateSource = RateSource.manual;
                  }),
                  validator: (value) => parseRate(value ?? '') == null
                      ? l10n.exchangeRateInvalid
                      : null,
                ),
              ],
              if (madeRate case (final currency, final rate?))
                if (!_needsRate || currency == toCurrency)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.transferRateMade(
                        currency.code,
                        '${rateInput(rate)} ${main.symbol}',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.date,
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

/// A transfer to look at: from where to where, how much, its worth, when,
/// the note. The app bar's [onEdit] switches to editing, the button below
/// closes it.
class _TransferView extends StatelessWidget {
  const _TransferView({
    required this.state,
    required this.from,
    required this.to,
    required this.onEdit,
  });

  final FinanceState state;
  final Entry from;
  final Entry to;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final main = state.mainCurrency;
    final fromAccount = state.account(from.accountId);
    final toAccount = state.account(to.accountId);
    final worth = state.entryInMain(to);
    final foreign =
        fromAccount?.currency != main || toAccount?.currency != main;
    Widget side(String label, Account? account, Entry entry) => ListTile(
      leading: const Icon(Icons.account_balance_wallet_outlined),
      title: Text(
        label,
        style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      // The account, and its balance just after the transfer.
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(account?.name ?? '–', style: textTheme.bodyLarge),
          if ((account, state.balanceAfter(entry)) case (
            final account?,
            final balance?,
          ))
            Text(
              '${l10n.balanceAfterEntry}: '
              '${account.currency.format(balance, locale)}',
              style: textTheme.bodySmall,
            ),
        ],
      ),
      trailing: account == null
          ? null
          : AmountText(
              entry.signedAmount,
              account.currency,
              signed: true,
              style: textTheme.titleMedium,
            ),
    );
    Widget detail(IconData icon, String label, String value) => ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      subtitle: Text(value, style: textTheme.bodyLarge),
    );
    // The rate of the side that isn't the main currency.
    final rated = [
      if (fromAccount != null && fromAccount.currency != main)
        (fromAccount.currency, from.rate),
      if (toAccount != null && toAccount.currency != main)
        (toAccount.currency, to.rate),
    ];
    return Scaffold(
      drawer: mainDrawer(context, null),
      appBar: AppBar(
        leading: backButton(context),
        title: Text(l10n.transfer),
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
              child: Column(
                children: [
                  side(l10n.transferFrom, fromAccount, from),
                  const Icon(Icons.arrow_downward),
                  side(l10n.transferTo, toAccount, to),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  if (foreign && worth != null)
                    detail(
                      Icons.balance,
                      l10n.transferWorth,
                      main.format(worth, locale),
                    ),
                  for (final (currency, rate) in rated)
                    if (rate != null)
                      detail(
                        Icons.currency_exchange,
                        l10n.exchangeRate,
                        '${rateInput(rate)} ${main.symbol} / 1 ${currency.code}',
                      ),
                  detail(
                    Icons.event,
                    l10n.date,
                    DateFormat.yMMMMEEEEd(locale).format(from.date),
                  ),
                  if (from.note.isNotEmpty)
                    detail(Icons.notes, l10n.note, from.note),
                ],
              ),
            ),
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
