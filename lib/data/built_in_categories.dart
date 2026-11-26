import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../utils/utils.dart';
import 'models/models.dart';

/// Which users get a built-in category.
enum BuiltInSet {
  /// A new personal user.
  personal,

  /// A new sole proprietor.
  business,

  /// Itemized taxation, added on demand (FinanceRepository
  /// .addBusinessCategories).
  itemized,
}

/// A category of [BuiltInCategories]: a [category] (without user, its
/// English name as `name`) with its names in the app's languages.
class BuiltInCategory {
  const BuiltInCategory({
    required this.set,
    required this.category,
    required this.names,
    this.retired = false,
  });

  String get key => category.systemKey!;
  final BuiltInSet set;
  final EntryCategory category;

  /// Language code → name; 'en' always.
  final Map<String, String> names;

  /// No longer given to anyone; only its names are still used.
  final bool retired;
}

/// The built-in categories, from [asset] (`assets/categories.json`), so a
/// category can be added or removed without changing the code.
///
/// A new user gets the [BuiltInSet] of their kind ([forNewUser]), the
/// [itemized] ones are added on demand; at every start each user gets the
/// ones of their sets they have never had ([missing], see
/// FinanceDatasource's `given_categories`). A removed one stays in the file
/// as `retired`, for its names. A category made from one keeps its key
/// ([EntryCategory.systemKey]) and is shown by it in the app's language
/// ([name]) until renamed.
///
/// Loaded once before the app starts ([load], main.dart; the tests' in
/// test/flutter_test_config.dart), then read through [current].
class BuiltInCategories {
  BuiltInCategories(Iterable<BuiltInCategory> all)
    : all = List.unmodifiable(all),
      _byKey = {for (final c in all) c.key: c} {
    if (_byKey.length != this.all.length) {
      throw const FormatException('Built-in categories: a key twice');
    }
  }

  static const String asset = 'assets/categories.json';

  static BuiltInCategories? _current;

  /// The loaded ones; a StateError before [load] (or setting it).
  static BuiltInCategories get current =>
      _current ?? (throw StateError('The built-in categories are not loaded'));
  static set current(BuiltInCategories value) => _current = value;

  /// Loads [asset] as [current].
  static Future<BuiltInCategories> load([AssetBundle? bundle]) async =>
      current = BuiltInCategories.parse(
        await (bundle ?? rootBundle).loadString(asset),
      );

  /// The categories of [asset]'s JSON; a FormatException naming the wrong
  /// one.
  factory BuiltInCategories.parse(String json) {
    final data = jsonDecode(json);
    if (data is! Map<String, Object?> || data['categories'] is! List) {
      throw const FormatException('Built-in categories: no "categories"');
    }
    return BuiltInCategories([
      for (final item in data['categories']! as List) _parseOne(item),
    ]);
  }

  static BuiltInCategory _parseOne(Object? item) {
    if (item is! Map<String, Object?>) {
      throw FormatException('Built-in categories: not an object: $item');
    }
    final key = item['key'];
    T field<T>(String name, T? Function(Object? value) parse) =>
        parse(item[name]) ??
        (throw FormatException(
          'Built-in category $key: wrong or missing "$name": ${item[name]}',
        ));
    T? named<T extends Enum>(List<T> values, Object? name) =>
        name is String ? values.asNameMap()[name] : null;
    if (key is! String || key.isEmpty) {
      throw FormatException('Built-in category without key: $item');
    }
    final names = field(
      'names',
      (v) => v is Map && v['en'] is String && v.values.every((n) => n is String)
          ? v.cast<String, String>()
          : null,
    );
    final set = field('set', (v) => named(BuiltInSet.values, v));
    return BuiltInCategory(
      set: set,
      names: Map.unmodifiable(names),
      retired: field(
        'retired',
        (v) => v == null ? false : (v is bool ? v : null),
      ),
      category: EntryCategory(
        name: names['en']!,
        type: field('type', (v) => named(EntryType.values, v)),
        color: field('color', _parseColor),
        systemKey: key,
        taxTreatment: field(
          'treatment',
          (v) => v == null ? TaxTreatment.none : named(TaxTreatment.values, v),
        ),
        scope: set == BuiltInSet.personal
            ? CategoryScope.personal
            : CategoryScope.business,
        icon: field('icon', (v) => v is String && v.isNotEmpty ? v : null),
      ),
    );
  }

  /// "#2E7D32" → 0xFF2E7D32.
  static int? _parseColor(Object? value) {
    if (value is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return null;
    }
    return 0xFF000000 | int.parse(value.substring(1), radix: 16);
  }

  /// Every one, the retired too, in the file's order.
  final List<BuiltInCategory> all;
  final Map<String, BuiltInCategory> _byKey;

  /// The ones of [set] given to users now (not the retired).
  List<EntryCategory> ofSet(BuiltInSet set) => [
    for (final c in all)
      if (c.set == set && !c.retired) c.category,
  ];

  /// A new user's: of their own kind only (a user's kind doesn't change).
  List<EntryCategory> forNewUser(UserType type) => ofSet(setOf(type));

  /// Of itemized taxation, added on demand.
  List<EntryCategory> get itemized => ofSet(BuiltInSet.itemized);

  static BuiltInSet setOf(UserType type) => type == UserType.soleProprietor
      ? BuiltInSet.business
      : BuiltInSet.personal;

  /// The keys of [set], the retired too.
  Set<String> keysOf(BuiltInSet set) => {
    for (final c in all)
      if (c.set == set) c.key,
  };

  /// What a user of [type] who has had the keys [given] gets now: the ones
  /// of their kind's set, and of the itemized set if they have had any of
  /// it, that they have never had (and aren't retired).
  List<EntryCategory> missing(UserType type, Set<String> given) {
    final sets = {
      setOf(type),
      if (given.intersection(keysOf(BuiltInSet.itemized)).isNotEmpty)
        BuiltInSet.itemized,
    };
    return [
      for (final c in all)
        if (sets.contains(c.set) && !c.retired && !given.contains(c.key))
          c.category,
    ];
  }

  /// The name of the category with [key] in [languageCode] (English if it
  /// has none in it); null for an unknown key.
  String? name(String key, String languageCode) {
    final names = _byKey[key]?.names;
    return names == null ? null : names[languageCode] ?? names['en'];
  }
}
