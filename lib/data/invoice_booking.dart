import '../utils/utils.dart';
import 'models/models.dart';

/// The entries that book [invoice]'s payments on [account], each on its
/// day: none while it is unpaid or has no account, or if [account]'s
/// currency is neither the invoice's nor forint.
///
/// A paid amount goes in the account's currency (in forints at the
/// payments' exchange rate); a foreign currency entry keeps the rate for the
/// business taxes. For a [category] with a tax treatment (itemized taxation)
/// the VAT part is a separate entry, as in the cash-flow ledger: in the VAT
/// category for a cost, in the non-taxable income for a sale, if
/// [categories] has one. A negative payment (a credit note) books the other
/// way.
List<Entry> invoiceEntries(
  Invoice invoice, {
  required Account? account,
  required EntryCategory? category,
  required List<EntryCategory> categories,
}) {
  if (invoice.payments.isEmpty || account == null) return const [];
  final rate = invoice.paidExchangeRate ?? invoice.exchangeRate;
  final sameCurrency = account.currency == invoice.currency;
  if (!sameCurrency && account.currency != Currency.huf) return const [];
  int inAccount(int amount) =>
      sameCurrency ? amount : invoice.currency.toHuf(amount, rate);

  final outgoing = invoice.direction == InvoiceDirection.outgoing;
  EntryCategory? vatCategory;
  if (category != null &&
      category.taxTreatment != TaxTreatment.none &&
      invoice.vatAmount != 0 &&
      invoice.gross != 0) {
    final treatment = outgoing
        ? TaxTreatment.nonTaxableIncome
        : TaxTreatment.vat;
    vatCategory = categories
        .where((c) => c.taxTreatment == treatment)
        .firstOrNull;
  }
  final note = [
    invoice.number,
    if (invoice.partnerName.isNotEmpty) invoice.partnerName,
  ].join(' · ');

  Entry? entry(DateTime date, int amount, EntryCategory? category) {
    final value = inAccount(amount);
    if (value == 0) return null;
    final income = outgoing == value > 0;
    return Entry(
      accountId: account.id!,
      categoryId: category?.id,
      type: income ? EntryType.income : EntryType.expense,
      amount: value.abs(),
      date: date,
      note: note,
      rate: account.currency == Currency.huf ? null : rate / exchangeRateScale,
      invoiceId: invoice.id,
    );
  }

  return [
    for (final payment in invoice.payments)
      ...() {
        final paid = payment.amount;
        final vatPart = vatCategory == null
            ? 0
            : (paid * invoice.vatAmount / invoice.gross).round();
        return [
          ?entry(payment.date, paid - vatPart, category),
          if (vatPart != 0) ?entry(payment.date, vatPart, vatCategory),
        ];
      }(),
  ];
}
