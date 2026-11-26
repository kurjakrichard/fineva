import 'package:equatable/equatable.dart';

import '../../utils/utils.dart';
import 'db_model.dart';
import 'entry.dart';
import 'invoice_payment.dart';

/// A sole proprietor's invoice or other document (bizonylat): issued
/// (outgoing, revenue) or received (incoming, cost). One VAT code per
/// record; an invoice with several VAT rates is recorded once per rate.
///
/// Amounts are in the smallest unit of [currency]; [huf] converts them at
/// [exchangeRate]. It is paid in [payments] (one or more parts); its paid
/// and open amounts come from them.
class Invoice extends Equatable implements DbModel {
  const Invoice({
    this.id,
    this.userId,
    required this.direction,
    this.number = '',
    this.description = '',
    this.partnerName = '',
    this.partnerTaxNumber = '',
    this.partnerLocation = PartnerLocation.domestic,
    this.paymentMethod = PaymentMethod.transfer,
    required this.issueDate,
    required this.fulfillmentDate,
    this.dueDate,
    this.currency = Currency.huf,
    this.exchangeRate = rateScale,
    required this.netAmount,
    required this.vatCode,
    this.vatAmount = 0,
    this.payments = const [],
    this.paidAccountId,
    this.paidExchangeRate,
    this.categoryId,
  });

  static const String table = 'invoices';

  /// [exchangeRate] is in this part of a forint: 389.73 HUF/EUR is
  /// 3897300.
  static const int rateScale = exchangeRateScale;

  @override
  final int? id;

  /// The user (sole proprietor) it belongs to. FinanceNotifier sets it when
  /// saving.
  final int? userId;
  final InvoiceDirection direction;

  /// The invoice's own number (bizonylat sorszáma).
  final String number;

  /// What it was for (a gazdasági esemény rövid leírása).
  final String description;
  final String partnerName;

  /// The partner's Hungarian tax number, EU VAT number or foreign tax id.
  final String partnerTaxNumber;
  final PartnerLocation partnerLocation;
  final PaymentMethod paymentMethod;

  /// Kiállítás kelte.
  final DateTime issueDate;

  /// Teljesítés időpontja; it decides the VAT period (see [vatDate]).
  final DateTime fulfillmentDate;

  /// Fizetési határidő.
  final DateTime? dueDate;
  final Currency currency;

  /// HUF per unit of [currency], times [rateScale]; [rateScale] for HUF.
  /// The rate of [rateDate]: the revenue and the VAT count at it, whenever
  /// it is paid.
  final int exchangeRate;

  /// The day of [exchangeRate]: the fulfillment, or the issue if the
  /// invoice was issued before it.
  DateTime get rateDate =>
      issueDate.isBefore(fulfillmentDate) ? issueDate : fulfillmentDate;

  final int netAmount;
  final VatCode vatCode;

  /// The VAT on the invoice (0 for codes without a rate).
  final int vatAmount;

  /// Its payments (kiegyenlítések), in the order paid. Loaded and saved
  /// with it (table `invoice_payments`).
  final List<InvoicePayment> payments;

  /// The day of the last payment; null if nothing was paid. (The VAT date
  /// of an outgoing invoice, see [vatDate].)
  DateTime? get paidDate => payments.isEmpty
      ? null
      : payments.map((p) => p.date).reduce((a, b) => a.isAfter(b) ? a : b);

  /// The paid part of [gross]: the sum of the [payments].
  int get paidAmount => payments.fold(0, (sum, p) => sum + p.amount);

  int get gross => netAmount + vatAmount;

  /// The account the payment is booked on (an entry linked to the invoice,
  /// see `invoiceEntries`); null: not booked.
  final int? paidAccountId;

  /// The exchange rate of the payments for booking them on a forint
  /// account (see [rateScale]); null: [exchangeRate].
  final int? paidExchangeRate;

  /// The category of the booked entry.
  final int? categoryId;

  /// [gross] - [paidAmount].
  int get openAmount => gross - paidAmount;

  /// Paid: its payments add up to [gross].
  bool get isPaid => payments.isNotEmpty && openAmount == 0;

  /// The days after the fulfillment within which the payment date is the
  /// VAT date of an outgoing invoice.
  static const int vatDateDays = 45;

  /// The day that decides the VAT period (áfa napja), see [vatDateOf].
  DateTime get vatDate => vatDateOf(direction, fulfillmentDate, paidDate);

  /// The VAT date as the income record workbooks calculate it: for an
  /// outgoing invoice the payment date if it was paid at most [vatDateDays]
  /// days after the fulfillment (or before it), otherwise, and while it is
  /// open, the fulfillment date + [vatDateDays] days; for an incoming one
  /// the fulfillment date.
  static DateTime vatDateOf(
    InvoiceDirection direction,
    DateTime fulfillmentDate,
    DateTime? paidDate,
  ) {
    if (direction == InvoiceDirection.incoming) return fulfillmentDate;
    // By calendar days: a Duration would be off by an hour across DST.
    final limit = DateTime(
      fulfillmentDate.year,
      fulfillmentDate.month,
      fulfillmentDate.day + vatDateDays,
    );
    return paidDate == null || paidDate.isAfter(limit) ? limit : paidDate;
  }

