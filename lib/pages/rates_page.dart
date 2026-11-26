import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// The current user's exchange rates: the main currency (chosen when the
/// user was made, a sole proprietor's is HUF; it doesn't change), the
/// source (MNB, ECB or manual only), downloading now (at every start:
/// Settings), the rate of each currency the user has, and the rates typed
/// in.
class RatesPage extends ConsumerWidget {
  static RatesPage builder(BuildContext context, GoRouterState state) =>
      const RatesPage();

  const RatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(financeProvider);
    final update = ref.watch(ratesProvider);
    final profile = state.profile;
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      drawer: mainDrawer(context, MainDestination.settings),
      appBar: AppBar(
        leading: backButton(context),
        title: Text(l10n.exchangeRates),
        actions: [
          if (update.running)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: l10n.updateRates,
              onPressed: () => ref.read(ratesProvider.notifier).update(),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      floatingActionButton: profile == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => const ManualRateDialog(),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.newManualRate),
            ),
      body: profile == null
          ? const SizedBox.shrink()
          : MaxWidth(
              child: ListView(
                // Room for the button.
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                children: [
                  _Settings(profile: profile, update: update),
                  const SizedBox(height: 24),
                  Text(l10n.currentRates, style: titleStyle),
                  const SizedBox(height: 8),
                  _CurrentRates(state: state),
                  const SizedBox(height: 24),
                  Text(l10n.manualRates, style: titleStyle),
                  const SizedBox(height: 8),
                  _ManualRates(state: state),
                ],
              ),
            ),
    );
  }
}

/// The main currency, the source, the download at start and how the last
/// download went.
class _Settings extends ConsumerWidget {
  const _Settings({required this.profile, required this.update});

