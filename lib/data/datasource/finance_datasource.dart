import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart'
    show applyWorkaroundToOpenSqlite3OnOldAndroidVersions;

import '../../utils/utils.dart';
import '../built_in_categories.dart';
import '../models/models.dart';

/// Why a file can't be restored (see [FinanceDatasource.restore]).
enum BackupError {
  /// Not a Fineva database, or a damaged one.
  invalid,

  /// Made by a newer Fineva, with a schema this one doesn't know.
  newer,
}

class BackupException implements Exception {
  const BackupException(this.error, [this.cause]);

  final BackupError error;
  final Object? cause;

  @override
  String toString() => 'BackupException(${error.name}, $cause)';
}

/// The app's sqlite database ([dbName] in the app support folder).
///
/// The generic functions ([getAll], [getById], [insert], [update], [delete])
/// work on any table through the models (see [DbModel]); only what a single
/// model can't express (e.g. [accountBalances], [insertProfile]) is written
/// out.
///
/// Opened through the sqflite_common_ffi factory with the sqlite bundled by
/// sqlite3_flutter_libs on every platform, like in calibre_touch.
class FinanceDatasource {
  /// [path] and [factory] are only set by tests; [builtIns] by tests and
  /// the seeder ([BuiltInCategories.current] if not).
  FinanceDatasource({this._path, this._factory, BuiltInCategories? builtIns})
    : _builtInsGiven = builtIns;

  /// Version of the schema. Raising it needs the matching step in
  /// [_upgradeSchema].
  static const int schemaVersion = 17;

  /// Tables every Fineva database has had since version 1.
  static const List<String> _tables = [
    Account.table,
    EntryCategory.table,
    Entry.table,
  ];

  String? _path;
  final DatabaseFactory? _factory;
  final BuiltInCategories? _builtInsGiven;

  BuiltInCategories get _builtIns =>
      _builtInsGiven ?? BuiltInCategories.current;
  Future<Database>? _dbFuture;

  Future<Database> get database =>
      // A failed open is not cached: the next call tries again.
      _dbFuture ??= _open().then(
        (db) => db,
        onError: (Object e, StackTrace st) {
          _dbFuture = null;
          Error.throwWithStackTrace(e, st);
        },
      );

  /// The database file.
  Future<String> get path async {
    final path = _path;
    if (path != null) return path;
    final dir = await getApplicationSupportDirectory();
    await Directory(dir.path).create(recursive: true);
    return _path = join(dir.path, dbName);
  }

  Future<DatabaseFactory> _databaseFactory() async {
    final factory = _factory;
    if (factory != null) return factory;
    if (Platform.isAndroid) {
      // Needed on some old Android devices to load the bundled sqlite.
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }

  Future<Database> _open() async {
    final factory = await _databaseFactory();
    return factory.openDatabase(
      await path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _createSchema(db),
        onUpgrade: _upgradeSchema,
        // Every user gets the new built-in categories of their sets.
        onOpen: (db) => db.transaction(_giveNewBuiltIns),
      ),
    );
  }

  Future<void> close() async {
    final db = _dbFuture;
    _dbFuture = null;
    if (db == null) return;
    try {
      await (await db).close();
    } catch (_) {
      // It was never opened.
    }
  }

  // ---- Schema ----

