import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// A new outgoing invoice paid the whole on [date] (recorded from the
/// revenue record): `extra` of the invoice page.
class PaidInvoice {
  const PaidInvoice(this.date, [this.method = PaymentMethod.transfer]);

  final DateTime date;
  final PaymentMethod method;
}

/// A sole proprietor's invoice: edit / delete the [Invoice] passed as
/// `extra`, or a new one of the [InvoiceDirection] passed (outgoing without
/// `extra`), or a new outgoing one already paid ([PaidInvoice]).
///
/// The VAT codes offered depend on the direction and where the partner is;
/// the VAT is calculated from the net amount and can be corrected. Another
/// currency's rate is of [Invoice.rateDate]: typed in (the own bank's), or
/// the MNB's / ECB's if the user reported that choice to NAV (downloaded if
/// missing). Its payments (any number, see [InvoicePayment]) are recorded
/// below; it is paid when they add up to its gross amount.
class InvoicePage extends ConsumerStatefulWidget {
  static InvoicePage builder(BuildContext context, GoRouterState state) =>
      switch (state.extra) {
        final Invoice invoice => InvoicePage(invoice: invoice),
        final InvoiceDirection direction => InvoicePage(direction: direction),
        final PaidInvoice paid => InvoicePage(paid: paid),
        _ => const InvoicePage(),
      };

  const InvoicePage({
    super.key,
    this.invoice,
    this.direction = InvoiceDirection.outgoing,
    this.paid,
  });

  final Invoice? invoice;

  /// Of a new invoice.
  final InvoiceDirection direction;

  /// A new outgoing invoice paid the whole on recording it.
  final PaidInvoice? paid;

  @override
  ConsumerState<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends ConsumerState<InvoicePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _description;
  late final TextEditingController _partnerName;
  late final TextEditingController _partnerTaxNumber;
  late final TextEditingController _exchangeRate;
  late final TextEditingController _net;
  late final TextEditingController _vat;
  late final TextEditingController _paidRate;

  late InvoiceDirection _direction;
  late PartnerLocation _location;
  late PaymentMethod _paymentMethod;
  late DateTime _issueDate;
  late DateTime _fulfillmentDate;
  DateTime? _dueDate;
  late Currency _currency;
  late VatCode _vatCode;

  /// The payments, saved with the invoice.
  late List<InvoicePayment> _payments;

  /// Paid the whole when recorded (from the revenue record): a payment of
  /// whatever the gross amount becomes, until edited.
  PaidInvoice? _paidWhole;

  /// The downloads of the rates of a source, currency and year tried, not
  /// to try them again by themselves.
  final _downloadsTried = <(RateSource, Currency, int)>{};
  bool _downloading = false;
  bool _downloadFailed = false;

  /// Where the payment is booked; null: not booked.
  int? _paidAccountId;
  int? _categoryId;
  bool _saving = false;

  bool get _isNew => widget.invoice == null;

  @override
  void initState() {
    super.initState();
    final invoice = widget.invoice;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _direction = invoice?.direction ?? widget.direction;
    _location = invoice?.partnerLocation ?? PartnerLocation.domestic;
    _paymentMethod = invoice?.paymentMethod ?? PaymentMethod.transfer;
    _issueDate = invoice?.issueDate ?? today;
    _fulfillmentDate = invoice?.fulfillmentDate ?? today;
    _dueDate = invoice?.dueDate;
    _currency = invoice?.currency ?? Currency.huf;
    _vatCode = invoice?.vatCode ?? _defaultCode();
    _payments = [...?invoice?.payments];
    _paidWhole = widget.paid;
    if (widget.paid case final paid?) _paymentMethod = paid.method;
    _number = TextEditingController(text: invoice?.number ?? '');
    _description = TextEditingController(text: invoice?.description ?? '');
    _partnerName = TextEditingController(text: invoice?.partnerName ?? '');
    _partnerTaxNumber = TextEditingController(
      text: invoice?.partnerTaxNumber ?? '',
    );
    _exchangeRate = TextEditingController(
      text: invoice == null || invoice.currency == Currency.huf
          ? ''
          : _rateText(invoice.exchangeRate),
    );
    String amount(int? value) => value == null ? '' : _currency.toInput(value);
    _net = TextEditingController(text: amount(invoice?.netAmount));
    _vat = TextEditingController(text: amount(invoice?.vatAmount));
    final paidRate = invoice?.paidExchangeRate;
    _paidRate = TextEditingController(
      text: paidRate == null ? '' : _rateText(paidRate),
    );
    final state = ref.read(financeProvider);
    _paidAccountId = invoice == null
        ? _defaultAccount(state)?.id
        : invoice.paidAccountId;
    _categoryId = invoice == null
        ? _defaultCategory(state)?.id
        : invoice.categoryId;
  }