  /// [amount] of [currency] in forints at [exchangeRate].
  int huf(int amount) => convert(amount, currency, exchangeRate);

  /// [amount] (in the smallest unit of [currency]) in forints at
  /// [exchangeRate] (see [rateScale]).
  static int convert(int amount, Currency currency, int exchangeRate) =>
      currency.toHuf(amount, exchangeRate);

  /// The net part of a payment of [amount] in forints, at [exchangeRate]:
  /// the revenue of a flat-rate sole proprietor.
  int netHuf(int amount) =>
      gross == 0 ? 0 : huf((amount * netAmount / gross).round());

  /// The net part of the paid amount in forints: the sum of the payments'
  /// [netHuf].
  int get paidNetHuf => payments.fold(0, (sum, p) => sum + netHuf(p.amount));

  /// [paidNetHuf] of the payments in [year].
  int paidNetHufIn(int year) => payments
      .where((p) => p.date.year == year)
      .fold(0, (sum, p) => sum + netHuf(p.amount));

  /// The VAT of [netAmount] at the code's rate, rounded to the currency's
  /// unit.
  static int vatOf(int netAmount, VatCode code) =>
      ((netAmount * (code.rate ?? 0)) / 100).round();

  static String? _dateText(DateTime? date) =>
      date == null ? null : Entry.dateText(date);

  static DateTime? _date(Object? text) =>
      text == null ? null : DateTime.parse(text as String);

  factory Invoice.fromMap(Map<String, Object?> map) => Invoice(
    id: map['id'] as int,
    userId: map['user_id'] as int,
    direction: InvoiceDirection.values.byName(map['direction'] as String),
    number: map['number'] as String,
    description: map['description'] as String,
    partnerName: map['partner_name'] as String,
    partnerTaxNumber: map['partner_tax_number'] as String,
    partnerLocation: PartnerLocation.values.byName(
      map['partner_location'] as String,
    ),
    paymentMethod: PaymentMethod.values.byName(map['payment_method'] as String),
    issueDate: _date(map['issue_date'])!,
    fulfillmentDate: _date(map['fulfillment_date'])!,
    dueDate: _date(map['due_date']),
    currency: Currency.fromCode(map['currency'] as String),
    exchangeRate: map['exchange_rate'] as int,
    netAmount: map['net_amount'] as int,
    vatCode: VatCode.values.byName(map['vat_code'] as String),
    vatAmount: map['vat_amount'] as int,
    paidAccountId: map['paid_account_id'] as int?,
    paidExchangeRate: map['paid_exchange_rate'] as int?,
    categoryId: map['category_id'] as int?,
  );

  @override
  Map<String, Object?> toMap() => {
    'user_id': userId,
    'direction': direction.name,
    'number': number,
    'description': description,
    'partner_name': partnerName,
    'partner_tax_number': partnerTaxNumber,
    'partner_location': partnerLocation.name,
    'payment_method': paymentMethod.name,
    'issue_date': _dateText(issueDate),
    'fulfillment_date': _dateText(fulfillmentDate),
    'due_date': _dateText(dueDate),
    'currency': currency.code,
    'exchange_rate': exchangeRate,
    'net_amount': netAmount,
    'vat_code': vatCode.name,
    'vat_amount': vatAmount,
    'paid_account_id': paidAccountId,
    'paid_exchange_rate': paidExchangeRate,
    'category_id': categoryId,
  };

  /// A copy with the given fields; [paidAccountId] and [categoryId] give
  /// the new value (null too).
  Invoice copyWith({
    int? userId,
    List<InvoicePayment>? payments,
    int? Function()? paidAccountId,
    int? Function()? categoryId,
  }) => Invoice(
    id: id,
    userId: userId ?? this.userId,
    direction: direction,
    number: number,
    description: description,
    partnerName: partnerName,
    partnerTaxNumber: partnerTaxNumber,
    partnerLocation: partnerLocation,
    paymentMethod: paymentMethod,
    issueDate: issueDate,
    fulfillmentDate: fulfillmentDate,
    dueDate: dueDate,
    currency: currency,
    exchangeRate: exchangeRate,
    netAmount: netAmount,
    vatCode: vatCode,
    vatAmount: vatAmount,
    payments: payments ?? this.payments,
    paidAccountId: paidAccountId == null ? this.paidAccountId : paidAccountId(),
    paidExchangeRate: paidExchangeRate,
    categoryId: categoryId == null ? this.categoryId : categoryId(),
  );

  @override
  List<Object?> get props => [
    id,
    userId,
    direction,
    number,
    description,
    partnerName,
    partnerTaxNumber,
    partnerLocation,
    paymentMethod,
    issueDate,
    fulfillmentDate,
    dueDate,
    currency,
    exchangeRate,
    netAmount,
    vatCode,
    vatAmount,
    payments,
    paidAccountId,
    paidExchangeRate,
    categoryId,
  ];
}
