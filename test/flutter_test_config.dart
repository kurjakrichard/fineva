import 'dart:async';
import 'dart:io';

import 'package:fineva/data/data_export.dart';

/// Every test has the app's built-in categories, as main.dart loads them
/// for the app.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  BuiltInCategories.current = BuiltInCategories.parse(
    File(BuiltInCategories.asset).readAsStringSync(),
  );
  await testMain();
}