  final Profile profile;
  final RateUpdate update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notifier = ref.read(financeProvider.notifier);
    // A sole proprietor's choice needs reporting to NAV.
    final business = profile.isSoleProprietor;
    final finished = update.finished;
    final status = update.running
        ? l10n.ratesDownloading
        : update.error != null
        ? l10n.ratesDownloadFailed(update.error!)
        : finished != null
        ? l10n.ratesDownloaded(
            DateFormat.Hm(context.localeName).format(finished),
            update.saved,
          )
        : null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              // Chosen once, when the user is made.
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.mainCurrency,
                  helperText: profile.isSoleProprietor
                      ? l10n.mainCurrencySoleProprietor
                      : l10n.mainCurrencyFixed,
                  helperMaxLines: 2,
                ),
                child: Text(l10n.currencyLabel(profile.mainCurrency)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.rateSource,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<RateSource>(
                showSelectedIcon: false,
                segments: [
                  for (final source in RateSource.values)
                    ButtonSegment(
                      value: source,
                      label: Text(
                        // A sole proprietor's own bank's rate, typed in.
                        business && source == RateSource.manual
                            ? l10n.rateSourceOwnBank
                            : l10n.rateSourceName(source),
                      ),
                    ),
                ],
                selected: {profile.rateSource},
                onSelectionChanged: (value) async {
                  final source = value.first;
                  // A sole proprietor reports the new choice first.
                  await notifier.saveProfile(
                    profile.copyWith(
                      rateSource: source,
                      rateSourceReported: false,
                    ),
                  );
                  if (!business && source != RateSource.manual) {
                    await ref.read(ratesProvider.notifier).update();
                  }
                },
              ),
            ),
            if (business && profile.rateSource != RateSource.manual)
              CheckboxListTile(
                value: profile.rateSourceReported,
                title: Text(l10n.rateSourceReported),
                subtitle: profile.rateSourceReported
                    ? null
                    : Text(l10n.rateSourceNotReported),
                onChanged: (value) async {
                  await notifier.saveProfile(
                    profile.copyWith(rateSourceReported: value ?? false),
                  );
                  if (value ?? false) {
                    await ref.read(ratesProvider.notifier).update();
                  }
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                business ? l10n.rateSourceBusinessText : l10n.rateSourceText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            if (status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: update.error != null
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The rate of each other currency of the user's accounts and invoices
/// today, in the main currency.
class _CurrentRates extends StatelessWidget {
  const _CurrentRates({required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final main = state.mainCurrency;
    final today = currentDay();
    final currencies = {
      for (final account in state.accounts) account.currency,
      for (final invoice in state.invoices) invoice.currency,
    }.where((c) => c != main).toList()..sort((a, b) => a.index - b.index);
    if (currencies.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.noForeignCurrency(main.code)),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final currency in currencies)
            switch (state.rates.quote(
              currency,
              main,
              today,
              state.rateSource,
            )) {
              final quote? => ListTile(
                title: Text(
                  '1 ${currency.code} = ${_rateText(quote.rate, main, locale)}',
                ),
                subtitle: Text(
                  '${DateFormat.yMMMd(locale).format(quote.date)} · '
                  '${l10n.rateSourceName(quote.source)}',
                ),
              ),
              null => ListTile(
                title: Text('1 ${currency.code}'),
                subtitle: Text(
                  l10n.missingRates(currency.code),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            },
        ],
      ),
    );
  }
}

/// A rate with at least four significant digits: "373,22 Ft", "2,1431 Ft",
/// "0,0026 €".
String _rateText(double rate, Currency currency, String locale) {
  final digits = rate >= 100
      ? 2
      : rate >= 1
      ? 4
      : 6;
  final number = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: digits,
  ).format(rate);
  return '$number ${currency.symbol}';
}

/// The rates typed in, the newest first, each can be deleted.
class _ManualRates extends ConsumerWidget {
  const _ManualRates({required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final rates = state.rates.manual;
    return Card(
      margin: EdgeInsets.zero,
      child: rates.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.noManualRates),
            )
          : Column(
              children: [
                for (final rate in rates)
                  ListTile(
                    title: Text(
                      '1 ${rate.currency.code} = '
                      '${_rateText(rate.rate, rate.base, locale)}',
                    ),
                    subtitle: Text(DateFormat.yMMMd(locale).format(rate.date)),
                    trailing: IconButton(
                      tooltip: l10n.delete,
                      onPressed: () =>
                          ref.read(financeProvider.notifier).deleteRate(rate),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// A rate typed in: on a day, one unit of a currency is worth so much of
/// the user's main currency. It goes before a downloaded rate of that day.
class ManualRateDialog extends ConsumerStatefulWidget {
  const ManualRateDialog({super.key});

  @override
  ConsumerState<ManualRateDialog> createState() => _ManualRateDialogState();
}

class _ManualRateDialogState extends ConsumerState<ManualRateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rate = TextEditingController();
  Currency? _currency;
  DateTime _date = currentDay();

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  static double? _parse(String text) {
    final value = double.tryParse(
      text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'),
    );
    return value == null || value <= 0 ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(financeProvider);
    final main = state.mainCurrency;
    final used = {for (final a in state.accounts) a.currency};
    // The user's currencies first.
    final currencies = [
      ...Currency.values.where((c) => c != main && used.contains(c)),
      ...Currency.values.where((c) => c != main && !used.contains(c)),
    ];
    final currency = _currency ?? currencies.first;
    return AlertDialog(
      title: Text(l10n.newManualRate),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              DropdownButtonFormField<Currency>(
                initialValue: currency,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.currency),
                items: [
                  for (final c in currencies)
                    DropdownMenuItem(
                      value: c,
                      child: Text(
                        l10n.currencyLabel(c),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _currency = value),
              ),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(currentDay().year + 1, 12, 31),
                  );
                  if (date != null) setState(() => _date = date);
                },
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
              TextFormField(
                controller: _rate,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.manualRateValue(currency.code, main.code),
                  suffixText: main.symbol,
                ),
                validator: (text) =>
                    _parse(text ?? '') == null ? l10n.manualRateInvalid : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final navigator = Navigator.of(context);
            await ref
                .read(financeProvider.notifier)
                .saveManualRate(
                  ExchangeRate(
                    source: RateSource.manual,
                    date: _date,
                    currency: currency,
                    base: main,
                    rate: _parse(_rate.text)!,
                  ),
                );
            navigator.pop();
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
