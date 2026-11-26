import 'dart:ffi';
import 'dart:io';

import 'package:fineva/data/data_export.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

// flutter test runs on the Dart VM, without the sqlite3 that the app bundles
// (sqlite3_flutter_libs). The system's is used instead: without its -devel
// package only libsqlite3.so.0 exists. Runs in sqflite's worker isolate.
void _openSystemSqlite() {
  open.overrideFor(OperatingSystem.linux, () {
    try {
      return DynamicLibrary.open('libsqlite3.so');
    } catch (_) {
      return DynamicLibrary.open('libsqlite3.so.0');
    }
  });
}

/// sqflite with the system's sqlite.
final testDatabaseFactory = createDatabaseFactoryFfi(
  ffiInit: _openSystemSqlite,
);

/// A datasource on a new, empty database in a temp folder. [dispose] closes
/// it and deletes the folder.
class TestDatabase {
  TestDatabase._(this._dir, this.path)
    : datasource = FinanceDatasource(path: path, factory: testDatabaseFactory);

  static Future<TestDatabase> create() async {
    final dir = await Directory.systemTemp.createTemp('fineva_test');
    return TestDatabase._(dir, p.join(dir.path, 'test.db'));
  }

  final Directory _dir;

  /// The database file (created on the datasource's first use).
  final String path;
  final FinanceDatasource datasource;

  Future<void> dispose() async {
    await datasource.close();
    await _dir.delete(recursive: true);
  }
}
