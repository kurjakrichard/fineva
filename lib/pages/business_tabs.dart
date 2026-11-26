import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../export/export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

// The tabs of the sole proprietors' pages: the business page, and an
// invoices only user's (Profile.invoicesOnly) invoices and flat-rate tax.

/// The invoices of the year, outgoing or incoming (chosen above them
/// unless [onDirectionChanged] is null), with their totals.
class InvoicesTab extends StatelessWidget {
  const InvoicesTab({
    super.key,
    required this.invoices,
    required this.profile,
    required this.year,
    this.direction = InvoiceDirection.outgoing,
    this.onDirectionChanged,
  });

  final List<Invoice> invoices;
  final Profile profile;
  final int year;
  final InvoiceDirection direction;
  final ValueChanged<InvoiceDirection>? onDirectionChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = [
      for (final invoice in invoices)
        if (invoice.direction == direction &&
            invoice.fulfillmentDate.year == year)
          invoice,
    ];
    // Numbered in the order of fulfillment, as in the income record.
    final numbers = {
      for (final (i, invoice) in shown.reversed.indexed) invoice: i + 1,
    };
    final gross = shown.fold(0, (sum, i) => sum + i.huf(i.gross));
    final open = shown.fold(0, (sum, i) => sum + i.huf(i.openAmount));
    final outgoing = direction == InvoiceDirection.outgoing;
    final onDirectionChanged = this.onDirectionChanged;
    // An invoices only user has the revenue record apart.
    final invoicesOnly = profile.invoicesOnly;

    return BusinessList(
      children: [
        if (onDirectionChanged != null) ...[
          Center(
            child: SegmentedButton<InvoiceDirection>(
              segments: [
                for (final d in InvoiceDirection.values)
                  ButtonSegment(
                    value: d,
                    label: Text(l10n.invoiceDirectionName(d)),
                  ),
              ],
              selected: {direction},
              onSelectionChanged: (value) => onDirectionChanged(value.first),
            ),
          ),
          const SizedBox(height: 12),
        ],
        BusinessCard(
          title: switch ((outgoing, invoicesOnly)) {
            (true, true) => l10n.outgoingInvoicesYear(year),
            (false, true) => l10n.incomingInvoicesYear(year),
            (true, false) => l10n.incomeRecord(year),
            (false, false) => l10n.costRecord(year),
          },
          children: [
            AmountRow(l10n.grossTotal, gross),
            AmountRow(l10n.openTotal, open),
            if (outgoing &&
                !invoicesOnly &&
                profile.taxRegime == TaxRegime.flatRate) ...[
              const SizedBox(height: 8),
              LimitBar(
                label: l10n.flatRateRevenue,
                used: FlatRateTax(invoices, profile, year).revenue,
                limit: TaxYear.of(year).flatRateRevenueLimit,
              ),
            ],
            if (outgoing && profile.taxRegime == TaxRegime.kata) ...[
              const SizedBox(height: 8),
              LimitBar(
                label: l10n.kataRevenue,
                used: kataRevenue(invoices, year),
                limit: TaxYear.kataRevenueLimit,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.kataTaxText(
                  Currency.huf.format(
                    TaxYear.kataMonthlyTax,
                    context.localeName,
                  ),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.noInvoices, textAlign: TextAlign.center),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final invoice in shown)
                  InvoiceTile(invoice: invoice, number: numbers[invoice]!),
              ],
            ),
          ),
      ],
    );
  }
}

/// The flat-rate tax of [year] (an invoices only user's page, the other
/// flat-rate users' business tab): a quarter ([FlatRateQuarterView]) or the
/// year's summary ([FlatRateSummaryView]), chosen at the top, beside it a
/// button to send or save what is shown (PDF, XLSX). The current quarter
/// first, the summary for another year, or [quarter].
class FlatRateTaxView extends StatefulWidget {
  const FlatRateTaxView({
    super.key,
    required this.profile,
    required this.invoices,
    required this.year,
    this.quarter,
  });

  final Profile profile;
  final List<Invoice> invoices;
  final int year;

  /// 1-4: the quarter shown first.
  final int? quarter;

  @override
  State<FlatRateTaxView> createState() => _FlatRateTaxViewState();
}

