import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'confirm_dialog.dart';

/// New account (without [account]), with its opening balance as an opening
/// entry, or edit [account], delete it only without entries.
Future<void> showAccountDialog(BuildContext context, {Account? account}) =>
    showDialog(
      context: context,
      builder: (context) => AccountDialog(account: account),
    );

class AccountDialog extends ConsumerStatefulWidget {
  const AccountDialog({super.key, this.account});

  final Account? account;

  @override
  ConsumerState<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _opening;
  DateTime _openingDate = currentDay();
  late final TextEditingController _description;
  late final TextEditingController _bankAccount;
  late final TextEditingController _swift;

  /// The closing day; null while open.
  DateTime? _closedDate;
  late AccountType _type;
  late Currency _currency;
  bool _saving = false;

  bool get _isNew => widget.account == null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _name = TextEditingController(text: account?.name ?? '');
    _type = account?.type ?? AccountType.cash;
    _currency = account?.currency ?? Currency.huf;
    _opening = TextEditingController();
    _description = TextEditingController(text: account?.description ?? '');
    _bankAccount = TextEditingController(text: account?.bankAccount ?? '');
    _swift = TextEditingController(text: account?.swift ?? '');
    _closedDate = account?.closedDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _description.dispose();
    _bankAccount.dispose();
    _swift.dispose();
    super.dispose();
  }

  // Empty: 0
  int? _parseBalance(String text) =>
      text.trim().isEmpty ? 0 : _currency.parse(text);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final bankAccount = _bankAccount.text.trim();
    final swift = _swift.text.trim();
    final account = Account(
      id: widget.account?.id,
      name: _name.text.trim(),
      type: _type,
      currency: _currency,
      description: _description.text.trim(),
      // Checked: the stored form.
      bankAccount: bankAccount.isEmpty ? '' : parseBankAccount(bankAccount)!,
      swift: swift.isEmpty ? '' : parseSwift(swift)!,
      closedDate: _closedDate,
    );
    setState(() => _saving = true);
    final ok = await ref
        .read(financeProvider.notifier)
        .saveAccount(
          account,
          opening: _isNew ? _parseBalance(_opening.text)! : 0,
          openingDate: _openingDate,
        );
    if (!mounted) return;
    if (ok) {
      nav.pop();
    } else {
      setState(() => _saving = false);
      showMessage(context, l10n.saveError);
    }
  }

  Future<void> _delete() async {
    final account = widget.account!;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final notifier = ref.read(financeProvider.notifier);
    final message = l10n.deleteAccountConfirm(account.name, 0);
    if (!await showConfirmDialog(context, message)) return;
    final ok = await notifier.deleteAccount(account);
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
    final account = widget.account;
    // Only an account without entries can be deleted.
    final state = ref.watch(financeProvider);
    final entryCount = account == null ? 0 : state.entryCountOf(account);
    // Closed only with a 0 balance then and no later entries.
    final closedDate = _closedDate;
    final closing = account == null || closedDate == null
        ? null
        : state.closingCheck(account, closedDate);
    final closingProblem = closing == null
        ? null
        : closing.later > 0
        ? l10n.closeAccountLaterEntries(closing.later)
        : closing.balance != 0
        ? l10n.closeAccountBalance(
            account!.currency.format(closing.balance, context.localeName),
          )
        : null;
    return AlertDialog(
      title: Text(_isNew ? l10n.addAccount : l10n.editAccount),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: _isNew,
                decoration: InputDecoration(labelText: l10n.name),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? l10n.nameRequired : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: InputDecoration(labelText: l10n.accountType),
                items: [
                  for (final type in AccountType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(l10n.accountTypeName(type)),
                    ),
                ],
                onChanged: (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 12),
              // Fixed once saved: the entries' amounts are stored in the
              // smallest unit of this currency.
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
                onChanged: _isNew
                    ? (value) => setState(() => _currency = value!)
                    : null,
              ),
              // A new account's opening entry; later it is an entry of
              // the account, changed and deleted there.
              if (_isNew) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _opening,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.initialBalance,
                    helperText: l10n.openingBalanceHelper,
                    helperMaxLines: 2,
                    suffixText: _currency.symbol,
                  ),
                  validator: (value) => _parseBalance(value ?? '') == null
                      ? l10n.initialBalanceInvalid
                      : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _openingDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) setState(() => _openingDate = date);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.openingDate,
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat.yMMMd(context.localeName).format(_openingDate),
                    ),
                  ),
                ),
              ],
              // Optional details; a cash account has no number.
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(labelText: l10n.accountDescription),
              ),
              if (_type != AccountType.cash) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bankAccount,
                  decoration: InputDecoration(
                    labelText: l10n.bankAccountNumber,
                    helperText: l10n.bankAccountNumberHelper,
                    helperMaxLines: 2,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    return text.isEmpty || parseBankAccount(text) != null
                        ? null
                        : l10n.bankAccountNumberInvalid;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _swift,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: l10n.swiftCode),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    return text.isEmpty || parseSwift(text) != null
                        ? null
                        : l10n.swiftCodeInvalid;
                  },
                ),
              ],
              // Closing: the balance must be 0 then, no entries after.
              if (account != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.accountClosed),
                  subtitle: Text(l10n.accountClosedText),
                  value: closedDate != null,
                  onChanged: (closed) => setState(
                    () => _closedDate = closed
                        ? state.lastEntryDay(account) ?? currentDay()
                        : null,
                  ),
                ),
                if (closedDate != null)
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: closedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) setState(() => _closedDate = date);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.closedDate,
                        errorText: closingProblem,
                        errorMaxLines: 3,
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat.yMMMd(context.localeName).format(closedDate),
                      ),
                    ),
                  ),
              ],
              if (!_isNew && entryCount > 0) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.accountHasEntries(entryCount),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_isNew)
          TextButton(
            onPressed: _saving || entryCount > 0 ? null : _delete,
            child: Text(l10n.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving || closingProblem != null ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
