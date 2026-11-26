import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_export.dart';
import '../utils/utils.dart';
import 'finance/date_period.dart';
import 'finance/finance_notifier.dart';
import 'finance/rate_book.dart';
import 'shared_preferences_provider.dart';

/// What the last download of the exchange rates did.
class RateUpdate extends Equatable {
  const RateUpdate({
    this.running = false,
    this.finished,
    this.saved = 0,
    this.error,
  });

  final bool running;

  /// When the last download finished (null: none yet since the start).
  final DateTime? finished;

  /// How many rates it saved.
  final int saved;

  /// Why it failed (no network, ...); null if it didn't.
  final String? error;

  @override
  List<Object?> get props => [running, finished, saved, error];
}

final rateDownloaderProvider = Provider<RateDownloader>(
  (ref) => RateDownloader(),
);

/// Downloads the exchange rates the users need.
class RatesNotifier extends Notifier<RateUpdate> {
  @override
  RateUpdate build() => const RateUpdate();

  /// Downloads the missing rates of the sources the users chose (in use:
  /// a sole proprietor's only if reported to NAV, see
  /// `Profile.rateSourceInUse`; none for manual) for every currency they
  /// use, from January 1 of the year of the first entry or invoice (this
  /// year without any): the choice is for a whole year, so a user starting
  /// in the year finds them there. For each currency what isn't there yet:
  /// from the day after its last rate, or from that January 1 if its rates
  /// start later. Then reloads the data. [atStart]: only if Settings →
  /// rates at start is on.
  Future<void> update({bool atStart = false}) async {
    if (state.running) return;
    if (atStart && !ref.read(sharedUtilityProvider).getRatesAtStart()) return;
    state = const RateUpdate(running: true);
    try {
      final repository = ref.read(financeRepositoryProvider);
      final sources = {
        for (final profile in await repository.getProfiles())
          if (profile.rateSourceInUse != RateSource.manual)
            profile.rateSourceInUse,
      };
      final needs = await repository.rateNeeds();
      final today = currentDay();
      final start = DateTime((needs.firstDay ?? today).year);
      var saved = 0;
      for (final source in sources) {
        saved += await _download(source, needs.currencies, start);
      }
      final filled = await _fillEntryRates(repository);
      state = RateUpdate(finished: DateTime.now(), saved: saved);
      if (saved > 0 || filled > 0) {
        await ref.read(financeProvider.notifier).load();
      }
    } catch (e) {
      debugPrint('Rate download failed: $e');
      state = RateUpdate(finished: DateTime.now(), error: e.toString());
    }
  }

  /// Downloads the rates of [source] for [currency] from January 1 of
  /// [year] (what isn't there yet), e.g. for an invoice of a currency not
  /// used before; then reloads the data. False if it failed.
  Future<bool> downloadYear(
    RateSource source,
    Currency currency,
    int year,
  ) async {
    if (state.running) return false;
    state = const RateUpdate(running: true);
    try {
      final saved = await _download(source, {currency}, DateTime(year));
      state = RateUpdate(finished: DateTime.now(), saved: saved);
      if (saved > 0) await ref.read(financeProvider.notifier).load();
      return true;
    } catch (e) {
      debugPrint('Rate download failed: $e');
      state = RateUpdate(finished: DateTime.now(), error: e.toString());
      return false;
    }
  }

  /// Downloads what is missing of [source]'s rates of [currencies] from
  /// [start] up to today; returns how many were saved.
  Future<int> _download(
    RateSource source,
    Set<Currency> currencies,
    DateTime start,
  ) async {
    final repository = ref.read(financeRepositoryProvider);
    final wanted = {
      for (final c in currencies)
        if (c != source.pivot) c,
    };
    if (wanted.isEmpty) return 0;
    final today = currentDay();
    final first = await repository.firstRateDays(source);
    final last = await repository.lastRateDays(source);
    // Rates start on the first working day: a week after January 1 is
    // still from it.
    final covered = DateTime(start.year, start.month, start.day + 7);
    var from = today;
    for (final currency in wanted) {
      final firstDay = first[currency];
      final lastDay = last[currency];
      final next =
          firstDay == null || lastDay == null || firstDay.isAfter(covered)
          ? start
          : DateTime(lastDay.year, lastDay.month, lastDay.day + 1);
      if (next.isBefore(from)) from = next;
    }
    if (from.isAfter(today)) return 0;
    final rates = await ref
        .read(rateDownloaderProvider)
        .download(source, wanted, from, today);
    return repository.saveRates(rates);
  }
}

/// Gives the personal users' entries of another currency than their main
/// one that have no rate yet (older data) the downloaded rate of their day,
/// as if offered when they were recorded. An invoice's payment, a sole
/// proprietor's entries (taxes) and the entries of a user who types the
/// rates in are left as they are. Returns how many.
Future<int> _fillEntryRates(FinanceRepository repository) async {
  final book = RateBook(await repository.getRates());
  if (book.isEmpty) return 0;
  var filled = 0;
  for (final profile in await repository.getProfiles()) {
    // Taxes; or typing them in.
    if (profile.isSoleProprietor || profile.rateSource == RateSource.manual) {
      continue;
    }
    final main = profile.mainCurrency;
    final foreign = {
      for (final account in await repository.getAccounts(profile.id!))
        if (account.currency != main) account.id!: account.currency,
    };
    if (foreign.isEmpty) continue;
    final entries = <Entry>[];
    for (final entry in await repository.getEntries(profile.id!)) {
      final currency = foreign[entry.accountId];
      if (currency == null || entry.rate != null || entry.invoiceId != null) {
        continue;
      }
      final rate = book.downloaded(
        currency,
        main,
        entry.date,
        profile.rateSource,
      );
      if (rate != null) entries.add(entry.withRate(rate.rate, rate.source));
    }
    filled += await repository.updateEntries(entries);
  }
  return filled;
}

final ratesProvider = NotifierProvider<RatesNotifier, RateUpdate>(
  RatesNotifier.new,
);

/// Whether the missing rates are downloaded at every start (on by
/// default).
class RatesAtStartNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedUtilityProvider).getRatesAtStart();

  void set(bool value) {
    ref.read(sharedUtilityProvider).setRatesAtStart(value);
    state = value;
  }
}

final ratesAtStartProvider = NotifierProvider<RatesAtStartNotifier, bool>(
  RatesAtStartNotifier.new,
);