class _FlatRateTaxViewState extends State<FlatRateTaxView> {
  /// 1-4 a quarter, 0 the summary.
  late int _view = widget.quarter ?? _first(widget.year);

  /// The current quarter of this year, the summary of another.
  static int _first(int year) {
    final today = currentDay();
    return year == today.year ? (today.month - 1) ~/ 3 + 1 : 0;
  }

  @override
  void didUpdateWidget(FlatRateTaxView old) {
    super.didUpdateWidget(old);
    // Another year: its first.
    if (old.year != widget.year) _view = _first(widget.year);
  }

  void _show(int view) => setState(() => _view = view);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = widget.profile;
    final tax = FlatRateTax(widget.invoices, profile, widget.year);
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              // Changed from the summary too.
              key: ValueKey(_view),
              initialValue: _view,
              decoration: InputDecoration(labelText: l10n.period),
              items: [
                for (var q = 1; q <= 4; q++)
                  DropdownMenuItem(value: q, child: Text(l10n.quarterName(q))),
                DropdownMenuItem(value: 0, child: Text(l10n.flatRateSummary)),
              ],
              onChanged: (view) => _show(view!),
            ),
          ),
          const SizedBox(width: 4),
          // What is shown.
          SendReportButton(
            report: (l10n) => _view == 0
                ? flatRateSummaryReport(tax, profile, l10n)
                : flatRateQuarterReport(tax, _view, profile, l10n),
          ),
        ],
      ),
    );
    return _view == 0
        ? FlatRateSummaryView(tax: tax, header: header, onQuarter: _show)
        : FlatRateQuarterView(tax: tax, quarter: _view, header: header);
  }
}

/// One quarter of flat-rate taxation ([FlatRateTaxView]): [header] (the choice of the quarter), its taxes and deadline,
/// what to transfer, and the year up to its end (the revenue against the
/// limit, the taxes).
class FlatRateQuarterView extends StatelessWidget {
  const FlatRateQuarterView({
    super.key,
    required this.tax,
    required this.quarter,
    this.header,
  });

  final FlatRateTax tax;

