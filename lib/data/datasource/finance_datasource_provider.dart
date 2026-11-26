import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'finance_datasource.dart';

/// The app's database. Closed when the provider is disposed.
final financeDatasourceProvider = Provider<FinanceDatasource>((ref) {
  final datasource = FinanceDatasource();
  ref.onDispose(datasource.close);
  return datasource;
});
