/// The legal amounts of a tax year that the sole proprietor calculations
/// use. Rates are in basis points (1/100 of a percent): 1850 is 18.5%.
class TaxYear {
  const TaxYear({
    required this.year,
    required this.minimumWage,
    required this.guaranteedMinimumWage,
  });

  final int year;

  /// Minimálbér, monthly.
  final int minimumWage;

  /// Garantált bérminimum, monthly: the minimum contribution base of a
  /// flat-rate sole proprietor in main occupation.
  final int guaranteedMinimumWage;

  static const int szjaRate = 1500;
  static const int tbRate = 1850;
  static const int szochoRate = 1300;

  /// Local business tax (helyi iparűzési adó); the municipality may set
  /// less.
  static const int localTaxRate = 200;

  /// Chamber fee (kamarai hozzájárulás), paid in the first quarter.
  static const int chamberFee = 5000;

  /// KATA: the yearly revenue limit and the monthly tax.
  static const int kataRevenueLimit = 18000000;
  static const int kataMonthlyTax = 50000;

  static const List<TaxYear> known = [
    TaxYear(year: 2025, minimumWage: 290800, guaranteedMinimumWage: 348800),
    TaxYear(year: 2026, minimumWage: 322800, guaranteedMinimumWage: 373200),
  ];

  /// The amounts of [year]; the latest known year's after it, the first
  /// one's before.
  static TaxYear of(int year) {
    TaxYear? result;
    for (final known in TaxYear.known) {
      if (known.year <= year) result = known;
    }
    final found = result ?? TaxYear.known.first;
    return found.year == year
        ? found
        : TaxYear(
            year: year,
            minimumWage: found.minimumWage,
            guaranteedMinimumWage: found.guaranteedMinimumWage,
          );
  }

  /// True if the amounts were set for [year], not taken from another year.
  bool get isKnown => known.any((k) => k.year == year);

  /// The tax-free income of a flat-rate sole proprietor: half of the
  /// yearly minimum wage.
  int get taxFreeIncome => minimumWage * 12 ~/ 2;

  /// The yearly revenue limit of flat-rate taxation: ten times the yearly
  /// minimum wage.
  int get flatRateRevenueLimit => minimumWage * 12 * 10;

  /// [amount] times [rate] (in basis points), rounded to a forint.
  static int percent(num amount, int rate) => (amount * rate / 10000).round();
}

/// [date], or the next Monday if it is on a weekend. (Public holidays are
/// not known.)
DateTime workday(DateTime date) => switch (date.weekday) {
  DateTime.saturday => date.add(const Duration(days: 2)),
  DateTime.sunday => date.add(const Duration(days: 1)),
  _ => date,
};