  /// 1-4.
  final int quarter;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final upTo = tax.quarters.sublist(0, quarter);
    final payments = [
      for (final payment in tax.payments(quarter))
        if (payment.amount > 0) payment,
    ];
    return BusinessList(
      children: [
        ?header,
        ResponsiveRow(
          children: [
            _QuarterCard(
              quarter: tax.quarters[quarter - 1],
              costRatio: tax.costRatio,
            ),
            BusinessCard(
              title: l10n.toTransfer,
              children: [
                for (final payment in payments) TaxPaymentRow(payment: payment),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FlatRateYearCard(
          tax: tax,
          revenueLabel: l10n.cumulativeRevenue,
          revenue: upTo.fold(0, (sum, q) => sum + q.revenue),
          after: [
            AmountRow(
              l10n.taxesSoFar,
              upTo.fold(0, (sum, q) => sum + q.total),
              strong: true,
            ),
          ],
        ),
      ],
    );
  }
}

/// The year of flat-rate taxation summed up: [header] (the choice), the
/// revenue against the limit, the year's taxes by kind, and each quarter's
/// total with its deadline ([onQuarter] opens one).
class FlatRateSummaryView extends StatelessWidget {
  const FlatRateSummaryView({
    super.key,
    required this.tax,
    required this.onQuarter,
    this.header,
  });

  final FlatRateTax tax;
  final ValueChanged<int> onQuarter;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final quarters = tax.quarters;
    int sum(int Function(FlatRateQuarter q) of) =>
        quarters.fold(0, (total, q) => total + of(q));
    final chamberFee = sum((q) => q.chamberFee);
    return BusinessList(
      children: [
        ?header,
        _FlatRateYearCard(
          tax: tax,
          revenueLabel: l10n.flatRateRevenue,
          revenue: tax.revenue,
          // Revenue - costs = income - tax-free part = tax base.
          before: [
            AmountRow(l10n.revenue, tax.revenue),
            AmountRow(
              l10n.flatRateCost,
              sum((q) => q.cost),
              hint: l10n.costRatioHint(tax.costRatio),
            ),
            AmountRow(l10n.flatRateIncome, sum((q) => q.income)),
            AmountRow(
              l10n.taxFreePart,
              sum((q) => q.taxFreeIncome),
              hint: l10n.taxFreePartHint(
                Currency.huf.format(tax.taxYear.taxFreeIncome, locale),
              ),
            ),
            AmountRow(l10n.taxBase, sum((q) => q.taxableIncome), strong: true),
          ],
        ),
        const SizedBox(height: 12),
        ResponsiveRow(
          children: [
            BusinessCard(
              title: l10n.taxesOfYear,
              children: [
                AmountRow(l10n.szja, sum((q) => q.szja)),
                AmountRow(l10n.tbContribution, sum((q) => q.tb)),
                AmountRow(l10n.szocho, sum((q) => q.szocho)),
                AmountRow(l10n.localTax, sum((q) => q.localTax)),
                if (chamberFee > 0) AmountRow(l10n.chamberFee, chamberFee),
                AmountRow(l10n.total, tax.total, strong: true),
              ],
            ),
            BusinessCard(
              title: l10n.quarters,
              children: [
                for (final quarter in quarters)
                  InkWell(
                    onTap: () => onQuarter(quarter.quarter),
                    child: AmountRow(
                      l10n.quarterName(quarter.quarter),
                      quarter.total,
                      hint: l10n.deadline(
                        DateFormat.yMMMd(locale).format(quarter.deadline),
                      ),
                    ),
                  ),
                AmountRow(l10n.total, tax.total, strong: true),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// The year's card: [revenue] (labelled [revenueLabel]) against the limit,
/// a warning above it, a note of the tax-free revenue, the rows [before]
/// and [after] (the calculation), a note for a year whose amounts aren't
/// known yet.
class _FlatRateYearCard extends StatelessWidget {
  const _FlatRateYearCard({
    required this.tax,
    required this.revenueLabel,
    required this.revenue,
    this.before = const [],
    this.after = const [],
  });

  final FlatRateTax tax;
  final String revenueLabel;
  final int revenue;
  final List<Widget> before;
  final List<Widget> after;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final scheme = Theme.of(context).colorScheme;
    final taxYear = tax.taxYear;
    return BusinessCard(
      title: l10n.flatRateYear(taxYear.year),
      children: [
        LimitBar(label: revenueLabel, used: revenue, limit: tax.revenueLimit),
        if (revenue > tax.revenueLimit) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.warning_amber, color: scheme.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.flatRateOverLimit,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        // Not a result: the revenue up to which there is no tax.
        Text(
          l10n.taxFreeRevenueNote(
            Currency.huf.format(tax.taxFreeRevenue, locale),
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        ...before,
        ...after,
        if (!taxYear.isKnown) ...[
          const SizedBox(height: 8),
          Text(
            l10n.taxYearUnknown(taxYear.year, TaxYear.known.last.year),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// A quarter's taxes and deadline; its costs at [costRatio] percent.
class _QuarterCard extends StatelessWidget {
  const _QuarterCard({required this.quarter, required this.costRatio});

  final FlatRateQuarter quarter;
  final int costRatio;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final huf = Currency.huf;
    return BusinessCard(
      title: l10n.quarterName(quarter.quarter),
      trailing: Text(
        l10n.deadline(DateFormat.yMMMd(locale).format(quarter.deadline)),
        style: textTheme.bodySmall,
      ),
      children: [
        AmountRow(l10n.revenue, quarter.revenue),
        // How the income, the tax base comes out.
        AmountRow(
          l10n.flatRateCost,
          quarter.cost,
          hint: l10n.costRatioHint(costRatio),
        ),
        AmountRow(l10n.flatRateIncome, quarter.income),
        // What is left of the year's tax-free part.
        AmountRow(l10n.taxFreePart, quarter.taxFreeIncome),
        AmountRow(l10n.taxBase, quarter.taxableIncome, strong: true),
        const Divider(),
        AmountRow(l10n.szja, quarter.szja),
        AmountRow(
          l10n.tbContribution,
          quarter.tb,
          hint: l10n.baseHint(huf.format(quarter.contributionBase, locale)),
        ),
        AmountRow(
          l10n.szocho,
          quarter.szocho,
          hint: l10n.baseHint(huf.format(quarter.szochoBase, locale)),
        ),
        AmountRow(l10n.localTax, quarter.localTax),
        if (quarter.chamberFee > 0)
          AmountRow(l10n.chamberFee, quarter.chamberFee),
        AmountRow(l10n.total, quarter.total, strong: true),
      ],
    );
  }
}

/// The VAT of a return period: payable, deductible, balance.
class VatTab extends StatefulWidget {
  const VatTab({
    super.key,
    required this.invoices,
    required this.profile,
    required this.year,
  });

  final List<Invoice> invoices;
  final Profile profile;
  final int year;

  @override
  State<VatTab> createState() => _VatTabState();
}

class _VatTabState extends State<VatTab> {
  int? _index;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final profile = widget.profile;
    // An exempt sole proprietor with EU reporting files quarterly.
    final vatPeriod = profile.vatStatus == VatStatus.registered
        ? profile.vatPeriod
        : VatPeriod.quarterly;
    final periods = VatReturnPeriod.ofYear(widget.year, vatPeriod);
    final now = DateTime.now();
    final index =
        (_index ??
                periods
                    .indexWhere((p) => p.contains(now))
                    .clamp(0, periods.length - 1))
            .clamp(0, periods.length - 1);
    final summaries = [
      for (final period in periods)
        VatSummary(widget.invoices, profile, period),
    ];
    final summary = summaries[index];
    // A negative balance of the periods before is carried forward.
    final carriedIn = vatCarriedIn(summaries)[index];
    final balance = summary.balance + carriedIn;

    String periodName(VatReturnPeriod period) => switch (vatPeriod) {
      VatPeriod.monthly => DateFormat.MMM(locale).format(period.start),
      VatPeriod.quarterly => l10n.quarterName(period.start.month ~/ 3 + 1),
      VatPeriod.yearly => '${period.start.year}',
    };

    return BusinessList(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final (i, period) in periods.indexed)
              ChoiceChip(
                label: Text(periodName(period)),
                selected: i == index,
                onSelected: (_) => setState(() => _index = i),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.vatDateRuleText(Invoice.vatDateDays),
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        BusinessCard(
          title: l10n.vatPayable,
          trailing: Text(
            l10n.deadline(
              DateFormat.yMMMd(locale).format(periods[index].deadline),
            ),
            style: textTheme.bodySmall,
          ),
          children: [
            for (final rate in [27, 18, 5, 0])
              if (summary.payable[rate] case final line?)
                AmountRow(
                  '$rate%',
                  line.vat,
                  hint: l10n.baseHint(Currency.huf.format(line.base, locale)),
                ),
            if (summary.reverseCharge.base != 0)
              AmountRow(
                l10n.reverseCharge,
                summary.reverseCharge.vat,
                hint: l10n.baseHint(
                  Currency.huf.format(summary.reverseCharge.base, locale),
                ),
              ),
            AmountRow(l10n.vatTotalRounded, summary.totalPayable, strong: true),
          ],
        ),
        const SizedBox(height: 12),
        if (summary.registered) ...[
          BusinessCard(
            title: l10n.vatDeductible,
            children: [
              for (final rate in [27, 18, 5, 0])
                if (summary.deductible[rate] case final line?)
                  AmountRow(
                    '$rate%',
                    line.vat,
                    hint: l10n.baseHint(Currency.huf.format(line.base, locale)),
                  ),
              if (summary.reverseCharge.base != 0)
                AmountRow(l10n.reverseCharge, summary.reverseCharge.vat),
              AmountRow(
                l10n.vatTotalRounded,
                summary.totalDeductible,
                strong: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ] else ...[
          Text(l10n.vatExemptReverseChargeText, style: textTheme.bodySmall),
          const SizedBox(height: 12),
        ],
        BusinessCard(
          title: balance >= 0 ? l10n.vatToPay : l10n.vatToReclaim,
          trailing: Text(
            Currency.huf.format(balance.abs(), locale),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          children: [
            if (carriedIn != 0) ...[
              AmountRow(l10n.vatPeriodBalance, summary.balance),
              AmountRow(l10n.vatCarriedIn, carriedIn),
            ],
            if (summary.exemptSales.isNotEmpty) ...[
              Text(l10n.salesWithoutVat, style: textTheme.titleSmall),
              for (final location in PartnerLocation.values)
                if (summary.exemptSales[location] case final amount?)
                  AmountRow(l10n.partnerLocationName(location), amount),
            ],
          ],
        ),
      ],
    );
  }
}