  // The accounts a payment of the currency can be booked on: of the same
  // currency, or forint.
  List<Account> _accounts(FinanceState state) => [
    for (final account in state.openAccounts(keep: _paidAccountId))
      if (account.currency == _currency || account.currency == Currency.huf)
        account,
  ];

  Account? _defaultAccount(FinanceState state) {
    final accounts = _accounts(state);
    return accounts.where((a) => a.currency == _currency).firstOrNull ??
        accounts.firstOrNull;
  }

  // The categories of the direction: income for a sale, expense for a cost.
  List<EntryCategory> _categories(FinanceState state) {
    final type = _direction == InvoiceDirection.outgoing
        ? EntryType.income
        : EntryType.expense;
    return [
      for (final category in state.visibleCategories)
        if (category.type == type) category,
    ];
  }

  // Itemized taxation: the revenue / other cost; otherwise the business
  // income / expense.
  EntryCategory? _defaultCategory(FinanceState state) {
    final outgoing = _direction == InvoiceDirection.outgoing;
    final categories = _categories(state);
    return categories
            .where(
              (c) =>
                  c.taxTreatment ==
                  (outgoing ? TaxTreatment.revenue : TaxTreatment.otherCost),
            )
            .firstOrNull ??
        categories
            .where(
              (c) =>
                  c.systemKey ==
                  (outgoing ? 'businessIncome' : 'businessExpense'),
            )
            .firstOrNull ??
        categories.firstOrNull;
  }

