import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_export.dart';
import '../../utils/utils.dart';
import '../shared_preferences_provider.dart';
import 'date_period.dart';
import 'finance_state.dart';
import 'rate_book.dart';

/// Loads everything and saves the changes the pages make. After every
/// write the whole state is reloaded, so balances are always right.
///
/// The current user is the one saved in SharedPreferences, or the first
/// one if that is gone.
class FinanceNotifier extends Notifier<FinanceState> {
  FinanceRepository get _repository => ref.read(financeRepositoryProvider);
  SharedUtility get _settings => ref.read(sharedUtilityProvider);

  @override
  FinanceState build() {
    ref.watch(financeRepositoryProvider);
    Future.microtask(load);
    return const FinanceState.initial();
  }

  Future<void> load() async {
    try {
      final profiles = await _repository.getProfiles();
      final savedId = _settings.getCurrentUser();
      final profile =
          profiles.where((p) => p.id == savedId).firstOrNull ??
          profiles.firstOrNull;
      final userId = profile?.id;
      if (userId == null) {
        state = const FinanceState(loaded: true);
        return;
      }
      final rates = RateBook(await _repository.getRates());
      final (
        accounts,
        categories,
        entries,
        balances,
        invoices,
        assets,
      ) = await (
        _repository.getAccounts(userId),
        _repository.getCategories(userId),
        _repository.getEntries(userId),
        _repository.getAccountBalances(userId),
        _repository.getInvoices(userId),
        _repository.getAssets(userId),
      ).wait;
      state = FinanceState(
        profiles: profiles,
        profile: profile,
        accounts: accounts,
        categories: categories,
        entries: entries,
        balances: balances,
        invoices: invoices,
        assets: assets,
        rates: rates,
        loaded: true,
      );
    } catch (e) {
      debugPrint('Loading failed: $e');
      state = state.copyWith(loaded: true, error: e.toString());
    }
  }

  /// Makes [profile] the current user.
  Future<void> selectProfile(Profile profile) async {
    _settings.setCurrentUser(profile.id!);
    await load();
  }

  // Each write returns true on success.

  /// A new user (without id) becomes the current one, as does any with
  /// [select].
  Future<bool> saveProfile(Profile profile, {bool select = false}) =>
      _write(() async {
        final id = await _repository.saveProfile(profile);
        if (select || profile.id == null) _settings.setCurrentUser(id);
        return id;
      });

  /// Deletes the user with their accounts, entries and categories. If it
  /// was the current one, the first other user becomes current.
  Future<bool> deleteProfile(Profile profile) =>
      _write(() => _repository.deleteProfile(profile));

  // Accounts and categories are saved as the current user's.
  /// The current user: every write is theirs only. Another user's account,
  /// category, entry, invoice, asset or transfer is refused (the
  /// repository throws, the write returns false), even if one got here.
  int get _userId => state.profile!.id!;

  /// Saves [account]; a new one gets an opening entry of [opening] (signed,
  /// none for 0) on [openingDate] (today by default). A closed one only if
  /// its balance is 0 on the closing day and it has no entries after it
  /// ([FinanceState.closingCheck]); false otherwise.
  Future<bool> saveAccount(
    Account account, {
    int opening = 0,
    DateTime? openingDate,
  }) => _write(() async {
    // Closed only with a 0 balance then and no later entries.
    final closed = account.closedDate;
    if (closed != null) {
      final check = state.closingCheck(account, closed);
      if (check.balance != 0 || check.later > 0) {
        throw StateError('${account.name} can not be closed on $closed');
      }
    }
    final id = await _repository.saveAccount(account.copyWith(userId: _userId));
    if (account.id != null || opening == 0) return id;
    return _repository.saveEntry(
      Entry(
        accountId: id,
        type: opening > 0 ? EntryType.income : EntryType.expense,
        amount: opening.abs(),
        date: openingDate ?? currentDay(),
        opening: true,
      ),
      _userId,
    );
  });

  /// Deletes [account] if it has no entries (the opening one included);
  /// false otherwise.
  Future<bool> deleteAccount(Account account) => _write(() async {
    if (await _repository.getEntryCount(account) > 0) {
      throw StateError('${account.name} has entries');
    }
    await _repository.deleteAccount(account.copyWith(userId: _userId));
    return null;
  });

  Future<int> entryCount(Account account) => _repository.getEntryCount(account);

  Future<bool> saveCategory(EntryCategory category) => _write(
    () => _repository.saveCategory(category.copyWith(userId: _userId)),
  );

  Future<bool> deleteCategory(EntryCategory category) => _write(
    () => _repository.deleteCategory(category.copyWith(userId: _userId)),
  );

  Future<bool> saveEntry(Entry entry) =>
      _write(() => _repository.saveEntry(entry, _userId));

  Future<bool> deleteEntry(Entry entry) =>
      _write(() => _repository.deleteEntry(entry, _userId));

