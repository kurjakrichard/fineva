import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'amount_text.dart';
import 'category_avatar.dart';

/// The query parameter (=1) of the entry route that opens an entry right to
/// editing, not to looking at it.
const String editEntryParameter = 'edit';

/// The query parameter (=1) of the entry route that gives a new opening
/// entry on the account passed as `extra`.
const String openingEntryParameter = 'opening';

/// The page of a new opening entry ([Entry.opening]) on [account].
void openNewOpening(BuildContext context, Account account) =>
    context.pushNamed<Entry>(
      Routes.entry.name,
      extra: account,
      queryParameters: const {openingEntryParameter: '1'},
    );

/// Opens [entry] to look at it, or with [edit] to edit it; an entry
/// booking an invoice's payment is edited on the invoice, a transfer's side
/// opens the transfer.
void openEntry(
  BuildContext context,
  FinanceState state,
  Entry entry, {
  bool edit = false,
}) {
  if (entry.transferId case final transferId?) {
    context.pushNamed<void>(
      Routes.transfer.name,
      extra: transferId,
      queryParameters: edit ? const {editEntryParameter: '1'} : const {},
    );
    return;
  }
  final invoiceId = entry.invoiceId;
  final invoice = !edit || invoiceId == null
      ? null
      : state.invoices.where((i) => i.id == invoiceId).firstOrNull;
  if (invoice != null) {
    context.pushNamed<Invoice>(Routes.invoice.name, extra: invoice);
  } else {
    context.pushNamed<Entry>(
      Routes.entry.name,
      extra: entry,
      queryParameters: edit ? const {editEntryParameter: '1'} : const {},
    );
  }
}

/// One entry in a list: category, date, account, note and amount, and an
/// edit button if [onEdit] is given (see [openEntry]). An account's page leaves out the date (its day is
/// above) and the account.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.account,
    this.category,
    this.onTap,
    this.onEdit,
    this.showDate = true,
    this.showAccount = true,
    this.transferPeer,
  });

  final Entry entry;
  final Account account;
  final EntryCategory? category;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool showDate;
  final bool showAccount;

  /// The account at the other side of a transfer ([FinanceState
  /// .transferPeer]).
  final Account? transferPeer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final category = this.category;
    final peer = transferPeer;
    final details = [
      // Where it went, or came from.
      if (entry.isTransfer && peer != null)
        entry.type == EntryType.expense
            ? l10n.transferToAccount(peer.name)
            : l10n.transferFromAccount(peer.name),
      if (showDate) DateFormat.yMMMd(context.localeName).format(entry.date),
      if (showAccount) account.name,
      if (entry.note.isNotEmpty) entry.note,
    ];
    final onEdit = this.onEdit;
    final amount = AmountText(
      entry.signedAmount,
      account.currency,
      signed: true,
      style: Theme.of(context).textTheme.bodyLarge,
    );
    return ListTile(
      onTap: onTap,
      contentPadding: onEdit == null
          ? null
          : const EdgeInsetsDirectional.only(start: 16, end: 4),
      leading: CategoryAvatar(
        category: category,
        type: entry.type,
        opening: entry.opening,
        transfer: entry.isTransfer,
      ),
      title: Text(
        entry.isTransfer
            ? l10n.transfer
            : entry.opening
            ? l10n.openingEntry
            : category == null
            ? l10n.noCategory
            : l10n.categoryName(category),
      ),
      subtitle: details.isEmpty
          ? null
          : Text(
              details.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      // ListTile's trailing text style is tiny: same size as the title.
      trailing: onEdit == null
          ? amount
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                amount,
                IconButton(
                  tooltip: l10n.editEntry,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
    );
  }
}
