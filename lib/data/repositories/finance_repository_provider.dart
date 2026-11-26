import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasource/finance_datasource_provider.dart';
import 'finance_repository.dart';
import 'finance_repository_impl.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepositoryImpl(ref.watch(financeDatasourceProvider));
});