  /// With its payments, booked as entries (see `invoiceEntries`); an
  /// invoices only user's (`Profile.invoicesOnly`) aren't booked (entries
  /// booked before are deleted). Refused if the payments add up to more
  /// than the invoice (or a payment is 0).
  Future<bool> saveInvoice(Invoice invoice) => _write(() {
    checkPayments(invoice);
    final (saved, entries) = _booked(invoice);
    return _repository.saveInvoice(saved, entries);
  });

  /// [invoice] as the current user's, with the entries booking its
  /// payments (none for an invoices only user, whose isn't booked).
  (Invoice, List<Entry>) _booked(Invoice invoice) {
    final current = state;
    final booked = !current.profile!.invoicesOnly;
    final accountId = booked ? invoice.paidAccountId : null;
    final entries = invoiceEntries(
      invoice,
      account: accountId == null ? null : current.account(accountId),
      category: current.category(invoice.categoryId),
      categories: current.categories,
    );
    return (
      booked
          ? invoice.copyWith(userId: _userId)
          : invoice.copyWith(
              userId: _userId,
              paidAccountId: () => null,
              categoryId: () => null,
            ),
      entries,
    );
  }

  /// Adds [payment] to [invoice]'s payments, or replaces the one with its
  /// id; saved with the invoice ([saveInvoice]). With [from], another
  /// invoice it was a payment of (chosen wrong): moved from that one to
  /// [invoice], keeping its day and amount, both saved at once (refused if
  /// more than [invoice]'s open amount).
  Future<bool> savePayment(
    Invoice invoice,
    InvoicePayment payment, {
    Invoice? from,
  }) {
    final payments = [
      for (final p in invoice.payments)
        if (payment.id == null || p.id != payment.id) p,
      payment.copyWith(invoiceId: invoice.id),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final to = invoice.copyWith(payments: payments);
    if (from == null || from.id == invoice.id) return saveInvoice(to);
    final left = from.copyWith(
      payments: [
        for (final p in from.payments)
          if (p.id != payment.id) p,
      ],
    );
    return _write(() {
      checkPayments(to);
      checkPayments(left);
      // The one it goes to first (see FinanceDatasource.saveInvoices).
      return _repository.saveInvoices([_booked(to), _booked(left)]);
    });
  }

  /// Deletes [payment] of [invoice].
  Future<bool> deletePayment(Invoice invoice, InvoicePayment payment) =>
      saveInvoice(
        invoice.copyWith(
          payments: [
            for (final p in invoice.payments)
              if (p.id != payment.id) p,
          ],
        ),
      );

  Future<bool> deleteInvoice(Invoice invoice) => _write(
    () => _repository.deleteInvoice(invoice.copyWith(userId: _userId)),
  );

  Future<bool> saveAsset(Asset asset) =>
      _write(() => _repository.saveAsset(asset.copyWith(userId: _userId)));

  Future<bool> deleteAsset(Asset asset) =>
      _write(() => _repository.deleteAsset(asset.copyWith(userId: _userId)));

  /// Saves a transfer (a new one without [id]) as its two sides (see
  /// `transferSides`), and [dayRates] as the days' rates.
  Future<bool> saveTransfer(
    int? id,
    Entry from,
    Entry to, {
    List<ExchangeRate> dayRates = const [],
  }) => _write(() async {
    await _repository.saveRates(dayRates);
    return _repository.saveTransfer(id, _userId, from, to);
  });

  /// Deletes a transfer, both its sides.
  Future<bool> deleteTransfer(int id) =>
      _write(() => _repository.deleteTransfer(id, _userId));

  /// A rate typed in; replaces one of the same currency, base and day.
  Future<bool> saveManualRate(ExchangeRate rate) =>
      _write(() => _repository.saveRates([rate]));

  Future<bool> deleteRate(ExchangeRate rate) =>
      _write(() => _repository.deleteRate(rate));

  /// The categories of itemized taxation, for the current user.
  Future<bool> addBusinessCategories() =>
      _write(() => _repository.addBusinessCategories(_userId));

  /// The whole database (every user) as the bytes of a file.
  Future<Uint8List> backup() => _repository.backup();

  /// Replaces every user's data with a [backup], then reloads. Throws a
  /// BackupException (the data stays as it was) or another error.
  Future<void> restore(Uint8List bytes) async {
    try {
      await _repository.restore(bytes);
    } finally {
      await load();
    }
  }

  Future<bool> _write(Future<Object?> Function() write) async {
    var success = true;
    try {
      await write();
    } catch (e) {
      debugPrint('Saving failed: $e');
      success = false;
    }
    await load();
    return success;
  }
}

final financeProvider = NotifierProvider<FinanceNotifier, FinanceState>(
  FinanceNotifier.new,
);

/// A StateError unless [invoice]'s payments are not 0 and add up to at
/// most its gross amount (a credit note's to at least it).
void checkPayments(Invoice invoice) {
  final gross = invoice.gross;
  final paid = invoice.paidAmount;
  final over = gross >= 0 ? paid > gross || paid < 0 : paid < gross || paid > 0;
  if (over || invoice.payments.any((p) => p.amount == 0)) {
    throw StateError('Payments of ${invoice.number}: $paid of $gross');
  }
}
