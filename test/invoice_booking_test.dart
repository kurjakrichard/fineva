import 'package:fineva/data/data_export.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_database.dart';

void main() {
  const huf = Account(id: 1, name: 'Bank', type: AccountType.bank);
  const eur = Account(
    id: 2,
    name: 'Bank EUR',
    type: AccountType.bank,
    currency: Currency.eur,
  );
  const usd = Account(id: 3, name: 'USD', currency: Currency.usd);
  final categories = [
    for (final (i, c) in [
      ...BuiltInCategories.current.ofSet(BuiltInSet.business),
      ...BuiltInCategories.current.itemized,
    ].indexed)
      EntryCategory(
        id: i + 1,
        name: c.name,
        type: c.type,
        systemKey: c.systemKey,
        taxTreatment: c.taxTreatment,
        scope: c.scope,
      ),
  ];
  EntryCategory category(String key) =>
      categories.firstWhere((c) => c.systemKey == key);

  Invoice invoice({
    InvoiceDirection direction = InvoiceDirection.outgoing,
    int net = 100000,
    int vat = 27000,
    DateTime? paid,
    int? paidAmount,
    Currency currency = Currency.huf,
    int rate = Invoice.rateScale,
    int? paidRate,
  }) => Invoice(
    id: 7,
    direction: direction,
    number: 'A-1',
    partnerName: 'Partner Kft.',
    issueDate: DateTime(2026, 3, 1),
    fulfillmentDate: DateTime(2026, 3, 1),
    currency: currency,
    exchangeRate: rate,
    netAmount: net,
    vatCode: vat == 0 ? VatCode.aam : VatCode.vat27,
    vatAmount: vat,
    payments: [
      if (paid != null)
        InvoicePayment(date: paid, amount: paidAmount ?? net + vat),
    ],
    paidExchangeRate: paidRate,
  );

  List<Entry> book(Invoice invoice, Account? account, String categoryKey) =>
      invoiceEntries(
        invoice,
        account: account,
        category: category(categoryKey),
        categories: categories,
      );

  group('invoiceEntries', () {
    test('an unpaid invoice or one without account books nothing', () {
      expect(book(invoice(), huf, 'businessIncome'), isEmpty);
      expect(
        book(invoice(paid: DateTime(2026, 3, 5)), null, 'businessIncome'),
        isEmpty,
      );
    });

    test('a paid sale is one income of the paid gross on the account', () {
      final entries = book(
        invoice(paid: DateTime(2026, 3, 5)),
        huf,
        'businessIncome',
      );
      final entry = entries.single;
      expect(entry.accountId, huf.id);
      expect(entry.categoryId, category('businessIncome').id);
      expect(entry.type, EntryType.income);
      expect(entry.amount, 127000);
      expect(entry.date, DateTime(2026, 3, 5));
      expect(entry.note, 'A-1 · Partner Kft.');
      expect(entry.invoiceId, 7);
      expect(entry.exchangeRate, isNull);
    });

    test('a paid purchase is an expense', () {
      final entry = book(
        invoice(
          direction: InvoiceDirection.incoming,
          paid: DateTime(2026, 3, 5),
          paidAmount: 50000,
        ),
        huf,
        'businessExpense',
      ).single;
      expect(entry.type, EntryType.expense);
      expect(entry.amount, 50000);
    });

    test('a taxed category splits off the VAT, in proportion when partly '
        'paid', () {
      final sale = book(
        invoice(paid: DateTime(2026, 3, 5), paidAmount: 63500),
        huf,
        'bizRevenue',
      );
      expect(
        [for (final e in sale) (e.categoryId, e.type, e.amount)],
        [
          (category('bizRevenue').id, EntryType.income, 50000),
          (category('bizNonTaxableIncome').id, EntryType.income, 13500),
        ],
      );

      final purchase = book(
        invoice(
          direction: InvoiceDirection.incoming,
          net: 24000,
          vat: 6480,
          paid: DateTime(2026, 1, 20),
        ),
        huf,
        'bizIt',
      );
      expect(
        [for (final e in purchase) (e.categoryId, e.type, e.amount)],
        [
          (category('bizIt').id, EntryType.expense, 24000),
          (category('bizVat').id, EntryType.expense, 6480),
        ],
      );
    });

    test('foreign currency: kept on an account of the currency with the '
        'paid rate, converted on a HUF account, refused on another', () {
      final euros = invoice(
        net: 12000,
        vat: 3240,
        currency: Currency.eur,
        rate: 3900000,
        paid: DateTime(2026, 2, 6),
        paidRate: 3950000,
      );
      final onEur = book(euros, eur, 'bizAccounting');
      expect(onEur.map((e) => e.amount), [12000, 3240]);
      expect(onEur.map((e) => e.exchangeRate), [3950000, 3950000]);
      expect(onEur.map((e) => e.accountId).toSet(), {eur.id});

      final onHuf = book(euros, huf, 'businessExpense').single;
      expect(onHuf.amount, 60198); // 152.40 EUR * 395
      expect(onHuf.exchangeRate, isNull);

      // Without a payment rate the invoice's own.
      final invoiceRate = book(
        invoice(
          net: 10000,
          vat: 0,
          currency: Currency.eur,
          rate: 3900000,
          paid: DateTime(2026, 2, 6),
        ),
        huf,
        'businessIncome',
      ).single;
      expect(invoiceRate.amount, 39000);

      expect(book(euros, usd, 'businessExpense'), isEmpty);
    });

    test('a credit note (negative amounts) books the other type', () {
      final entry = book(
        invoice(net: -10000, vat: -2700, paid: DateTime(2026, 3, 5)),
        huf,
        'businessIncome',
      ).single;
      expect(entry.type, EntryType.expense);
      expect(entry.amount, 12700);
    });
  });

  test('an invoice paid in parts: an entry for each payment, on its day', () {
    final invoice = Invoice(
      id: 7,
      direction: InvoiceDirection.outgoing,
      number: 'A-7',
      issueDate: DateTime(2026, 3, 1),
      fulfillmentDate: DateTime(2026, 3, 1),
      netAmount: 100000,
      vatCode: VatCode.aam,
      payments: [
        InvoicePayment(date: DateTime(2026, 3, 10), amount: 60000),
        InvoicePayment(date: DateTime(2026, 4, 2), amount: 40000),
      ],
    );
    final entries = invoiceEntries(
      invoice,
      account: const Account(id: 1, name: 'Bank'),
      category: null,
      categories: const [],
    );
    expect(entries.map((e) => (e.date, e.amount, e.type)), [
      (DateTime(2026, 3, 10), 60000, EntryType.income),
      (DateTime(2026, 4, 2), 40000, EntryType.income),
    ]);
    expect(entries.map((e) => e.invoiceId), [7, 7]);
  });

  group('booking through the notifier', () {
    late TestDatabase testDb;
    late ProviderContainer container;

    setUp(() async {
      testDb = await TestDatabase.create();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          financeDatasourceProvider.overrideWithValue(testDb.datasource),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      await testDb.dispose();
    });

    FinanceNotifier notifier() => container.read(financeProvider.notifier);
    FinanceState state() => container.read(financeProvider);

    test('paying, changing, unpaying and deleting an invoice keeps its '
        'entry in step', () async {
      await notifier().load();
      // Itemized taxation keeps accounts (an invoices only user doesn't).
      await notifier().saveProfile(
        const Profile(
          name: 'Vállalkozó',
          userType: UserType.soleProprietor,
          taxRegime: TaxRegime.itemized,
        ),
      );
      await notifier().saveAccount(
        const Account(name: 'Bank', type: AccountType.bank),
      );
      final account = state().accounts.single;
      final income = state().categories.firstWhere(
        (c) => c.systemKey == 'businessIncome',
      );
      Invoice sale({int? id, DateTime? paid, int paidAmount = 0}) => Invoice(
        id: id,
        direction: InvoiceDirection.outgoing,
        number: 'A-1',
        issueDate: DateTime(2026, 3, 1),
        fulfillmentDate: DateTime(2026, 3, 1),
        netAmount: 100000,
        vatCode: VatCode.aam,
        payments: [
          if (paid != null) InvoicePayment(date: paid, amount: paidAmount),
        ],
        paidAccountId: account.id,
        categoryId: income.id,
      );

      // Not paid yet: an open invoice, no entry.
      expect(await notifier().saveInvoice(sale()), isTrue);
      final id = state().invoices.single.id!;
      expect(state().entries, isEmpty);
      expect(state().balances[account.id], 0);

      await notifier().saveInvoice(
        sale(id: id, paid: DateTime(2026, 3, 10), paidAmount: 100000),
      );
      final entry = state().entries.single;
      expect(entry.invoiceId, id);
      expect(entry.amount, 100000);
      expect(state().balances[account.id], 100000);

      // Changed: the entry is replaced, not added.
      await notifier().saveInvoice(
        sale(id: id, paid: DateTime(2026, 3, 12), paidAmount: 40000),
      );
      expect(state().entries.single.amount, 40000);
      expect(state().entries.single.date, DateTime(2026, 3, 12));

      await notifier().saveInvoice(sale(id: id));
      expect(state().entries, isEmpty);

      await notifier().saveInvoice(
        sale(id: id, paid: DateTime(2026, 3, 10), paidAmount: 100000),
      );
      expect(state().entries, hasLength(1));
      await notifier().deleteInvoice(state().invoices.single);
      expect(state().invoices, isEmpty);
      expect(state().entries, isEmpty);
      expect(state().balances[account.id], 0);
    });

    test("an invoices only user's paid invoice isn't booked; the entries "
        'booked before go when it is saved again', () async {
      await notifier().load();
      await notifier().saveProfile(
        const Profile(
          name: 'Átalányadós',
          userType: UserType.soleProprietor,
          taxRegime: TaxRegime.kata,
        ),
      );
      await notifier().saveAccount(
        const Account(name: 'Bank', type: AccountType.bank),
      );
      final account = state().accounts.single;
      final income = state().categories.firstWhere(
        (c) => c.systemKey == 'businessIncome',
      );
      Invoice sale({int? id}) => Invoice(
        id: id,
        direction: InvoiceDirection.outgoing,
        number: 'A-1',
        issueDate: DateTime(2026, 3, 1),
        fulfillmentDate: DateTime(2026, 3, 1),
        netAmount: 100000,
        vatCode: VatCode.aam,
        payments: [InvoicePayment(date: DateTime(2026, 3, 10), amount: 100000)],
        paidAccountId: account.id,
        categoryId: income.id,
      );
      // Booked while KATA.
      await notifier().saveInvoice(sale());
      expect(state().entries, hasLength(1));

      // Flat-rate and VAT exempt: invoices only.
      await notifier().saveProfile(
        state().profile!.copyWith(taxRegime: TaxRegime.flatRate),
      );
      expect(state().profile!.invoicesOnly, isTrue);
      await notifier().saveInvoice(sale(id: state().invoices.single.id));
      expect(state().entries, isEmpty);
      final saved = state().invoices.single;
      expect(saved.paidAccountId, isNull);
      expect(saved.categoryId, isNull);
      expect(saved.paidAmount, 100000);

      await notifier().saveInvoice(sale());
      expect(state().invoices, hasLength(2));
      expect(state().entries, isEmpty);
    });

    test('a payment added, changed and deleted: saved with its invoice, '
        'booked, refused if more than the invoice', () async {
      await notifier().load();
      await notifier().saveProfile(
        const Profile(
          name: 'KATA',
          userType: UserType.soleProprietor,
          taxRegime: TaxRegime.kata,
        ),
      );
      await notifier().saveAccount(
        const Account(name: 'Bank', type: AccountType.bank),
      );
      final account = state().accounts.single;
      await notifier().saveInvoice(
        Invoice(
          direction: InvoiceDirection.outgoing,
          number: 'K-1',
          issueDate: DateTime(2026, 3, 1),
          fulfillmentDate: DateTime(2026, 3, 1),
          netAmount: 100000,
          vatCode: VatCode.aam,
          paidAccountId: account.id,
        ),
      );
      Invoice invoice() => state().invoices.single;

      expect(
        await notifier().savePayment(
          invoice(),
          InvoicePayment(date: DateTime(2026, 3, 10), amount: 30000),
        ),
        isTrue,
      );
      expect(
        await notifier().savePayment(
          invoice(),
          InvoicePayment(date: DateTime(2026, 3, 5), amount: 50000),
        ),
        isTrue,
      );
      // In the order paid; each booked.
      expect(invoice().payments.map((p) => p.amount), [50000, 30000]);
      expect(state().entries.map((e) => e.amount), [30000, 50000]);
      expect(state().balances[account.id], 80000);

      // More than the invoice: refused, nothing changes.
      expect(
        await notifier().savePayment(
          invoice(),
          InvoicePayment(date: DateTime(2026, 3, 20), amount: 20001),
        ),
        isFalse,
      );
      expect(invoice().paidAmount, 80000);

      final first = invoice().payments.first;
      await notifier().savePayment(invoice(), first.copyWith(amount: 70000));
      expect(invoice().payments.map((p) => p.amount), [70000, 30000]);
      expect(invoice().isPaid, isTrue);

      await notifier().deletePayment(invoice(), invoice().payments.last);
      expect(invoice().payments.map((p) => p.amount), [70000]);
      expect(state().entries.single.amount, 70000);
    });

    test('a payment chosen for the wrong invoice moved to another: as it '
        'is, its entry with it; not more than that one is open', () async {
      await notifier().load();
      await notifier().saveProfile(
        const Profile(
          name: 'KATA',
          userType: UserType.soleProprietor,
          taxRegime: TaxRegime.kata,
        ),
      );
      await notifier().saveAccount(
        const Account(name: 'Bank', type: AccountType.bank),
      );
      final account = state().accounts.single;
      for (final (number, net) in [('K-1', 100000), ('K-2', 30000)]) {
        await notifier().saveInvoice(
          Invoice(
            direction: InvoiceDirection.outgoing,
            number: number,
            issueDate: DateTime(2026, 3, 1),
            fulfillmentDate: DateTime(2026, 3, 1),
            netAmount: net,
            vatCode: VatCode.aam,
            paidAccountId: account.id,
          ),
        );
      }
      Invoice invoice(String number) =>
          state().invoices.firstWhere((i) => i.number == number);
      await notifier().savePayment(
        invoice('K-1'),
        InvoicePayment(date: DateTime(2026, 3, 10), amount: 30000),
      );
      final payment = invoice('K-1').payments.single;
      expect(state().entries.single.invoiceId, invoice('K-1').id);

      // K-2 was paid.
      expect(
        await notifier().savePayment(
          invoice('K-2'),
          payment,
          from: invoice('K-1'),
        ),
        isTrue,
      );
      expect(invoice('K-1').payments, isEmpty);
      expect(invoice('K-2').payments.single.id, payment.id);
      expect(invoice('K-2').payments.single.date, DateTime(2026, 3, 10));
      expect(invoice('K-2').isPaid, isTrue);
      expect(state().entries.single.invoiceId, invoice('K-2').id);
      expect(state().balances[account.id], 30000);

      // Back to K-1, but more than K-2 had open: refused, nothing moves.
      await notifier().savePayment(
        invoice('K-1'),
        InvoicePayment(date: DateTime(2026, 3, 12), amount: 100000),
      );
      final big = invoice('K-1').payments.single;
      expect(
        await notifier().savePayment(invoice('K-2'), big, from: invoice('K-1')),
        isFalse,
      );
      expect(invoice('K-1').payments.single.id, big.id);
    });
  });
}
