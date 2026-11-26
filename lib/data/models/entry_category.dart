import 'package:equatable/equatable.dart';

import '../../utils/utils.dart';
import 'db_model.dart';

/// Category of income or expense entries (salary, food, taxes, ...).
///
/// (Not called Category: Flutter's foundation library has a class with that
/// name.)
class EntryCategory extends Equatable implements DbModel {
  const EntryCategory({
    this.id,
    this.userId,
    required this.name,
    required this.type,
    this.color = 0xFF546E7A,
    this.systemKey,
    this.taxTreatment = TaxTreatment.none,
    this.scope = CategoryScope.personal,
    this.icon,
  });

  static const String table = 'categories';

  @override
  final int? id;

  /// The user ([Profile]) the category belongs to. FinanceNotifier sets it
  /// when saving, FinanceDatasource.insertProfile for the built-in ones.
  final int? userId;

  /// Name given by the user. Built-in categories show their translated name
  /// instead (see [systemKey]).
  final String name;

  /// Only entries of this type can be in the category.
  final EntryType type;

  /// ARGB, one of `categoryColors`.
  final int color;

  /// Set for the categories the app creates (e.g. 'food'): they are shown in
  /// the app's language. Renaming one clears it.
  final String? systemKey;

  /// How its entries count in a sole proprietor's itemized taxation.
  final TaxTreatment taxTreatment;

  /// Shown for a personal user or for a sole proprietor.
  final CategoryScope scope;

  /// A key of `categoryIcons`; null: one picked by the id (see
  /// `categoryIcon`).
  final String? icon;

  factory EntryCategory.fromMap(Map<String, Object?> map) => EntryCategory(
    id: map['id'] as int,
    userId: map['user_id'] as int?,
    name: map['name'] as String,
    type: EntryType.values.byName(map['type'] as String),
    color: map['color'] as int,
    systemKey: map['system_key'] as String?,
    taxTreatment: TaxTreatment.values.byName(map['tax_treatment'] as String),
    scope: CategoryScope.values.byName(map['scope'] as String),
    icon: map['icon'] as String?,
  );

  @override
  Map<String, Object?> toMap() => {
    'user_id': userId,
    'name': name,
    'type': type.name,
    'color': color,
    'system_key': systemKey,
    'tax_treatment': taxTreatment.name,
    'scope': scope.name,
    'icon': icon,
  };

  /// A copy with the given fields. A new [name] makes it the user's own
  /// category: [systemKey] is cleared, so it's no longer shown translated.
  EntryCategory copyWith({
    int? userId,
    String? name,
    EntryType? type,
    int? color,
    TaxTreatment? taxTreatment,
    String? icon,
  }) => EntryCategory(
    id: id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    type: type ?? this.type,
    color: color ?? this.color,
    systemKey: name == null ? systemKey : null,
    taxTreatment: taxTreatment ?? this.taxTreatment,
    scope: scope,
    icon: icon ?? this.icon,
  );

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    type,
    color,
    systemKey,
    taxTreatment,
    scope,
    icon,
  ];
}
