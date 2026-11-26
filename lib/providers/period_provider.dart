import 'dart:math' show min;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'finance/date_period.dart';

/// The period the dashboard and the statistics show, the same on both and
/// kept while the app runs; this month at start.
class PeriodNotifier extends Notifier<DatePeriod> {
  @override
  DatePeriod build() => DatePeriod.current(PeriodKind.month);

  void set(DatePeriod period) => state = period;
}

final periodProvider = NotifierProvider<PeriodNotifier, DatePeriod>(
  PeriodNotifier.new,
);

/// The year the sole proprietor's pages show (the business page, and an
/// invoices only user's invoices, revenue record and flat-rate tax), the
/// same on all and kept while the app runs; this year at start, never a
/// later one.
class BusinessYearNotifier extends Notifier<int> {
  @override
  int build() => currentDay().year;

  void set(int year) => state = min(year, currentDay().year);
}

final businessYearProvider = NotifierProvider<BusinessYearNotifier, int>(
  BusinessYearNotifier.new,
);
