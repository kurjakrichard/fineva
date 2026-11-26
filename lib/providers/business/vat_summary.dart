import '../../data/data_export.dart';
import '../../utils/utils.dart';
import 'tax_year.dart';

/// A VAT return period: a month, a quarter or a year.
class VatReturnPeriod {
  const VatReturnPeriod(this.start, this.end);

  final DateTime start;

  /// The day after the last one.
  final DateTime end;

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);

  /// The VAT return and payment are due on the 20th of the next month.
  DateTime get deadline => workday(DateTime(end.year, end.month, 20));

  /// The periods of [year] for [vatPeriod].
  static List<VatReturnPeriod> ofYear(int year, VatPeriod vatPeriod) {
    final months = switch (vatPeriod) {
      VatPeriod.monthly => 1,
      VatPeriod.quarterly => 3,
      VatPeriod.yearly => 12,
    };
    return [
      for (var m = 1; m <= 12; m += months)
        VatReturnPeriod(DateTime(year, m), DateTime(year, m + months)),
    ];
  }
}

/// A line of the VAT summary: the net base and the VAT on it, in forints.
typedef VatLine = ({int base, int vat});

/// The VAT of a period from the invoices, by their VAT date
/// ([Invoice.vatDate]: for an outgoing invoice the payment date within 45
/// days of the fulfillment, otherwise the fulfillment + 45 days): payable
/// on the outgoing invoices by rate, deductible on the incoming ones (only
/// if VAT registered), self-assessed on the reverse charged purchases
/// (payable, and deductible if registered), and the sales without VAT by
/// where they were (for the return and the EU statement).
///
/// The return is filed in thousands of forints: [rounded] rounds a line.
class VatSummary {
  VatSummary(List<Invoice> invoices, Profile profile, this.period)
    : registered = profile.vatStatus == VatStatus.registered {
    for (final invoice in invoices) {
      if (!period.contains(invoice.vatDate)) continue;
      final code = invoice.vatCode;
      final base = invoice.huf(invoice.netAmount);
      final vat = invoice.huf(invoice.vatAmount);
      final rate = code.rate;
      if (invoice.direction == InvoiceDirection.outgoing) {
        if (rate != null) {
          payable[rate] = _add(payable[rate], base, vat);
        } else {
          exemptSales[code.location] = (exemptSales[code.location] ?? 0) + base;
        }
      } else if (code.reverseCharge) {
        reverseCharge = _add(
          reverseCharge,
          base,
          TaxYear.percent(base, VatCode.reverseChargeRate * 100),
        );
      } else if (rate != null && registered) {
        deductible[rate] = _add(deductible[rate], base, vat);
      }
    }
  }

  final VatReturnPeriod period;

  /// Only a VAT registered sole proprietor can deduct.
  final bool registered;

  /// Outgoing, by rate.
  final Map<int, VatLine> payable = {};

  /// Incoming, by rate.
  final Map<int, VatLine> deductible = {};

  /// Self-assessed on reverse charged purchases.
  VatLine reverseCharge = (base: 0, vat: 0);

  /// The net of the sales without VAT, by where the partner is.
  final Map<PartnerLocation, int> exemptSales = {};

  static VatLine _add(VatLine? line, int base, int vat) =>
      (base: (line?.base ?? 0) + base, vat: (line?.vat ?? 0) + vat);

  /// [amount] rounded to thousands, as in the return.
  static int rounded(int amount) => (amount / 1000).round() * 1000;

  int get totalPayable =>
      payable.values.fold(0, (sum, l) => sum + rounded(l.vat)) +
      rounded(reverseCharge.vat);

  int get totalDeductible =>
      deductible.values.fold(0, (sum, l) => sum + rounded(l.vat)) +
      (registered ? rounded(reverseCharge.vat) : 0);

  /// To pay (positive) or to reclaim / carry forward (negative).
  int get balance => totalPayable - totalDeductible;

  bool get isEmpty =>
      payable.isEmpty &&
      deductible.isEmpty &&
      reverseCharge.base == 0 &&
      exemptSales.isEmpty;
}

/// What each of [summaries] (the periods of a year, in order) brings over
/// from the ones before: a negative balance is carried forward (as
/// "továbbvihető") until a payable one uses it up. 0 or negative.
List<int> vatCarriedIn(List<VatSummary> summaries) {
  final result = <int>[];
  var carried = 0;
  for (final summary in summaries) {
    result.add(carried);
    final balance = summary.balance + carried;
    carried = balance < 0 ? balance : 0;
  }
  return result;
}

/// KATA: the revenue of [year] (the paid net of the outgoing invoices)
/// against the yearly limit.
int kataRevenue(List<Invoice> invoices, int year) => invoices
    .where((i) => i.direction == InvoiceDirection.outgoing)
    .fold(0, (sum, i) => sum + i.paidNetHufIn(year));