  // After the direction or the currency changed.
  void _checkBooking() {
    final state = ref.read(financeProvider);
    if (!_categories(state).any((c) => c.id == _categoryId)) {
      _categoryId = _defaultCategory(state)?.id;
    }
    if (_paidAccountId != null &&
        !_accounts(state).any((a) => a.id == _paidAccountId)) {
      _paidAccountId = _defaultAccount(state)?.id;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _number,
      _description,
      _partnerName,
      _partnerTaxNumber,
      _exchangeRate,
      _net,
      _vat,
      _paidRate,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _rateText(int rate) => exchangeRateText(rate);

  static int? _parseRate(String text) => parseExchangeRate(text);

  // The usual code of the direction and the partner's location; a VAT
  // exempt sole proprietor's domestic sales are AAM.
  VatCode _defaultCode() {
    final registered =
        ref.read(financeProvider).profile?.vatStatus == VatStatus.registered;
    final outgoing = _direction == InvoiceDirection.outgoing;
    return switch (_location) {
      PartnerLocation.domestic =>
        outgoing && !registered ? VatCode.aam : VatCode.vat27,
      PartnerLocation.eu => outgoing ? VatCode.eufad37 : VatCode.euServices,
      PartnerLocation.thirdCountry =>
        outgoing ? VatCode.ho : VatCode.importServices,
    };
  }

  // After the direction or the location changed.
  void _checkCode() {
    if (!VatCode.available(_direction, _location).contains(_vatCode)) {
      _vatCode = _defaultCode();
      _updateVat();
    }
  }

  // The VAT of the net amount at the code's rate.
  void _updateVat() {
    final net = _currency.parse(_net.text);
    _vat.text = net == null || _vatCode.rate == null
        ? ''
        : _currency.toInput(Invoice.vatOf(net, _vatCode));
  }

  int? get _gross {
    final net = _currency.parse(_net.text);
    if (net == null) return null;
    return net + (_vatCode.rate == null ? 0 : _currency.parse(_vat.text) ?? 0);
  }

  int get _paid => _payments.fold(0, (sum, p) => sum + p.amount);

  /// The day of the rate: the fulfillment, or the issue if earlier.
  DateTime get _rateDate =>
      _issueDate.isBefore(_fulfillmentDate) ? _issueDate : _fulfillmentDate;

  /// The MNB's / ECB's rate is used (reported to NAV), not the own bank's.
  bool _official(FinanceState state) =>
      _currency != Currency.huf && state.rateSource != RateSource.manual;

  /// The MNB's / ECB's rate of [_rateDate]; null if not downloaded yet.
  RateQuote? _officialRate(FinanceState state) => state.rates.official(
    _currency,
    Currency.huf,
    _rateDate,
    state.rateSource,
  );

  /// The rate of the invoice (scaled), null if there is none (yet).
  int? _rate(FinanceState state) {
    if (_currency == Currency.huf) return Invoice.rateScale;
    if (!_official(state)) return _parseRate(_exchangeRate.text);
    final quote = _officialRate(state);
    return quote == null ? null : (quote.rate * Invoice.rateScale).round();
  }

  /// Downloads the year's rates of the currency if the rate of the day is
  /// missing; once by itself, again with the button.
  Future<void> _downloadRates(FinanceState state, {bool again = false}) async {
    if (!_official(state) || _officialRate(state) != null || _downloading) {
      return;
    }
    final key = (state.rateSource, _currency, _rateDate.year);
    if (!_downloadsTried.add(key) && !again) return;
    setState(() {
      _downloading = true;
      _downloadFailed = false;
    });
    final ok = await ref
        .read(ratesProvider.notifier)
        .downloadYear(key.$1, key.$2, key.$3);
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _downloadFailed = !ok;
    });
  }

  /// The invoice as it is in the form (for the payment dialog).
  Invoice _draft() => Invoice(
    id: widget.invoice?.id,
    direction: _direction,
    number: _number.text.trim(),
    partnerName: _partnerName.text.trim(),
    paymentMethod: _paymentMethod,
    issueDate: _issueDate,
    fulfillmentDate: _fulfillmentDate,
    currency: _currency,
    netAmount: _gross ?? 0,
    vatCode: _vatCode,
  );

