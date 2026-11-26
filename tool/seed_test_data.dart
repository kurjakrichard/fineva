// Puts the test data of tool/test_data/test_data.json (made by
// tool/test_data/build_test_data.py) into a Fineva database, replacing every
// user, then writes what the app calculates from it for comparing with the
// workbooks:
//
//   FINEVA_DB=~/.local/share/com.example.fineva/fineva.db \
//   FINEVA_RESULTS=/some/where/app_results.json \
//   flutter test tool/seed_test_data.dart
//
// Run it with the app closed (or restart the app after it). It is not part
// of the test suite: it writes the real database.
import 'dart:convert';
import 'dart:io';

import 'package:fineva/data/data_export.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/test_database.dart' show testDatabaseFactory;

DateTime? _date(Object? text) =>
    text == null ? null : DateTime.parse(text as String);

T _enum<T extends Enum>(List<T> values, Object? name) =>
    values.byName(name! as String);

void main() {
  test('seed the test data', () async {
    final dbPath = Platform.environment['FINEVA_DB'];
    if (dbPath == null || !File(dbPath).existsSync()) {
      fail('FINEVA_DB must name an existing database');
    }
    final data = jsonDecode(
      File('tool/test_data/test_data.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final year = data['year']! as int;
    BuiltInCategories.current = BuiltInCategories.parse(
      File(BuiltInCategories.asset).readAsStringSync(),
    );
    final datasource = FinanceDatasource(
      path: dbPath,
      factory: testDatabaseFactory,
    );
    final repo = FinanceRepositoryImpl(datasource);

    for (final old in await repo.getProfiles()) {
      await repo.deleteProfile(old);
    }

    for (final user in data['users']! as List) {
      final u = user as Map<String, Object?>;
      final p = u['profile']! as Map<String, Object?>;
      final profile = Profile(
        name: p['name']! as String,
        address: p['address']! as String,
        taxId: p['taxId']! as String,
        taxNumber: p['taxNumber']! as String,
        userType: _enum(UserType.values, p['userType']),
        taxRegime: _enum(TaxRegime.values, p['taxRegime']),
        vatStatus: _enum(VatStatus.values, p['vatStatus']),
        euReporting: p['euReporting']! as bool,
        euVatNumber: p['euVatNumber']! as String,
        vatPeriod: _enum(VatPeriod.values, p['vatPeriod']),
        costRatio: p['costRatio']! as int,
        mainOccupation: p['mainOccupation']! as bool,
      );
      // The data must be what the onboarding accepts.
      expect(parseTaxId(profile.taxId), profile.taxId, reason: profile.name);
      expect(profile.isComplete, isTrue, reason: profile.name);
      if (profile.isSoleProprietor) {
        expect(parseTaxNumber(profile.taxNumber), profile.taxNumber);
      }
      final userId = await repo.saveProfile(profile);
      if (u['businessCategories'] == true) {
        await repo.addBusinessCategories(userId);
      }
      final categories = {
        for (final c in await repo.getCategories(userId)) c.systemKey: c.id,
      };

      final accounts = <String, int>{};
      for (final account in u['accounts']! as List) {
        final a = account as Map<String, Object?>;
        final id = await repo.saveAccount(
          Account(
            userId: userId,
            name: a['name']! as String,
            type: _enum(AccountType.values, a['type']),
            currency: Currency.fromCode(a['currency']! as String),
            description: a['description'] as String? ?? '',
            bankAccount: a['bankAccount'] as String? ?? '',
            swift: a['swift'] as String? ?? '',
            closedDate: _date(a['closedDate']),
          ),
        );
        accounts[a['key']! as String] = id;
        // The opening balance is an entry, at the start of the year.
        final opening = a['initialBalance']! as int;
        if (opening != 0) {
          await repo.saveEntry(
            Entry(
              accountId: id,
              type: opening > 0 ? EntryType.income : EntryType.expense,
              amount: opening.abs(),
              date: DateTime(year),
              opening: true,
            ),
            userId,
          );
        }
      }
      for (final entry in u['entries']! as List) {
        final e = entry as Map<String, Object?>;
        final category = e['category'] as String?;
        if (category != null && !categories.containsKey(category)) {
          fail('No category $category for ${profile.name}');
        }
        await repo.saveEntry(
          Entry(
            accountId: accounts[e['account']]!,
            categoryId: category == null ? null : categories[category],
            type: _enum(EntryType.values, e['type']),
            amount: e['amount']! as int,
            date: _date(e['date'])!,
            note: e['note']! as String,
            // HUF per unit times exchangeRateScale in the data.
            rate: switch (e['exchangeRate']) {
              final int rate => rate / exchangeRateScale,
              _ => null,
            },
          ),
          userId,
        );
      }
      final allCategories = await repo.getCategories(userId);
      final allAccounts = await repo.getAccounts(userId);
      // Transfers as the transfer page makes them: the same worth on both
      // sides, a rate made from the amounts the day's.
      Account accountOf(Object? key) =>
          allAccounts.firstWhere((a) => a.id == accounts[key]);
      for (final transfer in (u['transfers'] as List?) ?? const []) {
        final t = transfer as Map<String, Object?>;
        final sides = transferSides(
          from: accountOf(t['from']),
          to: accountOf(t['to']),
          fromAmount: t['fromAmount']! as int,
          toAmount: t['toAmount'] as int?,
          date: _date(t['date'])!,
          note: t['note']! as String,
          main: profile.mainCurrency,
        )!;
        await repo.saveRates(sides.dayRates);
        await repo.saveTransfer(null, userId, sides.from, sides.to);
      }
      for (final invoice in u['invoices']! as List) {
        final i = invoice as Map<String, Object?>;
        final paidAccount = accounts[i['paidAccount']];
        // None for an invoices only user's (not booked).
        final category = categories[i['category']];
        if (i['category'] != null && category == null) {
          fail('No category ${i['category']} for ${profile.name}');
        }
        final saved = Invoice(
          userId: userId,
          direction: _enum(InvoiceDirection.values, i['direction']),
          number: i['number']! as String,
          description: i['description']! as String,
          partnerName: i['partnerName']! as String,
          partnerTaxNumber: i['partnerTaxNumber']! as String,
          partnerLocation: _enum(PartnerLocation.values, i['partnerLocation']),
          paymentMethod: _enum(PaymentMethod.values, i['paymentMethod']),
          issueDate: _date(i['issueDate'])!,
          fulfillmentDate: _date(i['fulfillmentDate'])!,
          dueDate: _date(i['dueDate']),
          currency: Currency.fromCode(i['currency']! as String),
          exchangeRate: i['exchangeRate']! as int,
          netAmount: i['netAmount']! as int,
          vatCode: _enum(VatCode.values, i['vatCode']),
          vatAmount: i['vatAmount']! as int,
          // One payment (the workbooks have one), by the invoice's way.
          payments: [
            if (_date(i['paidDate']) case final paid?)
              InvoicePayment(
                date: paid,
                amount: i['paidAmount']! as int,
                method: _enum(PaymentMethod.values, i['paymentMethod']),
              ),
          ],
          paidAccountId: paidAccount,
          paidExchangeRate: i['paidExchangeRate'] as int?,
          categoryId: category,
        );
        // Booked as the invoice page books it.
        final entries = invoiceEntries(
          saved,
          account: allAccounts.where((a) => a.id == paidAccount).firstOrNull,
          category: allCategories.where((c) => c.id == category).firstOrNull,
          categories: allCategories,
        );
        // Booked, unless the user keeps invoices only.
        if (saved.paidDate != null) {
          expect(entries, profile.invoicesOnly ? isEmpty : isNotEmpty);
        }
        await repo.saveInvoice(saved, entries);
      }
      for (final asset in u['assets']! as List) {
        final a = asset as Map<String, Object?>;
        await repo.saveAsset(
          Asset(
            userId: userId,
            name: a['name']! as String,
            purchaseDate: _date(a['purchaseDate'])!,
            invoiceNumber: a['invoiceNumber']! as String,
            supplier: a['supplier']! as String,
            amount: a['amount']! as int,
            rate: a['rate']! as int,
          ),
        );
      }
    }

    // What the app calculates, read back from the database.
    final results = <String, Object?>{};
    for (final profile in await repo.getProfiles()) {
      final id = profile.id!;
      final invoices = await repo.getInvoices(id);
      final result = <String, Object?>{
        'entries': (await repo.getEntries(id)).length,
        'invoices': invoices.length,
      };
      if (profile.taxRegime == TaxRegime.flatRate && profile.isSoleProprietor) {
        final tax = FlatRateTax(invoices, profile, year);
        result['flatRate'] = {
          'revenue': tax.revenue,
          'total': tax.total,
          'quarters': [
            for (final q in tax.quarters)
              {
                'revenue': q.revenue,
                'income': q.income,
                'taxable': q.taxableIncome,
                'tbBase': q.contributionBase,
                'szochoBase': q.szochoBase,
                'szja': q.szja,
                'tb': q.tb,
                'szocho': q.szocho,
                'localTax': q.localTax,
                'chamber': q.chamberFee,
                'total': q.total,
              },
          ],
        };
      }
      if (profile.isSoleProprietor &&
          (profile.vatStatus == VatStatus.registered || profile.euReporting)) {
        final vatPeriod = profile.vatStatus == VatStatus.registered
            ? profile.vatPeriod
            : VatPeriod.quarterly;
        final summaries = [
          for (final period in VatReturnPeriod.ofYear(year, vatPeriod))
            VatSummary(invoices, profile, period),
        ];
        final carried = vatCarriedIn(summaries);
        result['vat'] = [
          for (final (i, s) in summaries.indexed)
            {
              'start': Entry.dateText(s.period.start),
              'payable': s.totalPayable,
              'deductible': s.totalDeductible,
              'balance': s.balance,
              'carriedIn': carried[i],
            },
        ];
      }
      if (profile.taxRegime == TaxRegime.itemized) {
        final assets = await repo.getAssets(id);
        final depreciation = List.filled(4, 0);
        for (final asset in assets) {
          final quarters = quarterlyDepreciation(asset, year);
          for (var q = 0; q < 4; q++) {
            depreciation[q] += quarters[q];
          }
        }
        final tax = ItemizedTax(
          entries: await repo.getEntries(id),
          categories: await repo.getCategories(id),
          accounts: await repo.getAccounts(id),
          depreciation: depreciation,
          year: year,
        );
        result['itemized'] = {
          'quarters': [
            for (final q in tax.quarters)
              {
                'revenue': q.revenue,
                'costs': q.costs,
                'depreciation': q.depreciation,
                'loss': q.lossCarried,
                'base': q.base,
                'vszja': q.vszja,
                'dividendBase': q.dividendBase,
                'szja': q.szja,
                'total': q.total,
              },
          ],
          'year': {
            'revenue': tax.revenue,
            'costs': tax.costs,
            'base': tax.base,
            'vszja': tax.vszja,
            'dividendBase': tax.dividendBase,
            'szja': tax.szja,
          },
          'szocho': {
            'cap': tax.szochoCap,
            'paid': tax.szochoPaid,
            'onDividend': tax.szochoOnDividend,
          },
          'localTax': {'base': tax.localTaxBase, 'tax': tax.localTax},
          'missingRates': tax.missingRates,
        };
      }
      results[profile.name] = result;
    }
    await datasource.close();

    final out = Platform.environment['FINEVA_RESULTS'];
    if (out != null) {
      File(
        out,
      ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(results));
    }
    // ignore: avoid_print
    print('Seeded ${results.length} users.');
  }, timeout: Timeout.none);
}
