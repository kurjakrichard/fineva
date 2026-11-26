/// A row of one of the app's tables. The datasource's generic functions
/// (getAll, getById, insert, update, delete) work with any model through
/// this; each model also has a `fromMap` factory and a `table` constant.
abstract interface class DbModel {
  /// Null until the row is inserted.
  int? get id;

  /// The row's columns without the id (the database assigns it).
  Map<String, Object?> toMap();
}