  /// A new payment ([index] null) or the one at [index]; the one paid the
  /// whole ([whole]) becomes an ordinary one once edited.
  Future<void> _editPayment({int? index, bool whole = false}) async {
    final gross = _gross;
    final payment = index == null ? null : _payments[index];
    final paidWhole = _paidWhole;
    final result = await showPaymentDialog(
      context,
      invoice: _draft(),
      payment: whole && paidWhole != null
          ? InvoicePayment(
              date: paidWhole.date,
              amount: (gross ?? 0) - _paid,
              method: paidWhole.method,
            )
          : payment,
      // What is open with it.
      max: gross == null ? null : gross - _paid + (payment?.amount ?? 0),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (whole) _paidWhole = null;
      if (index != null) _payments.removeAt(index);
      if (result case PaymentSaved(:final payment)) {
        _payments
          ..add(payment)
          ..sort((a, b) => a.date.compareTo(b.date));
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final net = _currency.parse(_net.text)!;
    final vat = _vatCode.rate == null ? 0 : _currency.parse(_vat.text) ?? 0;
    final state = ref.read(financeProvider);
    final rate = _rate(state);
    if (rate == null) {
      showMessage(context, l10n.exchangeRateInvalid);
      return;
    }
    final rest = net + vat - _paid;
    final payments = [
      ..._payments,
      if (_paidWhole case final whole? when rest != 0)
        InvoicePayment(date: whole.date, amount: rest, method: whole.method),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final invoice = Invoice(
      id: widget.invoice?.id,
      direction: _direction,
      number: _number.text.trim(),
      description: _description.text.trim(),
      partnerName: _partnerName.text.trim(),
      partnerTaxNumber: _location == PartnerLocation.domestic
          ? parseTaxNumber(_partnerTaxNumber.text) ??
                _partnerTaxNumber.text.trim()
          : _partnerTaxNumber.text.trim().toUpperCase(),
      partnerLocation: _location,
      paymentMethod: _paymentMethod,
      issueDate: _issueDate,
      fulfillmentDate: _fulfillmentDate,
      dueDate: _dueDate,
      currency: _currency,
      exchangeRate: rate,
      netAmount: net,
      vatCode: _vatCode,
      vatAmount: vat,
      payments: payments,
      paidAccountId: payments.isEmpty ? null : _paidAccountId,
      paidExchangeRate: payments.isEmpty || _currency == Currency.huf
          ? null
          : _parseRate(_paidRate.text),
      categoryId: _categoryId,
    );
    try {
      checkPayments(invoice);
    } on StateError {
      showMessage(context, l10n.paymentsTooMuch);
      return;
    }
    setState(() => _saving = true);
    final ok = await ref.read(financeProvider.notifier).saveInvoice(invoice);
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
    if (!await showConfirmDialog(context, l10n.deleteInvoiceConfirm)) return;
    final ok = await ref
        .read(financeProvider.notifier)
        .deleteInvoice(widget.invoice!);
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
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final gross = _gross;
    final hasRate = _vatCode.rate != null;
    final state = ref.watch(financeProvider);
    final profile = state.profile;
    // The VAT date matters for the VAT return.
    final vatRelevant =
        profile != null &&
        (profile.vatStatus == VatStatus.registered || profile.euReporting);
    final foreign = _currency != Currency.huf;
    // An invoices only user's invoice isn't booked, and is an outgoing one
    // unless they have incoming invoices.
    final invoicesOnly = profile?.invoicesOnly ?? false;
    final bothDirections =
        (profile?.incomingInvoices ?? true) ||
        _direction == InvoiceDirection.incoming;
    // The MNB's / ECB's rate of the day, downloaded if missing.
    final official = _official(state);
    if (official && _officialRate(state) == null && !_downloading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _downloadRates(ref.read(financeProvider));
      });
    }
    final paidDates = [for (final p in _payments) p.date, ?_paidWhole?.date]
      ..sort();

    String? amountValidator(String? text, {bool required = true}) {
      final value = text?.trim() ?? '';
      if (value.isEmpty) return required ? l10n.amountRequired : null;
      return _currency.parse(value) == null ? l10n.initialBalanceInvalid : null;
    }

    return Scaffold(
      drawer: mainDrawer(
        context,
        invoicesOnly ? MainDestination.invoices : MainDestination.business,
      ),
      appBar: AppBar(
        leading: backButton(context),
        title: Text(_isNew ? l10n.addInvoice : l10n.editInvoice),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: l10n.delete,
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: MaxWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (bothDirections) ...[
                SegmentedButton<InvoiceDirection>(
                  segments: [
                    for (final direction in InvoiceDirection.values)
                      ButtonSegment(
                        value: direction,
                        label: Text(l10n.invoiceDirectionName(direction)),
                      ),
                  ],
                  selected: {_direction},
                  onSelectionChanged: (value) => setState(() {
                    _direction = value.first;
                    _checkCode();
                    _checkBooking();
                  }),
                ),
                const SizedBox(height: 16),
              ],
              ResponsiveRow(
                children: [
                  TextFormField(
                    controller: _number,
                    decoration: InputDecoration(labelText: l10n.invoiceNumber),
                    textInputAction: TextInputAction.next,
                    validator: (text) => (text ?? '').trim().isEmpty
                        ? l10n.invoiceNumberRequired
                        : null,
                  ),
                  DropdownButtonFormField<PaymentMethod>(
                    initialValue: _paymentMethod,
                    decoration: InputDecoration(labelText: l10n.paymentMethod),
                    items: [
                      for (final method in PaymentMethod.values)
                        DropdownMenuItem(
                          value: method,
                          child: Text(l10n.paymentMethodName(method)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _paymentMethod = value!),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(labelText: l10n.invoiceDescription),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),
              Text(l10n.partner, style: titleStyle),
              const SizedBox(height: 8),
              SegmentedButton<PartnerLocation>(
                segments: [
                  for (final location in PartnerLocation.values)
                    ButtonSegment(
                      value: location,
                      label: Text(l10n.partnerLocationName(location)),
                    ),
                ],
                selected: {_location},
                onSelectionChanged: (value) => setState(() {
                  _location = value.first;
                  _checkCode();
                }),
              ),
              const SizedBox(height: 16),
              ResponsiveRow(
                children: [
                  TextFormField(
                    controller: _partnerName,
                    decoration: InputDecoration(labelText: l10n.partnerName),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                  TextFormField(
                    // Another field for another location: other format.
                    key: ValueKey(_location),
                    controller: _partnerTaxNumber,
                    decoration: InputDecoration(
                      labelText: _location == PartnerLocation.domestic
                          ? l10n.taxNumber
                          : _location == PartnerLocation.eu
                          ? l10n.euVatNumber
                          : l10n.foreignTaxNumber,
                      hintText: switch (_location) {
                        PartnerLocation.domestic => '12345678-1-12',
                        PartnerLocation.eu => 'DE123456789',
                        PartnerLocation.thirdCountry => null,
                      },
                    ),
                    keyboardType: _location == PartnerLocation.domestic
                        ? TextInputType.number
                        : TextInputType.text,
                    inputFormatters: _location == PartnerLocation.domestic
                        ? const [TaxNumberInputFormatter()]
                        : null,
                    textCapitalization: TextCapitalization.characters,
                    autovalidateMode: AutovalidateMode.onUserInteractionIfError,
                    validator: (text) {
                      final value = text?.trim() ?? '';
                      if (value.isEmpty) return null;
                      return switch (_location) {
                        PartnerLocation.domestic =>
                          parseTaxNumber(value) == null
                              ? l10n.taxNumberInvalid
                              : null,
                        PartnerLocation.eu =>
                          RegExp(r'^[A-Z]{2}[0-9A-Z]{2,13}$').hasMatch(
                                value.toUpperCase().replaceAll(' ', ''),
                              )
                              ? null
                              : l10n.partnerEuVatNumberInvalid,
                        PartnerLocation.thirdCountry => null,
                      };
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(l10n.dates, style: titleStyle),
              const SizedBox(height: 8),
              ResponsiveRow(
                children: [
                  DateField(
                    label: l10n.issueDate,
                    value: _issueDate,
                    onChanged: (date) => setState(() => _issueDate = date!),
                  ),
                  DateField(
                    label: l10n.fulfillmentDate,
                    value: _fulfillmentDate,
                    onChanged: (date) =>
                        setState(() => _fulfillmentDate = date!),
                  ),
                  DateField(
                    label: l10n.dueDate,
                    value: _dueDate,
                    optional: true,
                    onChanged: (date) => setState(() => _dueDate = date),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(l10n.amount, style: titleStyle),
              const SizedBox(height: 8),
              ResponsiveRow(
                children: [
                  DropdownButtonFormField<Currency>(
                    isExpanded: true,
                    initialValue: _currency,
                    decoration: InputDecoration(labelText: l10n.currency),
                    items: [
                      for (final currency in Currency.values)
                        DropdownMenuItem(
                          value: currency,
                          child: Text(
                            l10n.currencyLabel(currency),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _currency = value!;
                      _updateVat();
                      _checkBooking();
                    }),
                  ),
                  if (foreign && official)
                    _OfficialRate(
                      currency: _currency,
                      quote: _officialRate(state),
                      source: state.rateSource,
                      rateDate: _rateDate,
                      ofIssue: _issueDate.isBefore(_fulfillmentDate),
                      downloading: _downloading,
                      failed: _downloadFailed,
                      onDownload: () => _downloadRates(state, again: true),
                    )
                  else if (foreign)
                    TextFormField(
                      controller: _exchangeRate,
                      decoration: InputDecoration(
                        labelText: l10n.exchangeRate,
                        // The own bank's rate of the day.
                        helperText: l10n.invoiceRateHelper(
                          _currency.code,
                          profile?.isSoleProprietor ?? false
                              ? l10n.rateSourceOwnBank
                              : l10n.rateManual,
                          DateFormat.yMMMd(context.localeName)
                              .format(_rateDate),
                          _issueDate.isBefore(_fulfillmentDate)
                              ? l10n.rateDayIssue
                              : l10n.rateDayFulfillment,
                        ),
                        helperMaxLines: 2,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (text) => _parseRate(text ?? '') == null
                          ? l10n.exchangeRateInvalid
                          : null,
                      onChanged: (_) => setState(() {}),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<VatCode>(
                // New choices for another direction or location.
                key: ValueKey((_direction, _location)),
                initialValue: _vatCode,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.vatCode),
                items: [
                  for (final code in VatCode.available(_direction, _location))
                    DropdownMenuItem(
                      value: code,
                      child: Text(
                        l10n.vatCodeName(code),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _vatCode = value!;
                  _updateVat();
                }),
              ),
              const SizedBox(height: 16),
              ResponsiveRow(
                children: [
                  TextFormField(
                    controller: _net,
                    decoration: InputDecoration(
                      labelText: l10n.netAmount,
                      suffixText: _currency.symbol,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: amountValidator,
                    onChanged: (_) => setState(_updateVat),
                  ),
                  if (hasRate)
                    TextFormField(
                      controller: _vat,
                      decoration: InputDecoration(
                        labelText: l10n.vatAmount,
                        suffixText: _currency.symbol,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (text) =>
                          amountValidator(text, required: false),
                      onChanged: (_) => setState(() {}),
                    ),
                ],
              ),
              if (_vatCode.reverseCharge &&
                  _direction == InvoiceDirection.incoming) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.reverseChargeText(VatCode.reverseChargeRate),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (gross != null) ...[
                const SizedBox(height: 12),
                _GrossLine(
                  gross: gross,
                  currency: _currency,
                  rate: foreign ? _rate(state) : null,
                ),
              ],
              const SizedBox(height: 16),
              _Payments(
                payments: _payments,
                paidWhole: _paidWhole,
                gross: gross,
                currency: _currency,
                outgoing: _direction == InvoiceDirection.outgoing,
                onAdd: () => _editPayment(),
                onEdit: (index) => _editPayment(index: index),
                onEditWhole: () => _editPayment(whole: true),
                booking: invoicesOnly || paidDates.isEmpty
                    ? null
                    : _Booking(
                        accounts: _accounts(state),
                        categories: _categories(state),
                        accountId: _paidAccountId,
                        categoryId: _categoryId,
                        currency: _currency,
                        rate: _paidRate,
                        rateHint: _exchangeRate.text,
                        onAccountChanged: (id) =>
                            setState(() => _paidAccountId = id),
                        onCategoryChanged: (id) =>
                            setState(() => _categoryId = id),
                      ),
              ),
              if (vatRelevant && _direction == InvoiceDirection.outgoing) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.vatDateLine(
                    DateFormat.yMMMd(context.localeName).format(
                      Invoice.vatDateOf(
                        _direction,
                        _fulfillmentDate,
                        paidDates.lastOrNull,
                      ),
                    ),
                    Invoice.vatDateDays,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
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

/// The gross amount, and in forints for another currency.
class _GrossLine extends StatelessWidget {
  const _GrossLine({required this.gross, required this.currency, this.rate});

  final int gross;
  final Currency currency;

  /// The exchange rate of another currency, if it is valid.
  final int? rate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final rate = this.rate;
    final huf = rate == null ? null : Invoice.convert(gross, currency, rate);
    // Wraps on a narrow phone with a big amount.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${l10n.grossAmount}: ', style: textTheme.bodyLarge),
        Text(
          currency.format(gross, locale),
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (huf != null) ...[
          const SizedBox(width: 8),
          Text(
            '(${Currency.huf.format(huf, locale)})',
            style: textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

/// Where a payment is booked: the account and category of the entry, and
/// for another currency the payment's exchange rate.
class _Booking extends StatelessWidget {
  const _Booking({
    required this.accounts,
    required this.categories,
    required this.accountId,
    required this.categoryId,
    required this.currency,
    required this.rate,
    required this.rateHint,
    required this.onAccountChanged,
    required this.onCategoryChanged,
  });

  final List<Account> accounts;
  final List<EntryCategory> categories;
  final int? accountId;
  final int? categoryId;
  final Currency currency;
  final TextEditingController rate;

  /// The invoice's own rate, used if [rate] is empty.
  final String rateHint;
  final ValueChanged<int?> onAccountChanged;
  final ValueChanged<int?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text(l10n.bookingText, style: Theme.of(context).textTheme.bodySmall),
        ResponsiveRow(
          children: [
            DropdownButtonFormField<int?>(
              key: ValueKey(('account', currency, accountId)),
              initialValue: accounts.any((a) => a.id == accountId)
                  ? accountId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.bookedOn),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.notBooked)),
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      '${account.name} (${account.currency.code})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onAccountChanged,
            ),
            DropdownButtonFormField<int?>(
              key: ValueKey(('category', categoryId, categories.length)),
              initialValue: categories.any((c) => c.id == categoryId)
                  ? categoryId
                  : null,
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
              onChanged: onCategoryChanged,
            ),
          ],
        ),
        if (currency != Currency.huf)
          TextFormField(
            controller: rate,
            decoration: InputDecoration(
              labelText: l10n.paidExchangeRate,
              hintText: rateHint,
              helperText: l10n.paidExchangeRateHelper,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (text) {
              final value = text?.trim() ?? '';
              if (value.isEmpty) return null;
              return parseExchangeRate(value) == null
                  ? l10n.exchangeRateInvalid
                  : null;
            },
          ),
      ],
    );
  }
}

/// The MNB's / ECB's rate of the rate date, shown (not typed in): where it
/// came from and its day; without it, downloading it or a button to.
class _OfficialRate extends StatelessWidget {
  const _OfficialRate({
    required this.currency,
    required this.quote,
    required this.source,
    required this.rateDate,
    required this.ofIssue,
    required this.downloading,
    required this.failed,
    required this.onDownload,
  });

  final Currency currency;
  final RateQuote? quote;
  final RateSource source;
  final DateTime rateDate;

  /// The rate date is the issue's (before the fulfillment).
  final bool ofIssue;
  final bool downloading;
  final bool failed;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final quote = this.quote;
    final date = DateFormat.yMMMd(locale);
    final sourceName = l10n.rateSourceName(source);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.exchangeRate,
        helperText: quote != null
            ? l10n.invoiceRateHelper(
                currency.code,
                sourceName,
                date.format(quote.date),
                ofIssue ? l10n.rateDayIssue : l10n.rateDayFulfillment,
              )
            : downloading
            ? l10n.downloadingRates
            : null,
        helperMaxLines: 2,
        errorText: quote != null || downloading
            ? null
            : failed
            ? l10n.rateDownloadFailed
            : l10n.noOfficialRate(sourceName, date.format(rateDate)),
        errorMaxLines: 2,
        suffixIcon: downloading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : quote == null
            ? IconButton(
                tooltip: l10n.updateRates,
                onPressed: onDownload,
                icon: const Icon(Icons.download),
              )
            : null,
      ),
      child: Text(
        quote == null
            ? '–'
            : exchangeRateText((quote.rate * Invoice.rateScale).round()),
      ),
    );
  }
}

/// The payments of the invoice, each opens its dialog; [paidWhole] is one
/// of the whole amount (recorded with the invoice); what is paid of the
/// gross and what is open; the booking (account, category) below.
class _Payments extends StatelessWidget {
  const _Payments({
    required this.payments,
    required this.paidWhole,
    required this.gross,
    required this.currency,
    required this.outgoing,
    required this.onAdd,
    required this.onEdit,
    required this.onEditWhole,
    required this.booking,
  });

  final List<InvoicePayment> payments;
  final PaidInvoice? paidWhole;
  final int? gross;
  final Currency currency;
  final bool outgoing;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final VoidCallback onEditWhole;
  final Widget? booking;

  static IconData _icon(PaymentMethod method) => switch (method) {
    PaymentMethod.transfer => Icons.account_balance_outlined,
    PaymentMethod.cash => Icons.payments_outlined,
    PaymentMethod.card => Icons.credit_card,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final date = DateFormat.yMMMd(locale);
    final gross = this.gross;
    final whole = paidWhole;
    final parts = payments.fold<int>(0, (sum, p) => sum + p.amount);
    // The one of the whole amount pays the rest.
    final paid = whole != null && gross != null ? gross : parts;
    final open = gross == null ? null : gross - paid;
    String line(PaymentMethod method, DateTime day, String note) => [
      date.format(day),
      l10n.paymentMethodName(method),
      if (note.isNotEmpty) note,
    ].join(' · ');
    final booking = this.booking;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(l10n.payments, style: textTheme.titleMedium),
            trailing: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l10n.addPayment),
            ),
          ),
          // Across the whole width: not squeezed beside the button.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              outgoing ? l10n.paidRevenueText : l10n.paidCostText,
              style: textTheme.bodySmall,
            ),
          ),
          if (payments.isEmpty && whole == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(l10n.noPayments, style: textTheme.bodySmall),
            ),
          for (final (i, payment) in payments.indexed)
            ListTile(
              dense: true,
              leading: Icon(_icon(payment.method)),
              title: Text(line(payment.method, payment.date, payment.note)),
              trailing: Text(
                currency.format(payment.amount, locale),
                style: textTheme.bodyLarge,
              ),
              onTap: () => onEdit(i),
            ),
          if (whole != null)
            ListTile(
              dense: true,
              leading: Icon(_icon(whole.method)),
              title: Text(line(whole.method, whole.date, '')),
              subtitle: Text(l10n.wholeAmount),
              trailing: Text(
                gross == null ? '' : currency.format(gross - parts, locale),
                style: textTheme.bodyLarge,
              ),
              onTap: onEditWhole,
            ),
          if (gross != null && (payments.isNotEmpty || whole != null))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Icon(
                    open == 0 ? Icons.check_circle : Icons.schedule,
                    size: 16,
                    color: open == 0 ? incomeColor : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      open == 0
                          ? l10n.paid
                          : '${l10n.paidOfGross(currency.format(paid, locale), currency.format(gross, locale))} · ${l10n.openAmount(currency.format(open!, locale))}',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (booking != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: booking,
            ),
        ],
      ),
    );
  }
}
