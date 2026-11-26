import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../utils/utils.dart';
import 'confirm_dialog.dart';
import 'date_field.dart';
import 'invoice_tile.dart';

/// What the payment dialog ended with.
sealed class PaymentAction {
  const PaymentAction();
}

/// Saved: the payment (its id kept when it was one saved before), of
/// [invoice] if another one was chosen (it was a payment of the wrong
/// one).
class PaymentSaved extends PaymentAction {
  const PaymentSaved(this.payment, {this.invoice});

  final InvoicePayment payment;
  final Invoice? invoice;
}

/// The payment is to be deleted.
class PaymentDeleted extends PaymentAction {
  const PaymentDeleted();
}

/// Records or edits a [payment] of [invoice] (a new one without it): its
/// day, amount (at most [max], the open amount with it, if not null),
/// method and note. With [invoices], the invoice can be changed to another
/// of them (chosen wrong): the payment goes to it with its day and amount
/// (at most its open amount). Null if cancelled.
Future<PaymentAction?> showPaymentDialog(
  BuildContext context, {
  required Invoice invoice,
  InvoicePayment? payment,
  int? max,
  List<Invoice>? invoices,
}) => showDialog<PaymentAction>(
  context: context,
  builder: (context) => _PaymentDialog(
    invoice: invoice,
    payment: payment,
    max: max,
    invoices: invoices,
  ),
);

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.invoice,
    required this.payment,
    required this.max,
    required this.invoices,
  });

  final Invoice invoice;
  final InvoicePayment? payment;
  final int? max;
  final List<Invoice>? invoices;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  late PaymentMethod _method;

  /// The invoice paid: the one it was opened with, or another chosen.
  late Invoice _invoice = widget.invoice;

  Currency get _currency => _invoice.currency;

  /// What can be paid of [_invoice]: the open amount (with this payment's,
  /// if it is the one it was a payment of).
  int? get _max =>
      _invoice.id == widget.invoice.id ? widget.max : _invoice.openAmount;

  Future<void> _chooseInvoice() async {
    final chosen = await showInvoiceChoice(
      context,
      invoices: widget.invoices!,
      title: context.l10n.chooseInvoice,
      current: _invoice.id,
    );
    if (chosen is Invoice && mounted) setState(() => _invoice = chosen);
  }

  @override
  void initState() {
    super.initState();
    final payment = widget.payment;
    final now = DateTime.now();
    _date = payment?.date ?? DateTime(now.year, now.month, now.day);
    _method = payment?.method ?? widget.invoice.paymentMethod;
    // A new one: what is still open.
    final amount = payment?.amount ?? widget.max;
    _amount = TextEditingController(
      text: amount == null ? '' : _currency.toInput(amount),
    );
    _note = TextEditingController(text: payment?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    if (!await showConfirmDialog(context, context.l10n.deletePaymentConfirm)) {
      return;
    }
    nav.pop(const PaymentDeleted());
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final other = _invoice.id != widget.invoice.id;
    Navigator.of(context).pop(
      PaymentSaved(
        InvoicePayment(
          id: widget.payment?.id,
          invoiceId: _invoice.id,
          date: _date,
          amount: _currency.parse(_amount.text)!,
          method: _method,
          note: _note.text.trim(),
        ),
        invoice: other ? _invoice : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final invoice = _invoice;
    final max = _max;
    final invoices = widget.invoices;
    final line = [
      if (invoice.number.isNotEmpty) invoice.number,
      if (invoice.partnerName.isNotEmpty) invoice.partnerName,
      invoice.currency.format(invoice.gross, locale),
    ].join(' · ');
    return AlertDialog(
      // Deleting beside the title: three buttons don't fit below on a
      // phone.
      title: Row(
        children: [
          Expanded(child: Text(l10n.addPayment)),
          if (widget.payment != null)
            IconButton(
              tooltip: l10n.delete,
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (invoices == null)
              Text(line, style: Theme.of(context).textTheme.bodySmall)
            else
              // Another one if it was chosen wrong.
              InkWell(
                onTap: _chooseInvoice,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.paymentInvoice,
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(line),
                ),
              ),
            const SizedBox(height: 16),
            DateField(
              label: l10n.paidDate,
              value: _date,
              onChanged: (date) => setState(() => _date = date!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              decoration: InputDecoration(
                labelText: l10n.paidAmount,
                suffixText: _currency.symbol,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: (text) {
                final value = _currency.parse(text?.trim() ?? '');
                if (value == null || value == 0) return l10n.amountRequired;
                // Not more than what is open, the same way (a credit
                // note's is negative).
                if (max != null &&
                    (max >= 0 ? value > max || value < 0 : value < max)) {
                  return l10n.paymentAtMost(_currency.format(max, locale));
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: InputDecoration(labelText: l10n.paymentMethod),
              items: [
                for (final method in PaymentMethod.values)
                  DropdownMenuItem(
                    value: method,
                    child: Text(l10n.paymentMethodName(method)),
                  ),
              ],
              onChanged: (value) => setState(() => _method = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.note),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}

/// Popped by [showInvoiceChoice] for a new invoice.
enum NewInvoiceChoice { chosen }

/// Chooses the invoice paid of [invoices] in a sheet: the one popped
/// ([current] marked); with [withNew] also a new invoice
/// ([NewInvoiceChoice.chosen]). Null if closed.
Future<Object?> showInvoiceChoice(
  BuildContext context, {
  required List<Invoice> invoices,
  required String title,
  String? text,
  bool withNew = false,
  int? current,
}) => showModalBottomSheet<Object>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _InvoiceChoiceSheet(
    invoices: invoices,
    title: title,
    text: text,
    withNew: withNew,
    current: current,
  ),
);

class _InvoiceChoiceSheet extends StatelessWidget {
  const _InvoiceChoiceSheet({
    required this.invoices,
    required this.title,
    required this.text,
    required this.withNew,
    required this.current,
  });

  final List<Invoice> invoices;
  final String title;
  final String? text;
  final bool withNew;
  final int? current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(title, style: textTheme.titleLarge),
          ),
          if (text case final text?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(text, style: textTheme.bodyMedium),
            ),
          if (withNew)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      Navigator.of(context).pop(NewInvoiceChoice.chosen),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addInvoice),
                ),
              ),
            ),
          const Divider(),
          if (invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.noOpenInvoices, textAlign: TextAlign.center),
            ),
          for (final invoice in invoices)
            RecordTile(
              onTap: () => Navigator.of(context).pop(invoice),
              leading: CircleAvatar(
                backgroundColor: invoice.id == current
                    ? scheme.primary
                    : scheme.secondaryContainer,
                foregroundColor: invoice.id == current
                    ? scheme.onPrimary
                    : scheme.onSecondaryContainer,
                child: Icon(
                  invoice.id == current
                      ? Icons.check
                      : Icons.request_quote_outlined,
                  size: 20,
                ),
              ),
              title: invoice.partnerName.isEmpty
                  ? invoice.number
                  : invoice.partnerName,
              amount: invoice.currency.format(invoice.openAmount, locale),
              details: [
                if (invoice.partnerName.isNotEmpty) invoice.number,
                DateFormat.yMMMd(locale).format(invoice.fulfillmentDate),
                if (invoice.description.isNotEmpty) invoice.description,
              ].join(' · '),
              footer: Text(
                l10n.paidOfGross(
                  invoice.currency.format(invoice.paidAmount, locale),
                  invoice.currency.format(invoice.gross, locale),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
