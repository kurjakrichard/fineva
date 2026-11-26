import 'dart:convert';

import 'package:fineva/data/data_export.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

/// [BuiltInCategories.current] with [extra] ones.
BuiltInCategories withExtra(List<BuiltInCategory> extra) =>
    BuiltInCategories([...BuiltInCategories.current.all, ...extra]);

BuiltInCategory extra(
  String key,
  BuiltInSet set, {
  bool retired = false,
  Map<String, String>? names,
}) => BuiltInCategory(
  set: set,
  retired: retired,
  names: names ?? {'en': key},
  category: EntryCategory(
    name: key,
    type: EntryType.expense,
    systemKey: key,
    scope: set == BuiltInSet.personal
        ? CategoryScope.personal
        : CategoryScope.business,
    icon: 'more_horiz',
  ),
);

/// The keys of [user]'s categories (null for the user's own).
Future<List<String?>> keysOf(FinanceDatasource db, int user) async => [
  for (final c in await db.getAll(
    EntryCategory.table,
    EntryCategory.fromMap,
    where: 'user_id = ?',
    whereArgs: [user],
  ))
    c.systemKey,
];

void main() {
  final builtIns = BuiltInCategories.current;

  group('assets/categories.json', () {
    test('every category is complete: a known icon, color and treatment, '
        'an English and a Hungarian name', () {
      expect(builtIns.all, isNotEmpty);
      for (final c in builtIns.all) {
        final category = c.category;
        expect(categoryIcons.keys, contains(category.icon), reason: c.key);
        expect(categoryColors, contains(category.color), reason: c.key);
        expect(c.names.keys, containsAll(['en', 'hu']), reason: c.key);
        expect(c.names.values, everyElement(isNotEmpty), reason: c.key);
        if (c.set != BuiltInSet.itemized) {
          expect(category.taxTreatment, TaxTreatment.none, reason: c.key);
        }
      }
      for (final set in BuiltInSet.values) {
        expect(builtIns.ofSet(set), isNotEmpty, reason: set.name);
      }
      expect(builtIns.itemized.map((c) => c.taxTreatment).toSet(), {
        for (final t in TaxTreatment.values)
          if (t != TaxTreatment.none) t,
      });
    });

    test('no key users were given ever disappears (removed ones are '
        'retired), the ones the code uses are given', () {
      final keys = builtIns.all.map((c) => c.key);
      // Given at schema 15 (FinanceDatasource._v15).
      expect(keys, containsAll(_keysAtSchema15));
      for (final key in ['businessIncome', 'businessExpense']) {
        expect(
          builtIns.ofSet(BuiltInSet.business).map((c) => c.systemKey),
          contains(key),
        );
      }
    });
  });

  group('parse', () {
    String file(Map<String, Object?> category) => jsonEncode({
      'categories': [category],
    });
    final good = {
      'key': 'gifts',
      'set': 'personal',
      'type': 'expense',
      'color': '#8E24AA',
      'icon': 'redeem',
      'names': {'en': 'Gifts', 'hu': 'Ajándék'},
    };

    test('a category', () {
      final parsed = BuiltInCategories.parse(file(good)).all.single;
      expect(parsed.key, 'gifts');
      expect(parsed.retired, isFalse);
      expect(
        parsed.category,
        const EntryCategory(
          name: 'Gifts',
          type: EntryType.expense,
          color: 0xFF8E24AA,
          systemKey: 'gifts',
          icon: 'redeem',
        ),
      );
      final business = BuiltInCategories.parse(
        file({...good, 'set': 'itemized', 'treatment': 'itCost'}),
      ).all.single.category;
      expect(business.scope, CategoryScope.business);
      expect(business.taxTreatment, TaxTreatment.itCost);
    });

    test('a wrong one is refused, naming it', () {
      for (final wrong in <Map<String, Object?>>[
        {...good, 'key': ''},
        {...good, 'set': 'company'},
        {...good, 'type': 'transfer'},
        {...good, 'color': 'purple'},
        {...good, 'icon': null},
        {...good, 'treatment': 'everything'},
        {...good, 'retired': 'yes'},
        {
          ...good,
          'names': {'hu': 'Ajándék'},
        },
      ]) {
        expect(
          () => BuiltInCategories.parse(file(wrong)),
          throwsA(isA<FormatException>()),
          reason: '$wrong',
        );
      }
      // A key twice.
      expect(
        () => BuiltInCategories.parse(
          jsonEncode({
            'categories': [good, good],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BuiltInCategories.parse('[]'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('names in the app\'s language, English if it has none', () {
    final catalog = withExtra([
      extra('gifts', BuiltInSet.personal, names: {'en': 'Gifts'}),
    ]);
    expect(catalog.name('food', 'hu'), 'Élelmiszer');
    expect(catalog.name('food', 'en'), 'Food');
    expect(catalog.name('gifts', 'hu'), 'Gifts');
    expect(catalog.name('nothing', 'hu'), isNull);
  });

  test('what a user gets: the never had ones of their sets, not the '
      'retired', () {
    final catalog = withExtra([
      extra('gifts', BuiltInSet.personal),
      extra('old', BuiltInSet.personal, retired: true),
      extra('bizNew', BuiltInSet.itemized),
    ]);
    final personal = catalog.keysOf(BuiltInSet.personal);
    expect(
      catalog
          .missing(UserType.personal, personal.difference({'gifts', 'old'}))
          .map((c) => c.systemKey),
      ['gifts'],
    );
    final business = catalog.keysOf(BuiltInSet.business);
    // Itemized only if they have had one of it.
    expect(catalog.missing(UserType.soleProprietor, business), isEmpty);
    expect(
      catalog
          .missing(UserType.soleProprietor, {...business, 'bizRevenue'})
          .map((c) => c.systemKey)
          .toSet(),
      builtIns.keysOf(BuiltInSet.itemized).difference({'bizRevenue'})
        ..add('bizNew'),
    );
  });

  group('in the database', () {
    late TestDatabase testDb;
    setUp(() async => testDb = await TestDatabase.create());
    tearDown(() => testDb.dispose());

    FinanceDatasource open(BuiltInCategories catalog) => FinanceDatasource(
      path: testDb.path,
      factory: testDatabaseFactory,
      builtIns: catalog,
    );

    test('a category added to the file is given to every user of its set at '
        'the next start, once; deleted, it doesn\'t come back', () async {
      final first = testDb.datasource;
      final anna = await first.insertProfile(const Profile(name: 'Anna'));
      final bela = await first.insertProfile(
        const Profile(name: 'Béla', userType: UserType.soleProprietor),
      );
      await first.close();

      final catalog = withExtra([
        extra('gifts', BuiltInSet.personal),
        extra('old', BuiltInSet.personal, retired: true),
        extra('bizNew', BuiltInSet.business),
      ]);
      var db = open(catalog);
      expect(await keysOf(db, anna), [
        ...builtIns.keysOf(BuiltInSet.personal),
        'gifts',
      ]);
      expect(await keysOf(db, bela), [
        ...builtIns.keysOf(BuiltInSet.business),
        'bizNew',
      ]);

      // Deleted, it stays deleted.
      final gifts = (await db.getAll(
        EntryCategory.table,
        EntryCategory.fromMap,
        where: "system_key = 'gifts'",
      )).single;
      await db.delete(EntryCategory.table, gifts.id!, userId: anna);
      await db.close();
      db = open(catalog);
      expect(await keysOf(db, anna), isNot(contains('gifts')));
      expect(await keysOf(db, bela), hasLength(4));

      // A new user gets them at once, not twice.
      final cili = await db.insertProfile(const Profile(name: 'Cili'));
      await db.close();
      db = open(catalog);
      expect(await keysOf(db, cili), [
        ...builtIns.keysOf(BuiltInSet.personal),
        'gifts',
      ]);
      await db.close();
    });

    test('the itemized ones on demand: the deleted given back, the others '
        'not twice', () async {
      final db = testDb.datasource;
      final user = await db.insertProfile(
        const Profile(name: 'EV', userType: UserType.soleProprietor),
      );
      await db.addBuiltIns(user, BuiltInSet.itemized);
      final vat = (await db.getAll(
        EntryCategory.table,
        EntryCategory.fromMap,
        where: "system_key = 'bizVat'",
      )).single;
      await db.delete(EntryCategory.table, vat.id!, userId: user);
      await db.addBuiltIns(user, BuiltInSet.itemized);
      final keys = await keysOf(db, user);
      expect(keys, hasLength(keys.toSet().length));
      expect(keys, contains('bizVat'));
    });
  });
}

/// The keys of the built-in categories at schema 15 (the first given from
/// the file): users have them, so they must stay in it.
const _keysAtSchema15 = [
  'salary',
  'otherIncome',
  'food',
  'housing',
  'utilities',
  'transport',
  'health',
  'entertainment',
  'taxes',
  'otherExpense',
  'businessIncome',
  'businessExpense',
  'businessTaxes',
  'bizRevenue',
  'bizNonTaxableIncome',
  'bizWithdrawal',
  'bizSzocho',
  'bizOther',
  'bizMaterial',
  'bizBank',
  'bizAccounting',
  'bizIt',
  'bizNonDeductible',
  'bizVat',
];
