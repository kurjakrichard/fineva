import 'dart:typed_data';

import '../../utils/utils.dart';
import '../models/models.dart';

/// Everything the app reads and writes. Saving a model without id inserts
/// it, with id updates it. Accounts, categories and entries belong to one
/// user: they are read by the user's id.
// A user's rows are only changed and deleted as theirs: an account,
// category, invoice or asset by its `userId`, an entry and a transfer by the
// user given; another user's makes a StateError.
abstract class FinanceRepository {
  /// Every user, in the order they were added. Empty until the first
  /// onboarding is finished.
  Future<List<Profile>> getProfiles();

  /// A new user gets the built-in categories.
  Future<int> saveProfile(Profile profile);

  /// The user's accounts, entries and categories go with it.
  Future<void> deleteProfile(Profile profile);

  Future<List<Account>> getAccounts(int userId);
  Future<int> saveAccount(Account account);
  Future<void> deleteAccount(Account account);

  /// Balance of every account of the user by id.
  Future<Map<int, int>> getAccountBalances(int userId);
  Future<int> getEntryCount(Account account);

  Future<List<EntryCategory>> getCategories(int userId);
  Future<int> saveCategory(EntryCategory category);
  Future<void> deleteCategory(EntryCategory category);

  /// Every entry of the user's accounts, the newest first.
  Future<List<Entry>> getEntries(int userId);

  /// An entry of the user with [userId]: on their account, in their
  /// category; a saved one only if theirs (a StateError otherwise).
  Future<int> saveEntry(Entry entry, int userId);

  /// Saves a transfer (a new one without [id]) of the current user as its
  /// sides [from] and [to]; returns its id.
  Future<int> saveTransfer(int? id, int userId, Entry from, Entry to);

  /// Deletes a transfer of the user with [userId], both its sides.
  Future<void> deleteTransfer(int id, int userId);

  /// Updates saved [entries] at once; returns how many.
  Future<int> updateEntries(List<Entry> entries);
  Future<void> deleteEntry(Entry entry, int userId);

  /// The user's invoices, the newest (by fulfillment) first.
  /// With their payments.
  Future<List<Invoice>> getInvoices(int userId);

  /// With the [entries] booking its payment (see `invoiceEntries`), in
  /// place of those booked before.
  Future<int> saveInvoice(Invoice invoice, List<Entry> entries);

  /// Several in one transaction (a payment moved from one to another).
  Future<List<int>> saveInvoices(List<(Invoice, List<Entry>)> invoices);
  Future<void> deleteInvoice(Invoice invoice);

  /// The user's assets, the newest first.
  Future<List<Asset>> getAssets(int userId);
  Future<int> saveAsset(Asset asset);
  Future<void> deleteAsset(Asset asset);

  /// Adds the categories of itemized taxation the user doesn't have yet.
  Future<void> addBusinessCategories(int userId);

  /// Every exchange rate (shared by the users).
  Future<List<ExchangeRate>> getRates();

  /// Saves [rates]; one of the same source, currency, base and day is
  /// replaced. Returns how many.
  Future<int> saveRates(List<ExchangeRate> rates);
  Future<void> deleteRate(ExchangeRate rate);

  /// The last day with a rate of [source], by currency.
  Future<Map<Currency, DateTime>> lastRateDays(RateSource source);
  Future<Map<Currency, DateTime>> firstRateDays(RateSource source);

  /// The currencies every user needs rates for, and the first day of an
  /// entry or invoice.
  Future<({Set<Currency> currencies, DateTime? firstDay})> rateNeeds();

  /// The whole database (every user) as the bytes of a file.
  Future<Uint8List> backup();

  /// Replaces the whole database with a [backup]; throws a BackupException
  /// if it can't.
  Future<void> restore(Uint8List bytes);
}
