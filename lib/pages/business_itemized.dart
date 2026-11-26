import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// The depreciation of [assets] in each quarter of [year].
List<int> assetsDepreciation(List<Asset> assets, int year) {
  final result = List.filled(4, 0);
  for (final asset in assets) {
    final quarters = quarterlyDepreciation(asset, year);
    for (var q = 0; q < 4; q++) {
      result[q] += quarters[q];
    }
  }
  return result;
}

/// Itemized taxation (vállalkozói SZJA) of a year from the entries of the
/// categories with a tax treatment and the assets' depreciation: the year,
/// the quarters with their advances, the sums by treatment.
class ItemizedTaxTab extends ConsumerWidget {
  const ItemizedTaxTab({super.key, required this.state, required this.year});

  final FinanceState state;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final scheme = Theme.of(context).colorScheme;
    final huf = Currency.huf;
    final tax = ItemizedTax(
      entries: state.entries,
      categories: state.categories,
      accounts: state.accounts,
      depreciation: assetsDepreciation(state.assets, year),
      year: year,
    );
    final configured = state.categories.any(
      (c) => c.taxTreatment != TaxTreatment.none,
    );
    return BusinessList(
      children: [
        if (!configured) ...[
          BusinessCard(
            title: l10n.itemizedSetupTitle,
            children: [
              Text(l10n.itemizedSetupText),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => ref
                      .read(financeProvider.notifier)
                      .addBusinessCategories(),
                  icon: const Icon(Icons.playlist_add),
                  label: Text(l10n.addBusinessCategories),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (tax.missingRates > 0) ...[
          Row(
            children: [
              Icon(Icons.warning_amber, color: scheme.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.missingExchangeRates(tax.missingRates),
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        BusinessCard(
          title: l10n.itemizedYear(year),
          children: [
            AmountRow(l10n.taxableRevenue, tax.revenue),
            AmountRow(
              l10n.costs,
              tax.costs,
              hint: l10n.depreciationHint(huf.format(tax.depreciation, locale)),
            ),
            AmountRow(l10n.taxBase, tax.base),
            AmountRow(l10n.vszja, tax.vszja),
            AmountRow(l10n.dividendBase, tax.dividendBase),
            AmountRow(l10n.dividendSzja, tax.szja),
            AmountRow(l10n.total, tax.vszja + tax.szja, strong: true),
            const Divider(),
            AmountRow(
              l10n.szochoOnDividend,
              tax.szochoOnDividend,
              hint: l10n.szochoCapHint(
                huf.format(tax.szochoCap, locale),
                huf.format(tax.szochoPaid, locale),
              ),
            ),
            AmountRow(
              l10n.localTax,
              tax.localTax,
              hint: l10n.baseHint(huf.format(tax.localTaxBase, locale)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var q = 0; q < 4; q += 2) ...[
          ResponsiveRow(
            children: [
              for (final quarter in tax.quarters.sublist(q, q + 2))
                _QuarterCard(quarter: quarter),
            ],
          ),
          const SizedBox(height: 12),
        ],
        BusinessCard(
          title: l10n.byTreatment,
          children: [
            for (final treatment in TaxTreatment.values)
              if (treatment != TaxTreatment.none && tax.total(treatment) != 0)
                AmountRow(
                  l10n.taxTreatmentName(treatment),
                  tax.total(treatment),
                ),
            if (tax.depreciation != 0)
              AmountRow(l10n.depreciation, tax.depreciation),
          ],
        ),
      ],
    );
  }
}

class _QuarterCard extends StatelessWidget {
  const _QuarterCard({required this.quarter});

  final ItemizedQuarter quarter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    return BusinessCard(
      title: l10n.quarterName(quarter.quarter),
      trailing: Text(
        l10n.deadline(DateFormat.yMMMd(locale).format(quarter.deadline)),
        style: textTheme.bodySmall,
      ),
      children: [
        AmountRow(l10n.taxableRevenue, quarter.revenue),
        AmountRow(
          l10n.costs,
          quarter.costs,
          hint: quarter.depreciation == 0
              ? null
              : l10n.depreciationHint(
                  Currency.huf.format(quarter.depreciation, locale),
                ),
        ),
        if (quarter.lossCarried != 0)
          AmountRow(l10n.lossCarried, quarter.lossCarried),
        AmountRow(l10n.taxBase, quarter.base),
        const Divider(),
        AmountRow(l10n.vszja, quarter.vszja),
        AmountRow(l10n.dividendBase, quarter.dividendBase),
        AmountRow(l10n.dividendSzja, quarter.szja),
        AmountRow(l10n.total, quarter.total, strong: true),
        if (quarter.total > 0) ...[
          const SizedBox(height: 8),
          Text(l10n.toTransfer, style: textTheme.titleSmall),
          TaxPaymentRow(payment: (kind: TaxKind.szja, amount: quarter.total)),
        ],
      ],
    );
  }
}

/// The assets with this year's depreciation and what is left of them.
class AssetsTab extends StatelessWidget {
  const AssetsTab({super.key, required this.assets, required this.year});

  final List<Asset> assets;
  final int year;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final huf = Currency.huf;
    final yearTotal = assetsDepreciation(assets, year).fold(0, (a, b) => a + b);
    return BusinessList(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.depreciationOfYear(huf.format(yearTotal, locale)),
                style: textTheme.titleSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: () => showAssetDialog(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.addAsset),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (assets.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.noAssets, textAlign: TextAlign.center),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final asset in assets)
                  ListTile(
                    onTap: () => showAssetDialog(context, asset: asset),
                    title: Text(asset.name),
                    subtitle: Text(
                      [
                        DateFormat.yMMMd(locale).format(asset.purchaseDate),
                        _ratePercent(asset.rate, locale),
                        if (asset.invoiceNumber.isNotEmpty) asset.invoiceNumber,
                        if (asset.supplier.isNotEmpty) asset.supplier,
                      ].join(' · '),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          huf.format(asset.amount, locale),
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.assetRemaining(
                            huf.format(
                              asset.amount - depreciatedBy(asset, year),
                              locale,
                            ),
                          ),
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "33%", "14,5%" (basis points).
String _ratePercent(int rate, String locale) =>
    '${NumberFormat.decimalPattern(locale).format(rate / 100)}%';

/// New asset (without [asset]) or edit / delete [asset].
Future<void> showAssetDialog(BuildContext context, {Asset? asset}) =>
    showDialog(
      context: context,
      builder: (context) => _AssetDialog(asset: asset),
    );

class _AssetDialog extends ConsumerStatefulWidget {
  const _AssetDialog({this.asset});

  final Asset? asset;

  @override
  ConsumerState<_AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends ConsumerState<_AssetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _invoiceNumber;
  late final TextEditingController _supplier;
  late final TextEditingController _amount;
  late final TextEditingController _rate;
  late DateTime _purchaseDate;
  bool _saving = false;

  bool get _isNew => widget.asset == null;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    final now = DateTime.now();
    _name = TextEditingController(text: asset?.name ?? '');
    _invoiceNumber = TextEditingController(text: asset?.invoiceNumber ?? '');
    _supplier = TextEditingController(text: asset?.supplier ?? '');
    _amount = TextEditingController(
      text: asset == null ? '' : '${asset.amount}',
    );
    _rate = TextEditingController(
      text: asset == null
          ? '33'
          : (asset.rate / 100).toString().replaceAll(RegExp(r'\.0+$'), ''),
    );
    _purchaseDate =
        asset?.purchaseDate ?? DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _invoiceNumber,
      _supplier,
      _amount,
      _rate,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// "33" or "14,5" -> 3300 / 1450 basis points; null if not 0 < x <= 100.
  static int? _parseRate(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0 || value > 100) return null;
    return (value * 100).round();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final asset = Asset(
      id: widget.asset?.id,
      name: _name.text.trim(),
      purchaseDate: _purchaseDate,
      invoiceNumber: _invoiceNumber.text.trim(),
      supplier: _supplier.text.trim(),
      amount: Currency.huf.parse(_amount.text)!,
      rate: _parseRate(_rate.text)!,
    );
    setState(() => _saving = true);
    final ok = await ref.read(financeProvider.notifier).saveAsset(asset);
    if (!mounted) return;
    if (ok) {
      nav.pop();
    } else {
      setState(() => _saving = false);
      showMessage(context, l10n.saveError);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    if (!await showConfirmDialog(context, l10n.deleteAssetConfirm)) return;
    final ok = await ref
        .read(financeProvider.notifier)
        .deleteAsset(widget.asset!);
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
    return AlertDialog(
      title: Text(_isNew ? l10n.addAsset : l10n.editAsset),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              TextFormField(
                controller: _name,
                autofocus: _isNew,
                decoration: InputDecoration(labelText: l10n.name),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? l10n.nameRequired : null,
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _purchaseDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _purchaseDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.purchaseDate,
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat.yMMMd(context.localeName).format(_purchaseDate),
                  ),
                ),
              ),
              TextFormField(
                controller: _invoiceNumber,
                decoration: InputDecoration(labelText: l10n.invoiceNumber),
              ),
              TextFormField(
                controller: _supplier,
                decoration: InputDecoration(labelText: l10n.supplier),
              ),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.assetCost,
                  suffixText: Currency.huf.symbol,
                ),
                validator: (value) {
                  final amount = Currency.huf.parse(value ?? '');
                  return amount == null || amount <= 0
                      ? l10n.amountInvalid
                      : null;
                },
              ),
              TextFormField(
                controller: _rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.depreciationRate,
                  suffixText: '%',
                  helperText: l10n.depreciationRateHelper,
                  helperMaxLines: 3,
                ),
                validator: (value) => _parseRate(value ?? '') == null
                    ? l10n.depreciationRateInvalid
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!_isNew)
          TextButton(
            onPressed: _saving ? null : _delete,
            child: Text(l10n.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.save)),
      ],
    );
  }
}
