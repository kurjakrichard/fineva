import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fineva/data/data_export.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late TestDatabase testDb;
  late FinanceDatasource db;

  setUp(() async {
    testDb = await TestDatabase.create();
    db = testDb.datasource;
  });
  tearDown(() => testDb.dispose());

  Future<int> addEntry(
    int accountId,
    EntryType type,
    int amount, {
    int? categoryId,
    bool opening = false,
  }) => db.insert(
    Entry.table,
    Entry(
      accountId: accountId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      date: DateTime(2026, 11, 22),
      opening: opening,
    ),
  );

  test('a new database has the schema version and no user yet', () async {
    final rows = await (await db.database).rawQuery('PRAGMA user_version');
    expect(rows.first.values.first, FinanceDatasource.schemaVersion);
    expect(await db.getAll(Profile.table, Profile.fromMap), isEmpty);
    // The built-in categories come with a user.
    expect(
      await db.getAll(EntryCategory.table, EntryCategory.fromMap),
      isEmpty,
    );
  });

  test('every user gets the built-in categories of their kind', () async {
    final anna = await db.insertProfile(const Profile(name: 'Kiss Anna'));
    final bela = await db.insertProfile(
      const Profile(name: 'Nagy Béla', userType: UserType.soleProprietor),
    );
    expect(bela, isNot(anna));

    for (final (user, scope, builtIn) in [
      (
        anna,
        CategoryScope.personal,
        BuiltInCategories.current.forNewUser(UserType.personal),
      ),
      (
        bela,
        CategoryScope.business,
        BuiltInCategories.current.forNewUser(UserType.soleProprietor),
      ),
    ]) {
      final categories = await db.getAll(
        EntryCategory.table,
        EntryCategory.fromMap,
        where: 'user_id = ?',
        whereArgs: [user],
      );
      expect(
        categories.map((c) => c.systemKey),
        unorderedEquals(builtIn.map((c) => c.systemKey)),
      );
      expect(categories.every((c) => c.scope == scope), isTrue);
      expect(categories.every((c) => c.icon != null), isTrue);
    }
  });

  test('a user is read back and updated as it was saved', () async {
    const profile = Profile(
      name: 'Kiss Anna',
      address: '1234 Budapest, Fő utca 1.',
      taxId: '8391920003',
      taxNumber: '10773381-2-44',
      userType: UserType.soleProprietor,
      taxRegime: TaxRegime.kata,
      vatStatus: VatStatus.registered,
      euReporting: true,
      euVatNumber: 'HU10773381',
    );
    final id = await db.insertProfile(profile);
    final saved = await db.getById(Profile.table, id, Profile.fromMap);
    expect(saved, isNotNull);
    expect(saved!.name, 'Kiss Anna');
    expect(saved.address, '1234 Budapest, Fő utca 1.');
    expect(saved.taxId, '8391920003');
    expect(saved.taxNumber, '10773381-2-44');
    expect(saved.taxRegime, TaxRegime.kata);
    expect(saved.euReporting, isTrue);
    expect(saved.euVatNumber, 'HU10773381');

    await db.update(Profile.table, saved.copyWith(userType: UserType.personal));
    final updated = await db.getById(Profile.table, id, Profile.fromMap);
    expect(updated!.userType, UserType.personal);
    // The business choices and the tax number are kept.
    expect(updated.vatStatus, VatStatus.registered);
    expect(updated.taxNumber, '10773381-2-44');
  });

  test(
    'deleting a user deletes only their accounts, entries and categories',
    () async {
      final keep = await db.insertProfile(const Profile(name: 'Keep'));
      final gone = await db.insertProfile(const Profile(name: 'Gone'));
      final keepAccount = await db.insert(
        Account.table,
        Account(userId: keep, name: 'A'),
      );
      final goneAccount = await db.insert(
        Account.table,
        Account(userId: gone, name: 'B'),
      );
      await addEntry(keepAccount, EntryType.income, 1);
      await addEntry(goneAccount, EntryType.income, 2);

      await db.delete(Profile.table, gone);
      final accounts = await db.getAll(Account.table, Account.fromMap);
      expect(accounts.map((a) => a.userId), [keep]);
      final entries = await db.getAll(Entry.table, Entry.fromMap);
      expect(entries.map((e) => e.accountId), [keepAccount]);
      final categories = await db.getAll(
        EntryCategory.table,
        EntryCategory.fromMap,
      );
      expect(categories.every((c) => c.userId == keep), isTrue);
    },
  );

  test(
    'an invoice is read back as it was saved, and goes with its user',
    () async {
      final user = await db.insertProfile(const Profile(name: 'EV'));
      final invoice = Invoice(
        userId: user,
        direction: InvoiceDirection.outgoing,
        number: '2026/001',
        description: 'Webfejlesztés',
        partnerName: 'Kunde GmbH',
        partnerTaxNumber: 'DE123456789',
        partnerLocation: PartnerLocation.eu,
        issueDate: DateTime(2026, 3, 2),
        fulfillmentDate: DateTime(2026, 3, 1),
        dueDate: DateTime(2026, 3, 10),
        currency: Currency.eur,
        exchangeRate: 3897300,
        netAmount: 120050,
        vatCode: VatCode.eufad37,
        // Paid in two parts.
        payments: [
          InvoicePayment(date: DateTime(2026, 3, 9), amount: 100000),
          InvoicePayment(
            date: DateTime(2026, 3, 20),
            amount: 20050,
            method: PaymentMethod.cash,
            note: 'a rest',
          ),
        ],
      );
      final id = await db.saveInvoice(invoice, const []);
      final saved = await db.getById(Invoice.table, id, Invoice.fromMap);
      expect(saved, isNotNull);
      // Equal but for the id.
      expect(saved!.toMap(), invoice.toMap());
      final payments = await db.getPayments(user);
      (DateTime, int, PaymentMethod, String) fields(InvoicePayment p) =>
          (p.date, p.amount, p.method, p.note);
      expect(payments.map(fields), invoice.payments.map(fields));
      expect(payments.map((p) => p.invoiceId), [id, id]);
      expect(saved.copyWith(payments: payments).isPaid, isTrue);

      // Saved again: its payments replaced.
      await db.saveInvoice(
        saved.copyWith(payments: [invoice.payments.first]),
        const [],
      );
      expect(await db.getPayments(user), hasLength(1));

      await db.delete(Profile.table, user);
      expect(await db.getAll(Invoice.table, Invoice.fromMap), isEmpty);
      expect(await db.getPayments(user), isEmpty);
    },
  );

  test("the revenue record's sorszám: stored in date order, each year "
      'apart, whatever order recorded in; renumbered after a late one, a '
      'deletion or a new day', () async {
    final user = await db.insertProfile(
      const Profile(name: 'EV', userType: UserType.soleProprietor),
    );
    Invoice sale(String number, DateTime paid) => Invoice(
      userId: user,
      direction: InvoiceDirection.outgoing,
      number: number,
      issueDate: DateTime(paid.year, paid.month),
      fulfillmentDate: DateTime(paid.year, paid.month),
      netAmount: 1000,
      vatCode: VatCode.aam,
      payments: [InvoicePayment(date: paid, amount: 1000)],
    );
    Future<Map<String, int?>> numbers() async => {
      for (final i in await FinanceRepositoryImpl(db).getInvoices(user))
        for (final p in i.payments)
          '${i.number} ${p.date.month}': p.recordNumber,
    };

    final january = await db.saveInvoice(
      sale('A-1', DateTime(2026, 1, 9)),
      const [],
    );
    final march = await db.saveInvoice(
      sale('A-3', DateTime(2026, 3, 9)),
      const [],
    );
    expect(await numbers(), {'A-1 1': 1, 'A-3 3': 2});

    // A late one, received in February: inserted, March's renumbered.
    final february = await db.saveInvoice(
      sale('A-2', DateTime(2026, 2, 9)),
      const [],
    );
    expect(await numbers(), {'A-1 1': 1, 'A-2 2': 2, 'A-3 3': 3});

    // Saved again as it was: the same payment, nothing renumbered.
    final saved = (await FinanceRepositoryImpl(db).getInvoices(user))
        .firstWhere((i) => i.id == march);
    final paymentId = saved.payments.single.id;
    await db.saveInvoice(saved, const []);
    final again = (await FinanceRepositoryImpl(db).getInvoices(user))
        .firstWhere((i) => i.id == march);
    expect(again.payments.single.id, paymentId);
    expect(again.payments.single.recordNumber, 3);

    // January's paid later, after March: moved to its place.
    final first = (await FinanceRepositoryImpl(db).getInvoices(user))
        .firstWhere((i) => i.id == january);
    await db.saveInvoice(
      first.copyWith(
        payments: [first.payments.single.copyWith(date: DateTime(2026, 4, 2))],
      ),
      const [],
    );
    expect(await numbers(), {'A-2 2': 1, 'A-3 3': 2, 'A-1 4': 3});

    // Deleted: the later ones move up.
    await db.deleteInvoice(february, user);
    expect(await numbers(), {'A-3 3': 1, 'A-1 4': 2});

    // Another year has its own numbers; an incoming invoice none.
    await db.saveInvoice(sale('Z-1', DateTime(2025, 12, 30)), const []);
    final cost = await db.saveInvoice(
      Invoice(
        userId: user,
        direction: InvoiceDirection.incoming,
        number: 'B-1',
        issueDate: DateTime(2026, 1, 2),
        fulfillmentDate: DateTime(2026, 1, 2),
        netAmount: 500,
        vatCode: VatCode.vat27,
        payments: [InvoicePayment(date: DateTime(2026, 1, 2), amount: 500)],
      ),
      const [],
    );
    expect(await numbers(), {
      'A-3 3': 1,
      'A-1 4': 2,
      'Z-1 12': 1,
      'B-1 1': null,
    });
    expect(cost, isNotNull);

    // Made incoming: out of the record, the others renumbered.
    final raw = await db.database;
    await raw.update(
      Invoice.table,
      {'direction': InvoiceDirection.incoming.name},
      where: 'id = ?',
      whereArgs: [march],
    );
    await FinanceDatasource.renumber(raw, user);
    expect((await numbers())['A-3 3'], isNull);
    expect((await numbers())['A-1 4'], 1);

    // Recorded bank by bank, not by date: numbered by date all the same.
    for (final day in [20, 5, 28, 11]) {
      await db.saveInvoice(sale('M-$day', DateTime(2026, 5, day)), const []);
    }
    final may = {
      for (final MapEntry(:key, :value) in (await numbers()).entries)
        if (key.startsWith('M-')) key: value,
    };
    expect(may, {'M-5 5': 2, 'M-11 5': 3, 'M-20 5': 4, 'M-28 5': 5});
  });

  test('a payment moved to another invoice keeps its id; the numbers follow; '
      "another user's payment can't be taken", () async {
    final user = await db.insertProfile(
      const Profile(name: 'EV', userType: UserType.soleProprietor),
    );
    Invoice sale(String number, {List<InvoicePayment> payments = const []}) =>
        Invoice(
          userId: user,
          direction: InvoiceDirection.outgoing,
          number: number,
          partnerName: 'Partner $number',
          issueDate: DateTime(2026, 3),
          fulfillmentDate: DateTime(2026, 3),
          netAmount: 1000,
          vatCode: VatCode.aam,
          payments: payments,
        );
    await db.saveInvoice(
      sale(
        'A-1',
        payments: [InvoicePayment(date: DateTime(2026, 3, 5), amount: 1000)],
      ),
      const [],
    );
    await db.saveInvoice(sale('A-2'), const []);
    final repo = FinanceRepositoryImpl(db);
    var invoices = await repo.getInvoices(user);
    final wrong = invoices.firstWhere((i) => i.number == 'A-1');
    final right = invoices.firstWhere((i) => i.number == 'A-2');
    final payment = wrong.payments.single;

    // It goes to A-2 as it is.
    await db.saveInvoices([
      (right.copyWith(payments: [payment]), const []),
      (wrong.copyWith(payments: const []), const []),
    ]);
    invoices = await repo.getInvoices(user);
    final moved = invoices.firstWhere((i) => i.number == 'A-2').payments.single;
    expect(moved.id, payment.id);
    expect(moved.invoiceId, right.id);
    expect(moved.date, payment.date);
    expect(moved.recordNumber, 1);
    expect(invoices.firstWhere((i) => i.number == 'A-1').payments, isEmpty);

    // Another user's invoice can't take it: a new payment of theirs.
    final other = await db.insertProfile(
      const Profile(name: 'Béla', userType: UserType.soleProprietor),
    );
    await db.saveInvoice(
      Invoice(
        userId: other,
        direction: InvoiceDirection.outgoing,
        number: 'B-1',
        issueDate: DateTime(2026, 3),
        fulfillmentDate: DateTime(2026, 3),
        netAmount: 1000,
        vatCode: VatCode.aam,
        payments: [moved],
      ),
      const [],
    );
    expect(
      (await repo.getInvoices(user))
          .firstWhere((i) => i.number == 'A-2')
          .payments
          .single
          .id,
      payment.id,
    );
    expect(
      (await repo.getInvoices(other)).single.payments.single.id,
      isNot(payment.id),
    );
  });

  test("another user's row is refused: changing, deleting, an entry on "
      'their account or in their category', () async {
    final anna = await db.insertProfile(const Profile(name: 'Anna'));
    final bela = await db.insertProfile(const Profile(name: 'Béla'));
    final category = (await db.getAll(
      EntryCategory.table,
      EntryCategory.fromMap,
      where: 'user_id = ?',
      whereArgs: [anna],
    )).first;
    final account = await db.insert(
      Account.table,
      Account(userId: anna, name: 'Anna bank'),
    );
    final belasAccount = await db.insert(
      Account.table,
      Account(userId: bela, name: 'Béla bank'),
    );

    // Hers: as her, yes; as his, no.
    expect(
      await db.update(
        EntryCategory.table,
        category.copyWith(name: 'Renamed'),
        userId: anna,
      ),
      1,
    );
    expect(
      () => db.update(
        EntryCategory.table,
        category.copyWith(name: 'Hacked', userId: bela),
        userId: bela,
      ),
      throwsStateError,
    );
    expect(
      () => db.delete(EntryCategory.table, category.id!, userId: bela),
      throwsStateError,
    );
    expect(
      () => db.delete(Account.table, account, userId: bela),
      throwsStateError,
    );
    final entry = Entry(
      accountId: account,
      type: EntryType.expense,
      amount: 5,
      date: DateTime(2026, 11, 22),
    );
    expect(() => db.saveEntry(entry, bela), throwsStateError);
    final saved = await db.saveEntry(entry, anna);
    expect(() => db.deleteEntry(saved, bela), throwsStateError);
    expect(
      () => db.saveEntry(
        Entry(
          accountId: belasAccount,
          categoryId: category.id,
          type: EntryType.expense,
          amount: 5,
          date: DateTime(2026, 11, 22),
        ),
        bela,
      ),
      throwsStateError,
    );
    // Nothing of hers changed.
    final kept = await db.getById(
      EntryCategory.table,
      category.id!,
      EntryCategory.fromMap,
    );
    expect(kept!.name, 'Renamed');
    expect(kept.userId, anna);
    expect(await db.entryCount(account), 1);
  });

  test('generic insert, read, update and delete', () async {
    final id = await db.insert(
      Account.table,
      const Account(name: 'Wallet', type: AccountType.bank),
    );
    var account = await db.getById(Account.table, id, Account.fromMap);
    expect(
      account,
      const Account(id: 1, name: 'Wallet', type: AccountType.bank),
    );

    await db.update(Account.table, account!.copyWith(name: 'Cash'));
    account = await db.getById(Account.table, id, Account.fromMap);
    expect(account!.name, 'Cash');

    await db.delete(Account.table, id);
    expect(await db.getById(Account.table, id, Account.fromMap), isNull);
  });

  test('an entry is read back as it was saved', () async {
    final accountId = await db.insert(
      Account.table,
      const Account(name: 'Bank'),
    );
    final entry = Entry(
      accountId: accountId,
      type: EntryType.expense,
      amount: 1990,
      date: DateTime(2026, 2, 3),
      note: 'Lunch',
    );
    final id = await db.insert(Entry.table, entry);
    final saved = await db.getById(Entry.table, id, Entry.fromMap);
    expect(saved, isNotNull);
    expect(saved!.date, DateTime(2026, 2, 3));
    expect(saved.note, 'Lunch');
    expect(saved.signedAmount, -1990);
    expect(saved.opening, isFalse);

    final opening = await addEntry(
      accountId,
      EntryType.expense,
      500,
      opening: true,
    );
    expect(
      (await db.getById(Entry.table, opening, Entry.fromMap))!.opening,
      isTrue,
    );
  });

  test('balance: the entries, the opening one too', () async {
    final user = await db.insertProfile(const Profile());
    final other = await db.insertProfile(const Profile());
    final wallet = await db.insert(
      Account.table,
      Account(userId: user, name: 'Wallet'),
    );
    final empty = await db.insert(
      Account.table,
      Account(userId: user, name: 'Empty'),
    );
    final overdrawn = await db.insert(
      Account.table,
      Account(userId: user, name: 'Overdrawn'),
    );
    final notMine = await db.insert(
      Account.table,
      Account(userId: other, name: 'Not mine'),
    );
    await addEntry(wallet, EntryType.income, 1000, opening: true);
    await addEntry(wallet, EntryType.income, 500);
    await addEntry(wallet, EntryType.expense, 200);
    await addEntry(overdrawn, EntryType.expense, 42, opening: true);
    await addEntry(notMine, EntryType.income, 7, opening: true);

    expect(await db.accountBalances(user), {
      wallet: 1300,
      empty: 0,
      overdrawn: -42,
    });
    expect(await db.entryCount(wallet), 3);
  });

  test('deleting an account deletes its entries', () async {
    final keep = await db.insert(Account.table, const Account(name: 'Keep'));
    final gone = await db.insert(Account.table, const Account(name: 'Gone'));
    await addEntry(keep, EntryType.income, 1);
    await addEntry(gone, EntryType.income, 2);

    await db.delete(Account.table, gone);
    final entries = await db.getAll(Entry.table, Entry.fromMap);
    expect(entries.map((e) => e.accountId), [keep]);
  });

  test('deleting a category keeps its entries without category', () async {
    final account = await db.insert(Account.table, const Account(name: 'A'));
    final category = await db.insert(
      EntryCategory.table,
      const EntryCategory(name: 'Mine', type: EntryType.expense),
    );
    final entry = await addEntry(
      account,
      EntryType.expense,
      5,
      categoryId: category,
    );

    await db.delete(EntryCategory.table, category);
    final saved = await db.getById(Entry.table, entry, Entry.fromMap);
    expect(saved!.categoryId, isNull);
  });

  test('an amount of zero is refused', () async {
    final account = await db.insert(Account.table, const Account(name: 'A'));
    expect(addEntry(account, EntryType.income, 0), throwsA(anything));
  });

  group('backup', () {
    late TestDatabase otherDb;

    setUp(() async => otherDb = await TestDatabase.create());
    tearDown(() => otherDb.dispose());

    test('restoring a backup replaces every user and their data', () async {
      final user = await db.insertProfile(const Profile(name: 'Kiss Anna'));
      await db.insert(Account.table, Account(userId: user, name: 'Wallet'));
      final bytes = await db.backup();

      final other = otherDb.datasource;
      await other.insertProfile(const Profile(name: 'Replaced'));
      await other.restore(bytes);

      final profiles = await other.getAll(Profile.table, Profile.fromMap);
      expect(profiles.map((p) => p.name), ['Kiss Anna']);
      final accounts = await other.getAll(Account.table, Account.fromMap);
      expect(accounts.single.name, 'Wallet');
      // The replaced database is kept next to it.
      expect(File('${otherDb.path}.previous').existsSync(), isTrue);
    });

    test('a file that is not a Fineva database is refused', () async {
      await db.insertProfile(const Profile(name: 'Kept'));
      await expectLater(
        db.restore(Uint8List.fromList(utf8.encode('not a database'))),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.invalid,
          ),
        ),
      );
      final profiles = await db.getAll(Profile.table, Profile.fromMap);
      expect(profiles.single.name, 'Kept');
    });

    test('a backup of a newer version is refused', () async {
      final newer = await otherDb.datasource.database;
      await newer.execute(
        'PRAGMA user_version = ${FinanceDatasource.schemaVersion + 1}',
      );
      final bytes = await otherDb.datasource.backup();

      await expectLater(
        db.restore(bytes),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.newer,
          ),
        ),
      );
    });
  });
}