  // A new database gets the tables of version 1, then every upgrade step,
  // so it has exactly the schema of an upgraded one.
  static Future<void> _createSchema(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE ${Account.table} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          currency TEXT NOT NULL,
          initial_balance INTEGER NOT NULL DEFAULT 0
        )''')
      ..execute('''
        CREATE TABLE ${EntryCategory.table} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          color INTEGER NOT NULL,
          system_key TEXT
        )''')
      ..execute('''
        CREATE TABLE ${Entry.table} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL
            REFERENCES ${Account.table}(id) ON DELETE CASCADE,
          category_id INTEGER
            REFERENCES ${EntryCategory.table}(id) ON DELETE SET NULL,
          type TEXT NOT NULL,
          amount INTEGER NOT NULL CHECK (amount > 0),
          date TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT ''
        )''')
      ..execute('CREATE INDEX entries_date_idx ON ${Entry.table} (date)')
      ..execute(
        'CREATE INDEX entries_account_idx ON ${Entry.table} (account_id)',
      );
    await batch.commit(noResult: true);
    await _upgradeSchema(db, 1, schemaVersion);
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // One step per version, so any old database reaches the current one.
    final steps = [
      if (oldVersion < 2) ..._v2,
      if (oldVersion < 3) ..._v3,
      if (oldVersion < 4) ..._v4,
      if (oldVersion < 5) ..._v5,
      if (oldVersion < 6) ..._v6,
      if (oldVersion < 7) ..._v7,
      if (oldVersion < 8) ..._v8,
      if (oldVersion < 9) ..._v9,
      if (oldVersion < 10) ..._v10,
      if (oldVersion < 11) ..._v11,
      if (oldVersion < 12) ..._v12,
      if (oldVersion < 13) ..._v13,
      if (oldVersion < 14) ..._v14,
      if (oldVersion < 15) ..._v15,
      if (oldVersion < 16) ..._v16,
      if (oldVersion < 17) ..._v17,
    ];
    for (final sql in steps) {
      await db.execute(sql);
    }
  }

  // Version 2: the profile of the only user (one row, id 1).
  static const List<String> _v2 = [
    '''
    CREATE TABLE profile (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      user_type TEXT NOT NULL,
      tax_regime TEXT NOT NULL,
      vat_status TEXT NOT NULL,
      eu_reporting INTEGER NOT NULL DEFAULT 0
    )''',
  ];

  // Version 3: the user's name, address and tax identifiers.
  static const List<String> _v3 = [
    "ALTER TABLE profile ADD COLUMN name TEXT NOT NULL DEFAULT ''",
    "ALTER TABLE profile ADD COLUMN address TEXT NOT NULL DEFAULT ''",
    "ALTER TABLE profile ADD COLUMN tax_id TEXT NOT NULL DEFAULT ''",
    "ALTER TABLE profile ADD COLUMN tax_number TEXT NOT NULL DEFAULT ''",
  ];

  // Version 4: several users, each with their own accounts and categories.
  // The existing data goes to the first user. (user_id can only be added as
  // a nullable column: a NOT NULL one would need a rebuilt table, and
  // dropping a table with foreign keys on deletes its entries.)
  static const List<String> _v4 = [
    '''
    CREATE TABLE ${Profile.table} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      tax_id TEXT NOT NULL DEFAULT '',
      tax_number TEXT NOT NULL DEFAULT '',
      user_type TEXT NOT NULL,
      tax_regime TEXT NOT NULL,
      vat_status TEXT NOT NULL,
      eu_reporting INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    INSERT INTO ${Profile.table} (id, name, address, tax_id, tax_number,
      user_type, tax_regime, vat_status, eu_reporting)
    SELECT id, name, address, tax_id, tax_number,
      user_type, tax_regime, vat_status, eu_reporting
    FROM profile''',
    // Accounts from before the onboarding (version 1) get a user too.
    '''
    INSERT INTO ${Profile.table} (user_type, tax_regime, vat_status)
    SELECT 'personal', 'flatRate', 'exempt'
    WHERE NOT EXISTS (SELECT * FROM ${Profile.table})
      AND EXISTS (SELECT * FROM ${Account.table})''',
    'DROP TABLE profile',
    'ALTER TABLE ${Account.table} ADD COLUMN user_id INTEGER '
        'REFERENCES ${Profile.table}(id) ON DELETE CASCADE',
    'ALTER TABLE ${EntryCategory.table} ADD COLUMN user_id INTEGER '
        'REFERENCES ${Profile.table}(id) ON DELETE CASCADE',
    'UPDATE ${Account.table} SET user_id = (SELECT MIN(id) FROM ${Profile.table})',
    'UPDATE ${EntryCategory.table} '
        'SET user_id = (SELECT MIN(id) FROM ${Profile.table})',
    // No user yet: every new user gets the built-in categories.
    'DELETE FROM ${EntryCategory.table} WHERE user_id IS NULL',
    'CREATE INDEX accounts_user_idx ON ${Account.table} (user_id)',
    'CREATE INDEX categories_user_idx ON ${EntryCategory.table} (user_id)',
  ];

  // Version 5: the EU VAT number (közösségi adószám) for EU reporting.
  static const List<String> _v5 = [
    "ALTER TABLE ${Profile.table} ADD COLUMN eu_vat_number TEXT NOT NULL "
        "DEFAULT ''",
  ];

  // Version 6: the sole proprietors' invoices, VAT period and flat-rate
  // taxation settings.
  static const List<String> _v6 = [
    "ALTER TABLE ${Profile.table} ADD COLUMN vat_period TEXT NOT NULL "
        "DEFAULT 'quarterly'",
    'ALTER TABLE ${Profile.table} ADD COLUMN cost_ratio INTEGER NOT NULL '
        'DEFAULT 45',
    'ALTER TABLE ${Profile.table} ADD COLUMN main_occupation INTEGER '
        'NOT NULL DEFAULT 1',
    '''
    CREATE TABLE ${Invoice.table} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL
        REFERENCES ${Profile.table}(id) ON DELETE CASCADE,
      direction TEXT NOT NULL,
      number TEXT NOT NULL DEFAULT '',
      description TEXT NOT NULL DEFAULT '',
      partner_name TEXT NOT NULL DEFAULT '',
      partner_tax_number TEXT NOT NULL DEFAULT '',
      partner_location TEXT NOT NULL,
      payment_method TEXT NOT NULL,
      issue_date TEXT NOT NULL,
      fulfillment_date TEXT NOT NULL,
      due_date TEXT,
      currency TEXT NOT NULL,
      exchange_rate INTEGER NOT NULL CHECK (exchange_rate > 0),
      net_amount INTEGER NOT NULL,
      vat_code TEXT NOT NULL,
      vat_amount INTEGER NOT NULL DEFAULT 0,
      paid_date TEXT,
      paid_amount INTEGER NOT NULL DEFAULT 0
    )''',
    'CREATE INDEX invoices_user_idx ON ${Invoice.table} (user_id)',
  ];

  // Version 7: itemized taxation (vállalkozói SZJA): the tax treatment of
  // the categories, exchange rates of foreign currency entries, assets.
  static const List<String> _v7 = [
    "ALTER TABLE ${EntryCategory.table} ADD COLUMN tax_treatment TEXT "
        "NOT NULL DEFAULT 'none'",
    'ALTER TABLE ${Entry.table} ADD COLUMN exchange_rate INTEGER',
    '''
    CREATE TABLE ${Asset.table} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL
        REFERENCES ${Profile.table}(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      purchase_date TEXT NOT NULL,
      invoice_number TEXT NOT NULL DEFAULT '',
      supplier TEXT NOT NULL DEFAULT '',
      amount INTEGER NOT NULL CHECK (amount > 0),
      rate INTEGER NOT NULL CHECK (rate > 0)
    )''',
    'CREATE INDEX assets_user_idx ON ${Asset.table} (user_id)',
  ];

  // Version 8: the categories' scope (personal or business: only the
  // current user's kind is shown) and icon; the business "taxes" category
  // for every user.
  static const List<String> _v8 = [
    "ALTER TABLE ${EntryCategory.table} ADD COLUMN scope TEXT NOT NULL "
        "DEFAULT 'personal'",
    'ALTER TABLE ${EntryCategory.table} ADD COLUMN icon TEXT',
    '''
    UPDATE ${EntryCategory.table} SET scope = 'business'
    WHERE system_key IN ('businessIncome', 'businessExpense')
      OR tax_treatment != 'none'
    ''',
    '''
    UPDATE ${EntryCategory.table} SET icon = CASE system_key
        WHEN 'salary' THEN 'work'
        WHEN 'otherIncome' THEN 'redeem'
        WHEN 'food' THEN 'shopping_cart'
        WHEN 'housing' THEN 'home'
        WHEN 'utilities' THEN 'bolt'
        WHEN 'transport' THEN 'directions_bus'
        WHEN 'health' THEN 'local_hospital'
        WHEN 'entertainment' THEN 'theaters'
        WHEN 'taxes' THEN 'account_balance'
        WHEN 'otherExpense' THEN 'more_horiz'
        WHEN 'businessIncome' THEN 'storefront'
        WHEN 'businessExpense' THEN 'business_center'
        WHEN 'businessTaxes' THEN 'account_balance'
        WHEN 'bizRevenue' THEN 'trending_up'
        WHEN 'bizNonTaxableIncome' THEN 'login'
        WHEN 'bizWithdrawal' THEN 'payments'
        WHEN 'bizSzocho' THEN 'health_and_safety'
        WHEN 'bizOther' THEN 'receipt_long'
        WHEN 'bizMaterial' THEN 'inventory'
        WHEN 'bizBank' THEN 'credit_card'
        WHEN 'bizAccounting' THEN 'calculate'
        WHEN 'bizIt' THEN 'computer'
        WHEN 'bizNonDeductible' THEN 'block'
        WHEN 'bizVat' THEN 'percent'
      END
    WHERE system_key IS NOT NULL''',
    '''
    INSERT INTO ${EntryCategory.table}
      (user_id, name, type, color, system_key, tax_treatment, scope, icon)
    SELECT p.id, 'Taxes and contributions', 'expense', 4292352864,
      'businessTaxes', 'none', 'business', 'account_balance'
    FROM ${Profile.table} p
    WHERE NOT EXISTS (
      SELECT * FROM ${EntryCategory.table} c
      WHERE c.user_id = p.id AND c.system_key = 'businessTaxes')''',
  ];

  // Version 9: the payment of an invoice is booked as entries on an
  // account, in a category, at the payment's exchange rate.
  static const List<String> _v9 = [
    'ALTER TABLE ${Invoice.table} ADD COLUMN paid_account_id INTEGER '
        'REFERENCES ${Account.table}(id) ON DELETE SET NULL',
    'ALTER TABLE ${Invoice.table} ADD COLUMN paid_exchange_rate INTEGER',
    'ALTER TABLE ${Invoice.table} ADD COLUMN category_id INTEGER '
        'REFERENCES ${EntryCategory.table}(id) ON DELETE SET NULL',
    'ALTER TABLE ${Entry.table} ADD COLUMN invoice_id INTEGER '
        'REFERENCES ${Invoice.table}(id) ON DELETE CASCADE',
    'CREATE INDEX entries_invoice_idx ON ${Entry.table} (invoice_id)',
  ];

  /// Version 10: every user's main currency and rate source; the exchange
  /// rates (shared by the users).
  static const List<String> _v10 = [
    "ALTER TABLE ${Profile.table} ADD COLUMN main_currency TEXT NOT NULL "
        "DEFAULT 'HUF'",
    "ALTER TABLE ${Profile.table} ADD COLUMN rate_source TEXT NOT NULL "
        "DEFAULT 'mnb'",
    '''
    CREATE TABLE ${ExchangeRate.table} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source TEXT NOT NULL,
      date TEXT NOT NULL,
      currency TEXT NOT NULL,
      base TEXT NOT NULL,
      rate REAL NOT NULL CHECK (rate > 0),
      UNIQUE (source, currency, base, date)
    )''',
  ];

  /// Version 11: the opening balance is an entry (`opening`), so it can be
  /// deleted like the others, and an account only without entries. Each
  /// account's old opening balance becomes one, on the day of its first
  /// entry (today if it has none); the column stays, at 0.
  static const List<String> _v11 = [
    'ALTER TABLE ${Entry.table} ADD COLUMN opening INTEGER NOT NULL '
        'DEFAULT 0',
    '''
    INSERT INTO ${Entry.table} (account_id, type, amount, date, opening)
    SELECT a.id,
           CASE WHEN a.initial_balance > 0 THEN 'income' ELSE 'expense' END,
           ABS(a.initial_balance),
           COALESCE(
             (SELECT MIN(e.date) FROM ${Entry.table} e
              WHERE e.account_id = a.id),
             date('now', 'localtime')),
           1
    FROM ${Account.table} a
    WHERE a.initial_balance != 0''',
    'UPDATE ${Account.table} SET initial_balance = 0',
  ];

  /// Version 12: an entry's rate in the user's main currency, as a double
  /// (a weak currency's rate needs more digits than the old HUF rate times
  /// 10000), and where it came from. The old `exchange_rate` (HUF, a sole
  /// proprietor's main currency) is copied; the column stays, unused.
  static const List<String> _v12 = [
    'ALTER TABLE ${Entry.table} ADD COLUMN rate REAL',
    'ALTER TABLE ${Entry.table} ADD COLUMN rate_source TEXT',
    'UPDATE ${Entry.table} SET rate = exchange_rate / $exchangeRateScale.0 '
        'WHERE exchange_rate IS NOT NULL',
  ];

  /// Version 13: transfers between a user's accounts; their two sides are
  /// entries, deleted with the transfer.
  static const List<String> _v13 = [
    '''
    CREATE TABLE $transfersTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL
        REFERENCES ${Profile.table}(id) ON DELETE CASCADE
    )''',
    'ALTER TABLE ${Entry.table} ADD COLUMN transfer_id INTEGER '
        'REFERENCES $transfersTable(id) ON DELETE CASCADE',
    'CREATE INDEX entries_transfer_idx ON ${Entry.table} (transfer_id)',
  ];

  /// Version 14: an account's optional details (description, account
  /// number, SWIFT) and its closing day.
  static const List<String> _v14 = [
    "ALTER TABLE ${Account.table} ADD COLUMN description TEXT NOT NULL "
        "DEFAULT ''",
    "ALTER TABLE ${Account.table} ADD COLUMN bank_account TEXT NOT NULL "
        "DEFAULT ''",
    "ALTER TABLE ${Account.table} ADD COLUMN swift TEXT NOT NULL DEFAULT ''",
    'ALTER TABLE ${Account.table} ADD COLUMN closed_date TEXT',
  ];

  /// Version 15: the built-in categories (since then from
  /// assets/categories.json, see [BuiltInCategories]) each user has been
  /// given, so at every start they get the new ones of their sets once,
  /// and one they deleted doesn't come back. Every user has been given the
  /// ones they have, and those of their kind's set as it was then (and of
  /// the itemized set if they have one of it). The keys here are frozen.
  static const List<String> _v15 = [
    '''
    CREATE TABLE $givenCategoriesTable (
      user_id INTEGER NOT NULL
        REFERENCES ${Profile.table}(id) ON DELETE CASCADE,
      key TEXT NOT NULL,
      PRIMARY KEY (user_id, key)
    )''',
    '''
    INSERT OR IGNORE INTO $givenCategoriesTable (user_id, key)
    SELECT DISTINCT user_id, system_key FROM ${EntryCategory.table}
    WHERE user_id IS NOT NULL AND system_key IS NOT NULL''',
    '''
    INSERT OR IGNORE INTO $givenCategoriesTable (user_id, key)
    SELECT p.id, k.column1
    FROM ${Profile.table} p,
      (VALUES ('salary'), ('otherIncome'), ('food'), ('housing'),
        ('utilities'), ('transport'), ('health'), ('entertainment'),
        ('taxes'), ('otherExpense')) k
    WHERE p.user_type != 'soleProprietor'
    ''',
    '''
    INSERT OR IGNORE INTO $givenCategoriesTable (user_id, key)
    SELECT p.id, k.column1
    FROM ${Profile.table} p,
      (VALUES ('businessIncome'), ('businessExpense'), ('businessTaxes')) k
    WHERE p.user_type = 'soleProprietor'
    ''',
    '''
    INSERT OR IGNORE INTO $givenCategoriesTable (user_id, key)
    SELECT p.id, k.column1
    FROM ${Profile.table} p,
      (VALUES ('bizRevenue'), ('bizNonTaxableIncome'), ('bizWithdrawal'),
        ('bizSzocho'), ('bizOther'), ('bizMaterial'), ('bizBank'),
        ('bizAccounting'), ('bizIt'), ('bizNonDeductible'), ('bizVat')) k
    WHERE EXISTS (
      SELECT * FROM ${EntryCategory.table} c
      WHERE c.user_id = p.id AND c.system_key IN ('bizRevenue',
        'bizNonTaxableIncome', 'bizWithdrawal', 'bizSzocho', 'bizOther',
        'bizMaterial', 'bizBank', 'bizAccounting', 'bizIt',
        'bizNonDeductible', 'bizVat'))''',
  ];

  /// Version 16: an invoice can be paid in parts: its payments
  /// ([InvoicePayment]) instead of one paid date and amount. Each old
  /// payment becomes one, by the invoice's payment method; the old columns
  /// stay, emptied. A sole proprietor's choice of the MNB's or the ECB's
  /// rates is reported to NAV (not yet for anyone: their own bank's rate).
  static const List<String> _v16 = [
    'ALTER TABLE ${Profile.table} ADD COLUMN rate_source_reported INTEGER '
        'NOT NULL DEFAULT 0',
    '''
    CREATE TABLE ${InvoicePayment.table} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL
        REFERENCES ${Invoice.table}(id) ON DELETE CASCADE,
      date TEXT NOT NULL,
      amount INTEGER NOT NULL,
      method TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT ''
    )''',
    'CREATE INDEX payments_invoice_idx ON ${InvoicePayment.table} '
        '(invoice_id)',
    '''
    INSERT INTO ${InvoicePayment.table} (invoice_id, date, amount, method)
    SELECT id, paid_date, paid_amount, payment_method FROM ${Invoice.table}
    WHERE paid_date IS NOT NULL AND paid_amount != 0''',
    'UPDATE ${Invoice.table} SET paid_date = NULL, paid_amount = 0',
  ];

  /// Version 17: the revenue record's sorszám of each payment of an
  /// outgoing invoice (stored, in date order, see [revenueOrder]). The
  /// payments there are numbered.
  static const List<String> _v17 = [
    'ALTER TABLE ${InvoicePayment.table} ADD COLUMN record_number INTEGER',
    // The order of [revenueOrder] then, frozen here.
    '''
    UPDATE ${InvoicePayment.table} SET record_number = (
      SELECT n FROM (
        SELECT p.id AS pid, ROW_NUMBER() OVER (
          PARTITION BY i.user_id, substr(p.date, 1, 4)
          ORDER BY p.date, i.fulfillment_date, i.number, p.id) AS n
        FROM ${InvoicePayment.table} p
        JOIN ${Invoice.table} i ON i.id = p.invoice_id
        WHERE i.direction = 'outgoing')
      WHERE pid = ${InvoicePayment.table}.id)''',
  ];

  /// The order of the revenue record (the payments of a user's outgoing
  /// invoices, each year apart): by the day received, then the invoice's
  /// fulfillment and number, then as recorded. The sorszám follows it.
  static const String revenueOrder =
      'p.date, i.fulfillment_date, i.number, p.id';

  /// Every payment of the outgoing invoices ([where]: of which users) with
  /// its sorszám by [revenueOrder]: `pid`, its stored `old` one and `n`.
  static String _revenueNumbers(String where) =>
      '''
      SELECT p.id AS pid, p.record_number AS old,
        ROW_NUMBER() OVER (
          PARTITION BY i.user_id, substr(p.date, 1, 4)
          ORDER BY $revenueOrder) AS n
      FROM ${InvoicePayment.table} p
      JOIN ${Invoice.table} i ON i.id = p.invoice_id
      WHERE i.direction = '${InvoiceDirection.outgoing.name}' $where''';

  /// A transfer's id and its user; the rest is in its two entries.
  static const String transfersTable = 'transfers';

  /// The keys of the built-in categories each user has been given (see
  /// [_v15]).
  static const String givenCategoriesTable = 'given_categories';

  // ---- Generic operations ----

  /// Rows of [table] matching [where] (every row if null) as models.
  Future<List<T>> getAll<T extends DbModel>(
    String table,
    T Function(Map<String, Object?> row) fromMap, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    final rows = await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
    return rows.map(fromMap).toList();
  }

  /// The row of [table] with [id], null if there is none.
  Future<T?> getById<T extends DbModel>(
    String table,
    int id,
    T Function(Map<String, Object?> row) fromMap,
  ) async {
    final rows = await getAll(table, fromMap, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Inserts [item] into [table]; returns the new row's id.
  Future<int> insert(String table, DbModel item) async =>
      (await database).insert(table, item.toMap());

  /// Saves [item] over its row in [table] (found by its id). With [userId]
  /// only a row of that user (a table with `user_id`: an account, a
  /// category, an invoice, an asset); a StateError for another's.
  Future<int> update(String table, DbModel item, {int? userId}) async {
    final id = item.id;
    if (id == null) throw ArgumentError('Only a saved row can be updated');
    final count = await (await database).update(
      table,
      item.toMap(),
      where: userId == null ? 'id = ?' : 'id = ? AND user_id = ?',
      whereArgs: [id, ?userId],
    );
    if (userId != null && count == 0) throw _notTheirs(table, id, userId);
    return count;
  }

  static StateError _notTheirs(String table, int id, int userId) =>
      StateError('$table $id is not of user $userId');

  /// Updates the saved [items] of [table] in one transaction; returns how
  /// many.
  Future<int> updateAll(String table, List<DbModel> items) async {
    if (items.isEmpty) return 0;
    await (await database).transaction((txn) async {
      final batch = txn.batch();
      for (final item in items) {
        final id = item.id;
        if (id == null) throw ArgumentError('Only saved rows can be updated');
        batch.update(table, item.toMap(), where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    });
    return items.length;
  }

  /// Deletes the row of [table] with [id]. With [userId] only a row of
  /// that user (see [update]); a StateError for another's.
  Future<int> delete(String table, int id, {int? userId}) async {
    final count = await (await database).delete(
      table,
      where: userId == null ? 'id = ?' : 'id = ? AND user_id = ?',
      whereArgs: [id, ?userId],
    );
    if (userId != null && count == 0) throw _notTheirs(table, id, userId);
    return count;
  }

  // ---- A user's entries: through their accounts ----

  /// The ids of [userId]'s accounts, for a `WHERE account_id IN (...)`.
  static const String _usersAccounts =
      'SELECT id FROM ${Account.table} WHERE user_id = ?';

  /// A StateError unless [entry]'s account and category (if any) are
  /// [userId]'s.
  static Future<void> _checkEntry(
    DatabaseExecutor db,
    Entry entry,
    int userId,
  ) async {
    final account = await db.query(
      Account.table,
      columns: ['id'],
      where: 'id = ? AND user_id = ?',
      whereArgs: [entry.accountId, userId],
    );
    if (account.isEmpty) {
      throw _notTheirs(Account.table, entry.accountId, userId);
    }
    final category = entry.categoryId;
    if (category == null) return;
    final rows = await db.query(
      EntryCategory.table,
      columns: ['id'],
      where: 'id = ? AND user_id = ?',
      whereArgs: [category, userId],
    );
    if (rows.isEmpty) throw _notTheirs(EntryCategory.table, category, userId);
  }

  /// Saves [entry] (inserts it without id) of [userId]: on their account,
  /// in their category; a saved one only if it is theirs. Returns its id.
  Future<int> saveEntry(Entry entry, int userId) async =>
      (await database).transaction((txn) async {
        await _checkEntry(txn, entry, userId);
        final id = entry.id;
        if (id == null) return txn.insert(Entry.table, entry.toMap());
        final count = await txn.update(
          Entry.table,
          entry.toMap(),
          where: 'id = ? AND account_id IN ($_usersAccounts)',
          whereArgs: [id, userId],
        );
        if (count == 0) throw _notTheirs(Entry.table, id, userId);
        return id;
      });

  /// Deletes [userId]'s entry with [id]; a StateError for another's.
  Future<void> deleteEntry(int id, int userId) async {
    final count = await (await database).delete(
      Entry.table,
      where: 'id = ? AND account_id IN ($_usersAccounts)',
      whereArgs: [id, userId],
    );
    if (count == 0) throw _notTheirs(Entry.table, id, userId);
  }

  // ---- Users ----

  /// Inserts [profile] as a new user with the built-in categories of its
  /// kind ([BuiltInCategories.forNewUser]); returns its id.
  Future<int> insertProfile(Profile profile) async =>
      (await database).transaction((txn) async {
        final id = await txn.insert(Profile.table, profile.toMap());
        final batch = txn.batch();
        for (final category in _builtIns.forNewUser(profile.userType)) {
          _give(batch, id, category);
        }
        await batch.commit(noResult: true);
        return id;
      });

  /// Gives [userId] the built-in categories of [set] they don't have now
  /// (by key; one they deleted again).
  Future<void> addBuiltIns(int userId, BuiltInSet set) async =>
      (await database).transaction((txn) async {
        final rows = await txn.query(
          EntryCategory.table,
          columns: ['system_key'],
          where: 'user_id = ? AND system_key IS NOT NULL',
          whereArgs: [userId],
        );
        final have = {for (final row in rows) row['system_key']};
        final batch = txn.batch();
        for (final category in _builtIns.ofSet(set)) {
          if (!have.contains(category.systemKey)) {
            _give(batch, userId, category);
          }
        }
        await batch.commit(noResult: true);
      });

  /// Adds the built-in [category] to [userId]'s categories, noted as given.
  static void _give(Batch batch, int userId, EntryCategory category) {
    batch
      ..insert(EntryCategory.table, category.copyWith(userId: userId).toMap())
      ..insert(givenCategoriesTable, {
        'user_id': userId,
        'key': category.systemKey,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Gives every user the built-in categories of their sets they have never
  /// had ([BuiltInCategories.missing]): the ones added to
  /// assets/categories.json since. At every opening.
  Future<void> _giveNewBuiltIns(Transaction txn) async {
    final users = await txn.query(Profile.table, columns: ['id', 'user_type']);
    if (users.isEmpty) return;
    final given = <int, Set<String>>{};
    for (final row in await txn.query(givenCategoriesTable)) {
      (given[row['user_id']! as int] ??= {}).add(row['key']! as String);
    }
    final batch = txn.batch();
    for (final user in users) {
      final id = user['id']! as int;
      final type = UserType.values.asNameMap()[user['user_type']];
      if (type == null) continue;
      for (final category in _builtIns.missing(type, given[id] ?? const {})) {
        _give(batch, id, category);
      }
    }
    await batch.commit(noResult: true);
  }

  /// Saves [invoice] (inserts it without id) with its payments and
  /// [entries] booking them (see [saveInvoices]); returns its id.
  Future<int> saveInvoice(Invoice invoice, List<Entry> entries) async =>
      (await saveInvoices([(invoice, entries)])).single;

  /// Saves [invoices] (each inserted without id) in one transaction: each
  /// with its payments (a saved one updated, one of another invoice of the
  /// user moved here keeping its id, a new one inserted, the others
  /// deleted) and its entries booking them, replacing the entries booked
  /// before; then renumbers the revenue record ([renumber]). A payment moved
  /// to another invoice: that one first, then the one it leaves. Returns
  /// their ids. Each invoice must be its user's (`invoice.userId`), the
  /// entries on their accounts.
  Future<List<int>> saveInvoices(List<(Invoice, List<Entry>)> invoices) async =>
      (await database).transaction((txn) async {
        final ids = [
          for (final (invoice, entries) in invoices)
            await _saveInvoice(txn, invoice, entries),
        ];
        for (final userId in {for (final (i, _) in invoices) i.userId!}) {
          await renumber(txn, userId);
        }
        return ids;
      });

  static Future<int> _saveInvoice(
    Transaction txn,
    Invoice invoice,
    List<Entry> entries,
  ) async {
    final userId = invoice.userId!;
    for (final entry in entries) {
      await _checkEntry(txn, entry, userId);
    }
    var id = invoice.id;
    if (id == null) {
      id = await txn.insert(Invoice.table, invoice.toMap());
    } else {
      final count = await txn.update(
        Invoice.table,
        invoice.toMap(),
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
      if (count == 0) throw _notTheirs(Invoice.table, id, userId);
      await txn.delete(Entry.table, where: 'invoice_id = ?', whereArgs: [id]);
    }
    final saved = {
      for (final row in await txn.query(
        InvoicePayment.table,
        columns: ['id'],
        where: 'invoice_id = ?',
        whereArgs: [id],
      ))
        row['id']! as int,
    };
    final kept = {
      for (final payment in invoice.payments)
        if (saved.contains(payment.id)) payment.id!,
    };
    final gone = [
      for (final payment in saved)
        if (!kept.contains(payment)) payment,
    ];
    if (gone.isNotEmpty) {
      await txn.delete(
        InvoicePayment.table,
        where: 'id IN (${List.filled(gone.length, '?').join(', ')})',
        whereArgs: gone,
      );
    }
    for (final payment in invoice.payments) {
      final row = payment.copyWith(invoiceId: id).toMap();
      final paymentId = payment.id;
      if (kept.contains(paymentId)) {
        await txn.update(
          InvoicePayment.table,
          row,
          where: 'id = ?',
          whereArgs: [paymentId],
        );
        continue;
      }
      // One of another invoice of the user: moved here.
      final moved = paymentId == null
          ? 0
          : await txn.update(
              InvoicePayment.table,
              row,
              where:
                  'id = ? AND invoice_id IN '
                  '(SELECT id FROM ${Invoice.table} WHERE user_id = ?)',
              whereArgs: [paymentId, userId],
            );
      if (moved == 0) await txn.insert(InvoicePayment.table, row);
    }
    final batch = txn.batch();
    for (final entry in entries) {
      batch.insert(Entry.table, {...entry.toMap(), 'invoice_id': id});
    }
    await batch.commit(noResult: true);
    return id;
  }

  /// Deletes [userId]'s invoice with [id] (its payments and entries with
  /// it), then renumbers the revenue record; a StateError for another's.
  Future<void> deleteInvoice(int id, int userId) async =>
      (await database).transaction((txn) async {
        final owner = await txn.query(
          Invoice.table,
          columns: ['id'],
          where: 'id = ? AND user_id = ?',
          whereArgs: [id, userId],
        );
        if (owner.isEmpty) throw _notTheirs(Invoice.table, id, userId);
        // Its payments and entries with it (cascade).
        await txn.delete(Invoice.table, where: 'id = ?', whereArgs: [id]);
        await renumber(txn, userId);
      });

  /// Numbers [userId]'s revenue record again, each year apart, in date
  /// order ([revenueOrder]): every payment of an outgoing invoice whose
  /// sorszám isn't its place gets it, one of an incoming invoice none. The
  /// payments can be recorded in any order (bank by bank): the numbers end
  /// up right.
  static Future<void> renumber(DatabaseExecutor db, int userId) async {
    final rows = await db.rawQuery(_revenueNumbers('AND i.user_id = ?'), [
      userId,
    ]);
    for (final row in rows) {
      if (row['old'] == row['n']) continue;
      await db.update(
        InvoicePayment.table,
        {'record_number': row['n']},
        where: 'id = ?',
        whereArgs: [row['pid']],
      );
    }
    // Not in the record: an incoming invoice's (one made incoming).
    await db.rawUpdate(
      '''
      UPDATE ${InvoicePayment.table} SET record_number = NULL
      WHERE record_number IS NOT NULL AND invoice_id IN (
        SELECT id FROM ${Invoice.table} WHERE user_id = ? AND direction != ?)''',
      [userId, InvoiceDirection.outgoing.name],
    );
  }

  /// The payments of [userId]'s invoices, in the order paid.
  Future<List<InvoicePayment>> getPayments(int userId) async {
    final rows = await (await database).rawQuery(
      '''
      SELECT p.* FROM ${InvoicePayment.table} p
      JOIN ${Invoice.table} i ON i.id = p.invoice_id
      WHERE i.user_id = ?
      ORDER BY p.date, p.id''',
      [userId],
    );
    return rows.map(InvoicePayment.fromMap).toList();
  }

  /// Saves a transfer of [userId] (a new one without [id]) as its two
  /// sides, [from] and [to], in place of the ones saved before; returns its
  /// id.
  Future<int> saveTransfer(int? id, int userId, Entry from, Entry to) async =>
      (await database).transaction((txn) async {
        // Both sides on the user's accounts; a saved one theirs.
        await _checkEntry(txn, from, userId);
        await _checkEntry(txn, to, userId);
        var transferId = id;
        if (transferId == null) {
          transferId = await txn.insert(transfersTable, {'user_id': userId});
        } else {
          final theirs = await txn.query(
            transfersTable,
            where: 'id = ? AND user_id = ?',
            whereArgs: [transferId, userId],
          );
          if (theirs.isEmpty) {
            throw _notTheirs(transfersTable, transferId, userId);
          }
          await txn.delete(
            Entry.table,
            where: 'transfer_id = ?',
            whereArgs: [transferId],
          );
        }
        for (final side in [from, to]) {
          await txn.insert(Entry.table, {
            ...side.toMap(),
            'transfer_id': transferId,
          });
        }
        return transferId;
      });

  /// Deletes [userId]'s transfer with [id], both its sides; a StateError
  /// for another's.
  Future<void> deleteTransfer(int id, int userId) =>
      delete(transfersTable, id, userId: userId);

  /// Saves downloaded [rates]: a rate of the same source, currency, base
  /// and day is replaced. Returns how many.
  Future<int> saveRates(List<ExchangeRate> rates) async {
    if (rates.isEmpty) return 0;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final rate in rates) {
        batch.insert(
          ExchangeRate.table,
          rate.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
    return rates.length;
  }

  /// The last day with a rate of [source] for each currency.
  Future<Map<Currency, DateTime>> lastRateDays(RateSource source) =>
      _rateDays(source, 'MAX');

  /// The day of the first rate of each currency of [source].
  Future<Map<Currency, DateTime>> firstRateDays(RateSource source) =>
      _rateDays(source, 'MIN');

  Future<Map<Currency, DateTime>> _rateDays(
    RateSource source,
    String aggregate,
  ) async {
    final rows = await (await database).rawQuery(
      'SELECT currency, $aggregate(date) AS day FROM ${ExchangeRate.table} '
      'WHERE source = ? GROUP BY currency',
      [source.name],
    );
    return {
      for (final row in rows)
        Currency.fromCode(row['currency'] as String): DateTime.parse(
          row['day'] as String,
        ),
    };
  }

  /// What every user needs rates for: the currencies of the accounts and
  /// invoices and the main currencies, and the first day of an entry or
  /// invoice (null without any).
  Future<({Set<Currency> currencies, DateTime? firstDay})> rateNeeds() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT currency AS code FROM ${Account.table}
      UNION SELECT currency FROM ${Invoice.table}
      UNION SELECT main_currency FROM ${Profile.table}''');
    final first = await db.rawQuery('''
      SELECT MIN(day) AS day FROM (
        SELECT MIN(date) AS day FROM ${Entry.table}
        UNION ALL SELECT MIN(fulfillment_date) FROM ${Invoice.table})''');
    final day = first.first['day'] as String?;
    return (
      currencies: {
        for (final row in rows) Currency.fromCode(row['code'] as String),
      },
      firstDay: day == null ? null : DateTime.parse(day),
    );
  }

  // ---- Queries ----

  /// Balance of every account of the user with [userId] by id: the sum of
  /// its entries (the opening one too), income added, expenses taken.
  Future<Map<int, int>> accountBalances(int userId) async {
    final rows = await (await database).rawQuery(
      '''
      SELECT a.id, COALESCE(SUM(
               CASE e.type WHEN '${EntryType.income.name}' THEN e.amount
                           ELSE -e.amount END), 0) AS balance
      FROM ${Account.table} a
      LEFT JOIN ${Entry.table} e ON e.account_id = a.id
      WHERE a.user_id = ?
      GROUP BY a.id''',
      [userId],
    );
    return {for (final row in rows) row['id'] as int: row['balance'] as int};
  }

  /// Number of entries on the account with [accountId].
  Future<int> entryCount(int accountId) async {
    final rows = await (await database).rawQuery(
      'SELECT COUNT(*) AS n FROM ${Entry.table} WHERE account_id = ?',
      [accountId],
    );
    return rows.first['n'] as int;
  }

  // ---- Backup ----

  /// A copy of the whole database (every user) as the bytes of a file.
  Future<Uint8List> backup() async {
    final db = await database;
    final copy = '${await path}.backup';
    await _deleteFile(copy);
    // A consistent, compacted copy while the database is open.
    await db.execute('VACUUM INTO ?', [copy]);
    try {
      return await File(copy).readAsBytes();
    } finally {
      await _deleteFile(copy);
    }
  }

  /// Replaces the whole database with a [backup]. An older backup is
  /// upgraded. The replaced database is kept next to it as
  /// `fineva.db.previous` until the next restore.
  ///
  /// Throws a [BackupException] if [bytes] isn't a Fineva database or is
  /// from a newer version; the data stays as it was then.
  Future<void> restore(Uint8List bytes) async {
    final dbPath = await path;
    final restored = '$dbPath.restore';
    final previous = '$dbPath.previous';
    await File(restored).writeAsBytes(bytes, flush: true);
    try {
      await _checkBackup(restored);
    } catch (_) {
      await _deleteFile(restored);
      rethrow;
    }
    await close();
    await _deleteFile(previous);
    if (await File(dbPath).exists()) await File(dbPath).rename(previous);
    await File(restored).rename(dbPath);
    try {
      await database; // opens and upgrades it
    } catch (_) {
      // Back to the replaced one.
      await close();
      await _deleteFile(dbPath);
      if (await File(previous).exists()) await File(previous).rename(dbPath);
      rethrow;
    }
  }

  // Throws a [BackupException] unless [file] is a Fineva database this
  // version can open.
  Future<void> _checkBackup(String file) async {
    final factory = await _databaseFactory();
    final Database db;
    try {
      db = await factory.openDatabase(
        file,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
    } catch (e) {
      throw BackupException(BackupError.invalid, e);
    }
    try {
      final int version;
      final Set<String> tables;
      try {
        final check = await db.rawQuery('PRAGMA quick_check');
        if (check.first.values.first != 'ok') {
          throw BackupException(BackupError.invalid, check);
        }
        version =
            (await db.rawQuery('PRAGMA user_version')).first.values.first
                as int;
        tables = {
          for (final row in await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table'",
          ))
            row['name'] as String,
        };
      } on BackupException {
        rethrow;
      } catch (e) {
        // Not a database at all.
        throw BackupException(BackupError.invalid, e);
      }
      if (version > schemaVersion) {
        throw BackupException(BackupError.newer, version);
      }
      if (version < 1 || !tables.containsAll(_tables)) {
        throw BackupException(BackupError.invalid, tables);
      }
    } finally {
      await db.close();
    }
  }

  static Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
