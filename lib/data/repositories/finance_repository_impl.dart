import 'dart:typed_data';

import '../built_in_categories.dart';
import '../datasource/finance_datasource.dart';
import '../../utils/utils.dart';
import '../models/models.dart';
import 'finance_repository.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  FinanceRepositoryImpl(this._datasource);

  final FinanceDatasource _datasource;

  // Insert without id, update with id. Returns the row's id.
  /// Inserts [item] without id, or updates it if it is of [userId].
  Future<int> _save(String table, DbModel item, int? userId) async {
    final id = item.id;
    if (id == null) return _datasource.insert(table, item);
    await _datasource.update(table, item, userId: userId);
    return id;
  }

  static const String _byUser = 'user_id = ?';

  @override
  Future<List<Profile>> getProfiles() =>
      _datasource.getAll(Profile.table, Profile.fromMap, orderBy: 'id');

  @override
  Future<int> saveProfile(Profile profile) async {
    final id = profile.id;
    if (id == null) return _datasource.insertProfile(profile);
    await _datasource.update(Profile.table, profile);
    return id;
  }

  /// Its accounts (and their entries) and categories go with it (ON DELETE
  /// CASCADE).
  @override
  Future<void> deleteProfile(Profile profile) =>
      _datasource.delete(Profile.table, profile.id!);

  @override
  Future<List<Account>> getAccounts(int userId) => _datasource.getAll(
    Account.table,
    Account.fromMap,
    where: _byUser,
    whereArgs: [userId],
    orderBy: 'name',
  );

  @override
  Future<int> saveAccount(Account account) =>
      _save(Account.table, account, account.userId);

  /// Its entries go with it (ON DELETE CASCADE).
  @override
  Future<void> deleteAccount(Account account) =>
      _datasource.delete(Account.table, account.id!, userId: account.userId);

  @override
  Future<Map<int, int>> getAccountBalances(int userId) =>
      _datasource.accountBalances(userId);

  @override
  Future<int> getEntryCount(Account account) =>
      _datasource.entryCount(account.id!);

  @override
  Future<List<EntryCategory>> getCategories(int userId) => _datasource.getAll(
    EntryCategory.table,
    EntryCategory.fromMap,
    where: _byUser,
    whereArgs: [userId],
    orderBy: 'type, id',
  );

  @override
  Future<int> saveCategory(EntryCategory category) =>
      _save(EntryCategory.table, category, category.userId);

  /// Its entries stay, without category (ON DELETE SET NULL).
  @override
  Future<void> deleteCategory(EntryCategory category) => _datasource.delete(
    EntryCategory.table,
    category.id!,
    userId: category.userId,
  );

  @override
  Future<List<Entry>> getEntries(int userId) => _datasource.getAll(
    Entry.table,
    Entry.fromMap,
    where: 'account_id IN (SELECT id FROM ${Account.table} WHERE user_id = ?)',
    whereArgs: [userId],
    // The opening entry the oldest of its day.
    orderBy: 'date DESC, opening ASC, id DESC',
  );

  @override
  Future<int> saveEntry(Entry entry, int userId) =>
      _datasource.saveEntry(entry, userId);

  @override
  Future<int> saveTransfer(int? id, int userId, Entry from, Entry to) =>
      _datasource.saveTransfer(id, userId, from, to);

  @override
  Future<void> deleteTransfer(int id, int userId) =>
      _datasource.deleteTransfer(id, userId);

  @override
  Future<int> updateEntries(List<Entry> entries) =>
      _datasource.updateAll(Entry.table, entries);

  @override
  Future<void> deleteEntry(Entry entry, int userId) =>
      _datasource.deleteEntry(entry.id!, userId);

  @override
  Future<List<Invoice>> getInvoices(int userId) async {
    final (invoices, payments) = await (
      _datasource.getAll(
        Invoice.table,
        Invoice.fromMap,
        where: _byUser,
        whereArgs: [userId],
        orderBy: 'fulfillment_date DESC, id DESC',
      ),
      _datasource.getPayments(userId),
    ).wait;
    final byInvoice = <int, List<InvoicePayment>>{};
    for (final payment in payments) {
      (byInvoice[payment.invoiceId!] ??= []).add(payment);
    }
    return [
      for (final invoice in invoices)
        invoice.copyWith(payments: byInvoice[invoice.id] ?? const []),
    ];
  }

  @override
  Future<int> saveInvoice(Invoice invoice, List<Entry> entries) =>
      _datasource.saveInvoice(invoice, entries);

  @override
  Future<List<int>> saveInvoices(List<(Invoice, List<Entry>)> invoices) =>
      _datasource.saveInvoices(invoices);

  /// Its booked entries go with it (ON DELETE CASCADE).
  @override
  Future<void> deleteInvoice(Invoice invoice) =>
      _datasource.deleteInvoice(invoice.id!, invoice.userId!);

  @override
  Future<List<Asset>> getAssets(int userId) => _datasource.getAll(
    Asset.table,
    Asset.fromMap,
    where: _byUser,
    whereArgs: [userId],
    orderBy: 'purchase_date DESC, id DESC',
  );

  @override
  Future<int> saveAsset(Asset asset) => _save(Asset.table, asset, asset.userId);

  @override
  Future<void> deleteAsset(Asset asset) =>
      _datasource.delete(Asset.table, asset.id!, userId: asset.userId);

  @override
  Future<List<ExchangeRate>> getRates() =>
      _datasource.getAll(ExchangeRate.table, ExchangeRate.fromMap);

  @override
  Future<int> saveRates(List<ExchangeRate> rates) =>
      _datasource.saveRates(rates);

  @override
  Future<void> deleteRate(ExchangeRate rate) =>
      _datasource.delete(ExchangeRate.table, rate.id!);

  @override
  Future<Map<Currency, DateTime>> lastRateDays(RateSource source) =>
      _datasource.lastRateDays(source);

  @override
  Future<Map<Currency, DateTime>> firstRateDays(RateSource source) =>
      _datasource.firstRateDays(source);

  @override
  Future<({Set<Currency> currencies, DateTime? firstDay})> rateNeeds() =>
      _datasource.rateNeeds();

  @override
  Future<void> addBusinessCategories(int userId) =>
      _datasource.addBuiltIns(userId, BuiltInSet.itemized);

  @override
  Future<Uint8List> backup() => _datasource.backup();

  @override
  Future<void> restore(Uint8List bytes) => _datasource.restore(bytes);
}
