import 'dart:io';

import 'package:fineva/data/data_export.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_database.dart';

ExchangeRate _rate(
  RateSource source,
  DateTime date,
  Currency currency,
  Currency base,
  double rate,
) => ExchangeRate(
  source: source,
  date: date,
  currency: currency,
  base: base,
  rate: rate,
);

void main() {
  group('downloads', () {
    test('the MNB answer: HUF per unit, JPY per 100', () {
      final rates = RateDownloader.parseMnb(
        File('test/fixtures/mnb_rates.xml').readAsStringSync(),
      );
      expect(rates, hasLength(9));
      final eur = rates.firstWhere(
        (r) => r.currency == Currency.eur && r.date == DateTime(2026, 11, 20),
      );
      expect(eur.source, RateSource.mnb);
      expect(eur.base, Currency.huf);
      expect(eur.rate, 373.22);
      final jpy = rates.firstWhere(
        (r) => r.currency == Currency.jpy && r.date == DateTime(2026, 11, 20),
      );
      expect(jpy.rate, closeTo(2.1431, 1e-9));
    });

    test('the ECB answer: units per EUR, kept as the value of a unit', () {
      final rates = RateDownloader.parseEcb(
        File('test/fixtures/ecb_rates.csv').readAsStringSync(),
      );
      expect(rates, hasLength(9));
      final huf = rates.firstWhere(
        (r) => r.currency == Currency.huf && r.date == DateTime(2026, 11, 20),
      );
      expect(huf.source, RateSource.ecb);
      expect(huf.base, Currency.eur);
      expect(1 / huf.rate, closeTo(373.55, 1e-9));
    });

    test('the requests: dates and currency codes only, the pivot left '
        'out', () async {
      final calls = <(Uri, String?)>[];
      final downloader = RateDownloader(
        fetch: (url, {body, headers = const {}}) async {
          calls.add((url, body));
          // The ECB has nothing for a weekend.
          return url.host == 'www.mnb.hu'
              ? File('test/fixtures/mnb_rates.xml').readAsStringSync()
              : null;
        },
      );
      final from = DateTime(2026, 11, 18);
      final to = DateTime(2026, 11, 21);
      final mnb = await downloader.download(
        RateSource.mnb,
        {Currency.huf, Currency.usd, Currency.eur},
        from,
        to,
      );
      expect(mnb, hasLength(9));
      expect(calls.single.$1, RateDownloader.mnbUrl);
      expect(calls.single.$2, contains('<web:currencyNames>EUR,USD<'));
      expect(calls.single.$2, contains('<web:startDate>2026-11-18<'));

      expect(
        await downloader.download(
          RateSource.ecb,
          {Currency.huf, Currency.eur},
          from,
          to,
        ),
        isEmpty,
      );
      expect(
        calls.last.$1.toString(),
        'https://data-api.ecb.europa.eu/service/data/EXR/D.HUF.EUR.SP00.A'
        '?startPeriod=2026-11-18&endPeriod=2026-11-21&format=csvdata',
      );
      // Only the pivot: nothing to ask.
      expect(
        await downloader.download(RateSource.mnb, {Currency.huf}, from, to),
        isEmpty,
      );
      expect(calls, hasLength(2));
    });
  });

  group('RateBook', () {
    final book = RateBook([
      _rate(
        RateSource.mnb,
        DateTime(2026, 11, 18),
        Currency.eur,
        Currency.huf,
        380,
      ),
      _rate(
        RateSource.mnb,
        DateTime(2026, 11, 20),
        Currency.eur,
        Currency.huf,
        390,
      ),
      _rate(
        RateSource.mnb,
        DateTime(2026, 11, 20),
        Currency.usd,
        Currency.huf,
        300,
      ),
      // 1 EUR = 400 HUF, 1 EUR = 1.25 USD.
      _rate(
        RateSource.ecb,
        DateTime(2026, 11, 20),
        Currency.huf,
        Currency.eur,
        1 / 400,
      ),
      _rate(
        RateSource.ecb,
        DateTime(2026, 11, 20),
        Currency.usd,
        Currency.eur,
        1 / 1.25,
      ),
      _rate(
        RateSource.manual,
        DateTime(2026, 11, 19),
        Currency.eur,
        Currency.huf,
        385,
      ),
      _rate(
        RateSource.manual,
        DateTime(2026, 11, 10),
        Currency.huf,
        Currency.gbp,
        0.002,
      ),
    ]);

    double? rate(
      Currency from,
      Currency to,
      DateTime date,
      RateSource source,
    ) => book.quote(from, to, date, source)?.rate;

    test('the last rate on or before the day; the first one before them', () {
      // Weekend: Friday's.
      expect(
        rate(
          Currency.eur,
          Currency.huf,
          DateTime(2026, 11, 22),
          RateSource.mnb,
        ),
        390,
      );
      expect(
        rate(
          Currency.eur,
          Currency.huf,
          DateTime(2026, 11, 18),
          RateSource.mnb,
        ),
        380,
      );
      expect(
        rate(Currency.eur, Currency.huf, DateTime(2026, 1, 1), RateSource.mnb),
        380,
      );
      expect(
        rate(Currency.huf, Currency.huf, DateTime(2026), RateSource.mnb),
        1,
      );
    });

    test('both ways, and across the pivot', () {
      expect(
        rate(
          Currency.huf,
          Currency.eur,
          DateTime(2026, 11, 20),
          RateSource.mnb,
        ),
        1 / 390,
      );
      // USD -> EUR by the MNB: 300 / 390.
      expect(
        rate(
          Currency.usd,
          Currency.eur,
          DateTime(2026, 11, 20),
          RateSource.mnb,
        ),
        closeTo(300 / 390, 1e-12),
      );
      // EUR -> HUF and USD -> HUF by the ECB.
      expect(
        rate(
          Currency.eur,
          Currency.huf,
          DateTime(2026, 11, 20),
          RateSource.ecb,
        ),
        closeTo(400, 1e-9),
      );
      expect(
        rate(
          Currency.usd,
          Currency.huf,
          DateTime(2026, 11, 20),
          RateSource.ecb,
        ),
        closeTo(320, 1e-9),
      );
    });

    test('a manual rate goes before a downloaded one of its day or '
        'before', () {
      final manual = book.quote(
        Currency.eur,
        Currency.huf,
        DateTime(2026, 11, 19),
        RateSource.mnb,
      )!;
      expect(manual.rate, 385);
      expect(manual.source, RateSource.manual);
      // A newer downloaded one goes before it.
      expect(
        rate(
          Currency.eur,
          Currency.huf,
          DateTime(2026, 11, 20),
          RateSource.mnb,
        ),
        390,
      );
      // Typed in the other way round.
      expect(
        rate(
          Currency.gbp,
          Currency.huf,
          DateTime(2026, 11, 20),
          RateSource.mnb,
        ),
        closeTo(500, 1e-9),
      );
      // Manual source: only the manual ones.
      expect(
        rate(
          Currency.eur,
          Currency.huf,
          DateTime(2026, 11, 20),
          RateSource.manual,
        ),
        385,
      );
      expect(
        rate(
          Currency.usd,
          Currency.huf,
          DateTime(2026, 11, 20),
          RateSource.manual,
        ),
        isNull,
      );
    });

    test("official: the source's own rate published on or before the day; "
        'none after it, of another source, typed in, or past the downloaded '
        'ones', () {
      RateQuote? official(Currency from, DateTime date, RateSource source) =>
          book.official(from, Currency.huf, date, source);
      expect(official(Currency.eur, DateTime(2026, 11, 20), RateSource.mnb), (
        rate: 390.0,
        date: DateTime(2026, 11, 20),
        source: RateSource.mnb,
      ));
      // Not the one typed in on the 19th.
      expect(
        official(Currency.eur, DateTime(2026, 11, 19), RateSource.mnb)?.rate,
        380,
      );
      // The weekend: Friday's.
      expect(
        official(Currency.eur, DateTime(2026, 11, 22), RateSource.mnb)?.rate,
        390,
      );
      // None before the 18th; not downloaded yet a week after the 20th.
      expect(
        official(Currency.eur, DateTime(2026, 11, 17), RateSource.mnb),
        isNull,
      );
      expect(
        official(Currency.eur, DateTime(2026, 11, 28), RateSource.mnb),
        isNull,
      );
      // Across the ECB's pivot: 400 / 1.25.
      expect(
        official(Currency.usd, DateTime(2026, 11, 20), RateSource.ecb)?.rate,
        closeTo(320, 1e-9),
      );
      // Not the other source's, nor for manual.
      expect(
        official(Currency.eur, DateTime(2026, 11, 20), RateSource.ecb)?.rate,
        400,
      );
      expect(
        official(Currency.gbp, DateTime(2026, 11, 20), RateSource.mnb),
        isNull,
      );
      expect(
        official(Currency.eur, DateTime(2026, 11, 20), RateSource.manual),
        isNull,
      );
    });

    test("the other source if the chosen one doesn't have it", () {
      final mnbOnly = RateBook([
        _rate(
          RateSource.mnb,
          DateTime(2026, 11, 20),
          Currency.usd,
          Currency.huf,
          300,
        ),
      ]);
      expect(
        mnbOnly
            .quote(
              Currency.usd,
              Currency.huf,
              DateTime(2026, 11, 20),
              RateSource.ecb,
            )
            ?.source,
        RateSource.mnb,
      );
      expect(
        mnbOnly.quote(
          Currency.chf,
          Currency.huf,
          DateTime(2026, 11, 20),
          RateSource.ecb,
        ),
        isNull,
      );
      expect(const RateBook.empty().isEmpty, isTrue);
    });
  });

  group('database and download at start', () {
    late TestDatabase testDb;
    setUp(() async => testDb = await TestDatabase.create());
    tearDown(() => testDb.dispose());

    test('rates are saved once a day, the last days and the needs', () async {
      final db = testDb.datasource;
      final user = await db.insertProfile(
        const Profile(name: 'Anna', mainCurrency: Currency.eur),
      );
      final account = await db.insert(
        Account.table,
        Account(userId: user, name: 'Dollar', currency: Currency.usd),
      );
      await db.insert(
        Entry.table,
        Entry(
          accountId: account,
          type: EntryType.income,
          amount: 100,
          date: DateTime(2026, 3, 4),
        ),
      );
      final needs = await db.rateNeeds();
      expect(needs.currencies, {Currency.usd, Currency.eur});
      expect(needs.firstDay, DateTime(2026, 3, 4));

      await db.saveRates([
        _rate(
          RateSource.mnb,
          DateTime(2026, 11, 20),
          Currency.eur,
          Currency.huf,
          380,
        ),
        _rate(
          RateSource.mnb,
          DateTime(2026, 11, 19),
          Currency.eur,
          Currency.huf,
          379,
        ),
      ]);
      // The same day again: replaced.
      await db.saveRates([
        _rate(
          RateSource.mnb,
          DateTime(2026, 11, 20),
          Currency.eur,
          Currency.huf,
          381,
        ),
      ]);
      final rates = await db.getAll(ExchangeRate.table, ExchangeRate.fromMap);
      expect(rates, hasLength(2));
      expect(rates.map((r) => r.rate), containsAll([379.0, 381.0]));
      expect(await db.lastRateDays(RateSource.mnb), {
        Currency.eur: DateTime(2026, 11, 20),
      });
      expect(await db.lastRateDays(RateSource.ecb), isEmpty);
    });

    test('the download asks each currency from the day after its last rate '
        'or from January 1 of the first entry\'s year, then reloads', () async {
      final db = testDb.datasource;
      final anna = await db.insertProfile(
        const Profile(name: 'Anna', rateSource: RateSource.ecb),
      );
      await db.insertProfile(
        const Profile(name: 'Béla', rateSource: RateSource.manual),
      );
      final account = await db.insert(
        Account.table,
        Account(userId: anna, name: 'Euro', currency: Currency.eur),
      );
      await db.insert(
        Entry.table,
        Entry(
          accountId: account,
          type: EntryType.income,
          amount: 100,
          date: DateTime(2026, 3, 4),
        ),
      );

      final asked = <(RateSource, Set<Currency>, DateTime, DateTime)>[];
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          financeDatasourceProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          rateDownloaderProvider.overrideWithValue(
            RateDownloader(
              fetch: (url, {body, headers = const {}}) async {
                final from = DateTime.parse(
                  url.queryParameters['startPeriod']!,
                );
                asked.add((
                  RateSource.ecb,
                  {Currency.huf},
                  from,
                  DateTime.parse(url.queryParameters['endPeriod']!),
                ));
                return 'CURRENCY,CURRENCY_DENOM,TIME_PERIOD,OBS_VALUE\n'
                    'HUF,EUR,${Entry.dateText(from)},400\n';
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(financeProvider.notifier).load();

      await container.read(ratesProvider.notifier).update(atStart: true);
      final update = container.read(ratesProvider);
      expect(update.error, isNull);
      expect(update.saved, 1);
      // Only the ECB (Béla types his in), only HUF (EUR is its pivot).
      // The choice is for the whole year: from January 1.
      expect(asked.single.$3, DateTime(2026));
      expect(asked.single.$4, currentDay());
      // Reloaded: the EUR account counts in HUF.
      final state = container.read(financeProvider);
      expect(state.rates.isEmpty, isFalse);
      expect(state.toMain(100, Currency.eur, DateTime(2026, 3, 4)), 400);

      // The next time from the day after the last rate.
      await container.read(ratesProvider.notifier).update();
      expect(asked.last.$3, DateTime(2026, 1, 2));

      // Off in the settings: nothing at start.
      container.read(ratesAtStartProvider.notifier).set(false);
      await container.read(ratesProvider.notifier).update(atStart: true);
      expect(asked, hasLength(2));
    });

    test("after the download a personal user's entries without a rate get "
        "their day's, a sole proprietor's don't", () async {
      final db = testDb.datasource;
      Future<int> entryOf(int user) async {
        final account = await db.insert(
          Account.table,
          Account(userId: user, name: 'Euro', currency: Currency.eur),
        );
        return db.insert(
          Entry.table,
          Entry(
            accountId: account,
            type: EntryType.income,
            amount: 100,
            date: DateTime(2026, 3, 4),
          ),
        );
      }

      final anna = await db.insertProfile(
        const Profile(name: 'Anna', rateSource: RateSource.ecb),
      );
      final bela = await db.insertProfile(
        const Profile(
          name: 'Béla',
          userType: UserType.soleProprietor,
          rateSource: RateSource.ecb,
        ),
      );
      final annas = await entryOf(anna);
      final belas = await entryOf(bela);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          financeDatasourceProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          rateDownloaderProvider.overrideWithValue(
            RateDownloader(
              fetch: (url, {body, headers = const {}}) async =>
                  'CURRENCY,CURRENCY_DENOM,TIME_PERIOD,OBS_VALUE\n'
                  'HUF,EUR,${url.queryParameters['startPeriod']},400\n',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(ratesProvider.notifier).update();

      final filled = await db.getById(Entry.table, annas, Entry.fromMap);
      expect(filled!.rate, closeTo(400, 1e-9));
      expect(filled.rateSource, RateSource.ecb);
      final kept = await db.getById(Entry.table, belas, Entry.fromMap);
      expect(kept!.rate, isNull);
    });

    test("a sole proprietor's MNB / ECB only reported to NAV; a year's "
        'rates back to January 1; a currency\'s year on demand', () async {
      final db = testDb.datasource;
      final ev = await db.insertProfile(
        const Profile(
          name: 'EV',
          userType: UserType.soleProprietor,
          rateSource: RateSource.ecb,
        ),
      );
      await db.saveInvoice(
        Invoice(
          userId: ev,
          direction: InvoiceDirection.outgoing,
          issueDate: DateTime(2026, 6, 4),
          fulfillmentDate: DateTime(2026, 6, 4),
          currency: Currency.usd,
          netAmount: 10000,
          vatCode: VatCode.eufad37,
        ),
        const [],
      );
      // A rate of the summer only.
      await db.saveRates([
        _rate(
          RateSource.ecb,
          DateTime(2026, 6, 1),
          Currency.usd,
          Currency.eur,
          0.9,
        ),
      ]);

      final asked = <(Set<String>, DateTime)>[];
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          financeDatasourceProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          rateDownloaderProvider.overrideWithValue(
            RateDownloader(
              fetch: (url, {body, headers = const {}}) async {
                // .../EXR/D.HUF+USD.EUR.SP00.A
                final codes = url.pathSegments.last.split('.')[1].split('+');
                final from = DateTime.parse(
                  url.queryParameters['startPeriod']!,
                );
                asked.add((codes.toSet(), from));
                return 'CURRENCY,CURRENCY_DENOM,TIME_PERIOD,OBS_VALUE\n'
                    '${[for (final c in codes) '$c,EUR,${Entry.dateText(from)},2'].join('\n')}\n';
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final rates = container.read(ratesProvider.notifier);

      // Not reported: their own bank's, nothing to download.
      await rates.update();
      expect(asked, isEmpty);

      final profile = await db.getById(Profile.table, ev, Profile.fromMap);
      await db.update(
        Profile.table,
        profile!.copyWith(rateSourceReported: true),
      );
      await rates.update();
      // HUF and USD (EUR is the pivot), from January 1: USD's rates start in
      // June.
      expect(asked.single.$1, {'HUF', 'USD'});
      expect(asked.single.$2, DateTime(2026));

      // A currency not used yet, for an invoice of last year.
      expect(
        await rates.downloadYear(RateSource.ecb, Currency.chf, 2025),
        true,
      );
      expect(asked.last.$1, {'CHF'});
      expect(asked.last.$2, DateTime(2025));
    });

    test('a failed download keeps the error and the data', () async {
      final db = testDb.datasource;
      final anna = await db.insertProfile(const Profile(name: 'Anna'));
      await db.insert(
        Account.table,
        Account(userId: anna, name: 'Euro', currency: Currency.eur),
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          financeDatasourceProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          rateDownloaderProvider.overrideWithValue(
            RateDownloader(
              fetch: (url, {body, headers = const {}}) async =>
                  throw const RateDownloadException('www.mnb.hu: offline'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(ratesProvider.notifier).update();
      expect(container.read(ratesProvider).error, contains('offline'));
      expect(container.read(ratesProvider).running, isFalse);
    });
  });
}
