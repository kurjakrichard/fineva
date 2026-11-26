import 'package:fineva/data/data_export.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_database.dart';

void main() {
  late TestDatabase testDb;

  setUp(() async => testDb = await TestDatabase.create());
  tearDown(() => testDb.dispose());

  // A database of an old [version], made by [create].
  Future<void> oldDatabase(
    int version,
    Future<void> Function(Database db) create,
  ) async {
    final old = await testDatabaseFactory.openDatabase(
      testDb.path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, version) => create(db),
      ),
    );
    await old.close();
  }

  Future<void> createVersion1(Database db) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        currency TEXT NOT NULL,
        initial_balance INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        color INTEGER NOT NULL,
        system_key TEXT
      )''');
    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL
          REFERENCES accounts(id) ON DELETE CASCADE,
        category_id INTEGER
          REFERENCES categories(id) ON DELETE SET NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK (amount > 0),
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');
    await db.insert('categories', {
      'name': 'Food',
      'type': 'expense',
      'color': 0xFFF4511E,
      'system_key': 'food',
    });
  }

  Future<int> version(FinanceDatasource db) async {
    final rows = await (await db.database).rawQuery('PRAGMA user_version');
    return rows.first.values.first! as int;
  }

  test('version 1 data without a profile gets a user of its own', () async {
    await oldDatabase(1, (db) async {
      await createVersion1(db);
      final account = await db.insert('accounts', {
        'name': 'Old',
        'type': 'cash',
        'currency': 'HUF',
        'initial_balance': 7,
      });
      await db.insert('entries', {
        'account_id': account,
        'category_id': 1,
        'type': 'expense',
        'amount': 5,
        'date': '2026-01-02',
      });
    });

    final db = testDb.datasource;
    expect(await version(db), FinanceDatasource.schemaVersion);

    final user = (await db.getAll(Profile.table, Profile.fromMap)).single;
    expect(user.name, '');
    expect(user.userType, UserType.personal);
    final account = (await db.getAll(Account.table, Account.fromMap)).single;
    expect(account.name, 'Old');
    expect(account.userId, user.id);
    final categories = await db.getAll(
      EntryCategory.table,
      EntryCategory.fromMap,
    );
    final category = categories.singleWhere((c) => c.systemKey == 'food');
    expect(category.userId, user.id);
    // Version 8: personal, its icon; the business taxes category added.
    expect(category.scope, CategoryScope.personal);
    expect(category.icon, 'shopping_cart');
    final taxes = categories.singleWhere((c) => c.systemKey == 'businessTaxes');
    expect(taxes.scope, CategoryScope.business);
    expect(taxes.userId, user.id);
    final entries = await db.getAll(Entry.table, Entry.fromMap);
    final entry = entries.singleWhere((e) => !e.opening);
    expect(entry.categoryId, category.id);
    // Version 11: the opening balance is an entry, on the first entry's day.
    final opening = entries.singleWhere((e) => e.opening);
    expect(opening.signedAmount, 7);
    expect(opening.date, DateTime(2026, 1, 2));
    expect(opening.categoryId, isNull);
    final old = await (await db.database).rawQuery(
      'SELECT initial_balance FROM accounts',
    );
    expect(old.single['initial_balance'], 0);
    expect(await db.accountBalances(user.id!), {account.id: 2});
  });

  test(
    'an overdrawn opening balance without entries: an expense today',
    () async {
      await oldDatabase(1, (db) async {
        await createVersion1(db);
        await db.insert('accounts', {
          'name': 'Card',
          'type': 'card',
          'currency': 'HUF',
          'initial_balance': -500,
        });
        await db.insert('accounts', {
          'name': 'Zero',
          'type': 'cash',
          'currency': 'HUF',
        });
      });
      final db = testDb.datasource;
      final opening = (await db.getAll(Entry.table, Entry.fromMap)).single;
      expect(opening.opening, isTrue);
      expect(opening.type, EntryType.expense);
      expect(opening.amount, 500);
      final now = DateTime.now();
      expect(opening.date, DateTime(now.year, now.month, now.day));
    },
  );

  test("version 12: an entry's old HUF rate becomes its rate", () async {
    // Only what version 12 changes is needed: version 11 entries; and
    // what the later steps read: the users and the categories' user.
    await oldDatabase(11, (db) async {
      await createVersion1(db);
      await db.execute('ALTER TABLE entries ADD COLUMN exchange_rate INTEGER');
      await db.execute(
        'CREATE TABLE profiles (id INTEGER PRIMARY KEY, user_type TEXT)',
      );
      await db.execute('ALTER TABLE categories ADD COLUMN user_id INTEGER');
      await db.execute(
        'CREATE TABLE invoices (id INTEGER PRIMARY KEY, user_id INTEGER, '
        'direction TEXT, number TEXT, fulfillment_date TEXT, '
        'paid_date TEXT, paid_amount INTEGER, payment_method TEXT)',
      );
      final account = await db.insert('accounts', {
        'name': 'Euro',
        'type': 'bank',
        'currency': 'EUR',
      });
      for (final rate in [3860700, null]) {
        await db.insert('entries', {
          'account_id': account,
          'type': 'income',
          'amount': 100,
          'date': '2026-03-04',
          'exchange_rate': rate,
        });
      }
    });
    final entries = await testDb.datasource.getAll(
      Entry.table,
      Entry.fromMap,
      orderBy: 'id',
    );
    expect(entries.map((e) => e.rate), [386.07, null]);
    expect(entries.first.exchangeRate, 3860700);
    expect(entries.first.rateSource, isNull);
  });

  test('a version 1 database without data has no user yet', () async {
    await oldDatabase(1, createVersion1);

    final db = testDb.datasource;
    expect(await version(db), FinanceDatasource.schemaVersion);
    expect(await db.getAll(Profile.table, Profile.fromMap), isEmpty);
    // The new user's built-in categories come with the user.
    expect(
      await db.getAll(EntryCategory.table, EntryCategory.fromMap),
      isEmpty,
    );
  });

  test('the version 3 profile becomes the first user with the data', () async {
    await oldDatabase(3, (db) async {
      await createVersion1(db);
      await db.execute('''
        CREATE TABLE profile (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          user_type TEXT NOT NULL,
          tax_regime TEXT NOT NULL,
          vat_status TEXT NOT NULL,
          eu_reporting INTEGER NOT NULL DEFAULT 0,
          name TEXT NOT NULL DEFAULT '',
          address TEXT NOT NULL DEFAULT '',
          tax_id TEXT NOT NULL DEFAULT '',
          tax_number TEXT NOT NULL DEFAULT ''
        )''');
      await db.insert('profile', {
        'id': 1,
        'user_type': 'soleProprietor',
        'tax_regime': 'kata',
        'vat_status': 'registered',
        'eu_reporting': 1,
        'name': 'Kiss Anna',
        'tax_number': '10773381-2-44',
      });
      await db.insert('accounts', {
        'name': 'Bank',
        'type': 'bank',
        'currency': 'EUR',
      });
    });

    final db = testDb.datasource;
    expect(await version(db), FinanceDatasource.schemaVersion);
    final user = (await db.getAll(Profile.table, Profile.fromMap)).single;
    expect(
      user,
      const Profile(
        id: 1,
        name: 'Kiss Anna',
        taxNumber: '10773381-2-44',
        userType: UserType.soleProprietor,
        taxRegime: TaxRegime.kata,
        vatStatus: VatStatus.registered,
        euReporting: true,
      ),
    );
    final account = (await db.getAll(Account.table, Account.fromMap)).single;
    expect(account.userId, 1);

    // More users can be added now.
    final second = await db.insertProfile(const Profile(name: 'Nagy Béla'));
    expect(second, 2);
  });

  test('version 15: what users have had is given, so they get only the '
      'categories added later', () async {
    // A version 14 database: today's without what version 15 adds.
    final first = testDb.datasource;
    final anna = await first.insertProfile(const Profile(name: 'Anna'));
    final bela = await first.insertProfile(
      const Profile(name: 'Béla', userType: UserType.soleProprietor),
    );
    await first.addBuiltIns(bela, BuiltInSet.itemized);
    final cili = await first.insertProfile(
      const Profile(name: 'Cili', userType: UserType.soleProprietor),
    );
    // Anna deleted Food and renamed Housing.
    final annas = await first.getAll(
      EntryCategory.table,
      EntryCategory.fromMap,
      where: 'user_id = ?',
      whereArgs: [anna],
    );
    final food = annas.firstWhere((c) => c.systemKey == 'food');
    await first.delete(EntryCategory.table, food.id!);
    final housing = annas.firstWhere((c) => c.systemKey == 'housing');
    await first.update(EntryCategory.table, housing.copyWith(name: 'Rent'));
    final raw = await first.database;
    await raw.execute('DROP TABLE ${FinanceDatasource.givenCategoriesTable}');
    // Nor what versions 16 and 17 add (17: a column of the payments).
    await raw.execute('DROP TABLE ${InvoicePayment.table}');
    await raw.execute(
      'ALTER TABLE ${Profile.table} DROP COLUMN rate_source_reported',
    );
    await raw.execute('PRAGMA user_version = 14');
    await first.close();

    // Opened with new categories in the file.
    BuiltInCategory added(String key, BuiltInSet set) => BuiltInCategory(
      set: set,
      names: {'en': key},
      category: EntryCategory(
        name: key,
        type: EntryType.expense,
        systemKey: key,
        scope: CategoryScope.business,
      ),
    );
    final db = FinanceDatasource(
      path: testDb.path,
      factory: testDatabaseFactory,
      builtIns: BuiltInCategories([
        ...BuiltInCategories.current.all,
        added('gifts', BuiltInSet.personal),
        added('bizNew', BuiltInSet.business),
        added('bizItemizedNew', BuiltInSet.itemized),
      ]),
    );
    expect(await version(db), FinanceDatasource.schemaVersion);
    Future<List<String?>> keys(int user) async => [
      for (final c in await db.getAll(
        EntryCategory.table,
        EntryCategory.fromMap,
        where: 'user_id = ?',
        whereArgs: [user],
      ))
        c.systemKey,
    ];
    final annaKeys = await keys(anna);
    expect(annaKeys, isNot(contains('food')));
    expect(annaKeys, isNot(contains('housing')));
    expect(annaKeys.where((k) => k == 'gifts'), hasLength(1));
    expect(annaKeys, hasLength(10));
    expect(await keys(bela), containsAll(['bizNew', 'bizItemizedNew']));
    expect(await keys(bela), hasLength(3 + 11 + 2));
    final ciliKeys = await keys(cili);
    expect(ciliKeys, contains('bizNew'));
    expect(ciliKeys, isNot(contains('bizItemizedNew')));
    await db.close();
  });

  test("version 16: an invoice's payment becomes its first payment; no "
      'one has reported the MNB or the ECB yet', () async {
    // A version 15 database: today's without what version 16 adds.
    final first = testDb.datasource;
    final user = await first.insertProfile(
      const Profile(name: 'EV', userType: UserType.soleProprietor),
    );
    Invoice sale(String number) => Invoice(
      userId: user,
      direction: InvoiceDirection.outgoing,
      number: number,
      paymentMethod: PaymentMethod.cash,
      issueDate: DateTime(2026, 3),
      fulfillmentDate: DateTime(2026, 3),
      netAmount: 100000,
      vatCode: VatCode.aam,
    );
    final paid = await first.saveInvoice(sale('A-1'), const []);
    final open = await first.saveInvoice(sale('A-2'), const []);
    final raw = await first.database;
    await raw.execute('DROP TABLE ${InvoicePayment.table}');
    await raw.execute(
      'ALTER TABLE ${Profile.table} DROP COLUMN rate_source_reported',
    );
    // Partly paid the version 15 way.
    await raw.update(
      Invoice.table,
      {'paid_date': '2026-03-10', 'paid_amount': 40000},
      where: 'id = ?',
      whereArgs: [paid],
    );
    await raw.execute('PRAGMA user_version = 15');
    await first.close();

    final db = FinanceDatasource(
      path: testDb.path,
      factory: testDatabaseFactory,
    );
    expect(await version(db), FinanceDatasource.schemaVersion);
    final payment = (await db.getPayments(user)).single;
    expect(payment.invoiceId, paid);
    expect(payment.date, DateTime(2026, 3, 10));
    expect(payment.amount, 40000);
    expect(payment.method, PaymentMethod.cash);
    final invoices = await FinanceRepositoryImpl(db).getInvoices(user);
    expect(invoices.firstWhere((i) => i.id == paid).openAmount, 60000);
    expect(invoices.firstWhere((i) => i.id == open).payments, isEmpty);
    final profile = (await db.getAll(Profile.table, Profile.fromMap)).single;
    expect(profile.rateSourceReported, isFalse);
    // Their own bank's rates, typed in.
    expect(profile.rateSourceInUse, RateSource.manual);
    await db.close();
  });

  test("version 17: the revenue record's sorszám stored, in date order, "
      'each year apart; an incoming invoice has none', () async {
    final first = testDb.datasource;
    final user = await first.insertProfile(
      const Profile(name: 'EV', userType: UserType.soleProprietor),
    );
    Invoice invoice(
      String number,
      DateTime paid, {
      InvoiceDirection direction = InvoiceDirection.outgoing,
    }) => Invoice(
      userId: user,
      direction: direction,
      number: number,
      issueDate: DateTime(paid.year, paid.month),
      fulfillmentDate: DateTime(paid.year, paid.month),
      netAmount: 1000,
      vatCode: VatCode.aam,
      payments: [InvoicePayment(date: paid, amount: 1000)],
    );
    // Recorded in another order than received.
    for (final i in [
      invoice('A-3', DateTime(2026, 3, 9)),
      invoice('A-1', DateTime(2026, 1, 9)),
      invoice(
        'B-1',
        DateTime(2026, 2, 1),
        direction: InvoiceDirection.incoming,
      ),
      invoice('A-2', DateTime(2026, 2, 9)),
      invoice('Z-1', DateTime(2025, 12, 9)),
    ]) {
      await first.saveInvoice(i, const []);
    }
    // A version 16 database: without the numbers.
    final raw = await first.database;
    await raw.execute(
      'ALTER TABLE ${InvoicePayment.table} DROP COLUMN record_number',
    );
    await raw.execute('PRAGMA user_version = 16');
    await first.close();

    final db = FinanceDatasource(
      path: testDb.path,
      factory: testDatabaseFactory,
    );
    expect(await version(db), FinanceDatasource.schemaVersion);
    final invoices = await FinanceRepositoryImpl(db).getInvoices(user);
    int? number(String invoice) => invoices
        .firstWhere((i) => i.number == invoice)
        .payments
        .single
        .recordNumber;
    expect(
      [
        for (final n in ['A-1', 'A-2', 'A-3', 'Z-1', 'B-1']) number(n),
      ],
      [1, 2, 3, 1, null],
    );
    await db.close();
  });
}
