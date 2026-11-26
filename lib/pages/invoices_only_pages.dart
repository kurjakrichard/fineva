import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../export/export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';
import 'business_tabs.dart';
import 'invoice_page.dart';

// The menu's pages of an invoices only user (Profile.invoicesOnly: a
// flat-rate, VAT exempt sole proprietor): the invoices, the revenue record
// and the flat-rate tax, each of the year in the app bar (YearBar, shared).

/// The invoices of the year: the outgoing ones; with EU reporting the
/// incoming ones too (`Profile.incomingInvoices`).
class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  InvoiceDirection _direction = InvoiceDirection.outgoing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(financeProvider);
    final profile = state.profile;
    final incoming = profile?.incomingInvoices ?? false;
    final direction = incoming ? _direction : InvoiceDirection.outgoing;
    return Scaffold(
      appBar: AppBar(
        title: _Title(MainDestination.invoices.label(l10n, profile)),
        actions: const [YearBar()],
      ),
      drawer: mainDrawer(context, MainDestination.invoices),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.pushNamed(Routes.invoice.name, extra: direction),
        icon: const Icon(Icons.add),
        label: Text(l10n.addInvoice),
      ),
      body: _SoleProprietorContent(
        state: state,
        builder: (profile) => InvoicesTab(
          invoices: state.invoices,
          profile: profile,
          year: ref.watch(businessYearProvider),
          direction: direction,
          onDirectionChanged: incoming
              ? (d) => setState(() => _direction = d)
              : null,
        ),
      ),
    );
  }
}

/// The revenue record (bevételi nyilvántartás) of the year: the revenues
/// received (the payments of the outgoing invoices), in the order received,
/// by month, with the running total and the revenue limit
/// ([RevenueRecord]). A revenue is recorded as it came in on the bank
/// account or in the till: as a payment of an open invoice, or with a new
/// invoice ([addRevenue]); tapping one edits it: its payment, or the
/// invoice it belongs to if chosen wrong ([_editRevenue]).
class RevenueRecordPage extends ConsumerWidget {
  const RevenueRecordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(financeProvider);
    final year = ref.watch(businessYearProvider);
    return Scaffold(
      appBar: AppBar(
        title: _Title(l10n.revenueRecord),
        actions: [
          SendReportButton(
            report: (l10n) {
              final state = ref.read(financeProvider);
              final profile = state.profile;
              if (profile == null) return null;
              return revenueRecordReport(
                RevenueRecord(state.invoices, ref.read(businessYearProvider)),
                profile,
                l10n,
              );
            },
          ),
          const YearBar(),
        ],
      ),
      drawer: mainDrawer(context, MainDestination.revenueRecord),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addRevenue(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.addRevenue),
      ),
      body: _SoleProprietorContent(
        state: state,
        builder: (profile) =>
            _RevenueRecordView(record: RevenueRecord(state.invoices, year)),
      ),
    );
  }
}

/// A new revenue: a payment of an open outgoing invoice chosen, or a new
/// invoice paid the whole today ([PaidInvoice]).
Future<void> addRevenue(BuildContext context, WidgetRef ref) async {
  final state = ref.read(financeProvider);
  final open = [
    for (final invoice in state.invoices)
      if (invoice.direction == InvoiceDirection.outgoing &&
          invoice.openAmount != 0)
        invoice,
  ];
  final choice = await showInvoiceChoice(
    context,
    invoices: open,
    title: context.l10n.addRevenue,
    text: context.l10n.chooseInvoiceText,
    withNew: true,
  );
  if (!context.mounted) return;
  if (choice == NewInvoiceChoice.chosen) {
    await context.pushNamed(
      Routes.invoice.name,
      extra: PaidInvoice(currentDay()),
    );
    return;
  }
  // Closed without a choice.
  if (choice is! Invoice) return;
  final result = await showPaymentDialog(
    context,
    invoice: choice,
    max: choice.openAmount,
  );
  if (result is! PaymentSaved || !context.mounted) return;
  final ok = await ref
      .read(financeProvider.notifier)
      .savePayment(choice, result.payment);
  if (!ok && context.mounted) showMessage(context, context.l10n.saveError);
}

/// Edits a revenue [line], its payment: the day, amount, method and note;
/// or the invoice it is a payment of, if chosen wrong (another open one,
/// another partner's too: it moves there as it is); or deletes it. (The
/// invoice itself is put right in the invoices.)
Future<void> _editRevenue(
  BuildContext context,
  WidgetRef ref,
  RevenueLine line,
) async {
  final state = ref.read(financeProvider);
  final invoice = line.invoice;
  final payment = line.payment;
  final result = await showPaymentDialog(
    context,
    invoice: invoice,
    payment: payment,
    max: invoice.openAmount + payment.amount,
    invoices: [
      for (final other in state.invoices)
        if (other.direction == InvoiceDirection.outgoing &&
            (other.id == invoice.id || other.openAmount != 0))
          other,
    ],
  );
  if (!context.mounted || result == null) return;
  final notifier = ref.read(financeProvider.notifier);
  final ok = switch (result) {
    PaymentSaved(:final payment, invoice: final other?) =>
      await notifier.savePayment(other, payment, from: invoice),
    PaymentSaved(:final payment) => await notifier.savePayment(
      invoice,
      payment,
    ),
    PaymentDeleted() => await notifier.deletePayment(invoice, payment),
  };
  if (!ok && context.mounted) showMessage(context, context.l10n.saveError);
}

class _RevenueRecordView extends StatelessWidget {
  const _RevenueRecordView({required this.record});

  final RevenueRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final year = record.year;
    return BusinessList(
      children: [
        BusinessCard(
          title: l10n.incomeRecord(year),
          children: [
            AmountRow(l10n.revenueReceived, record.total, strong: true),
            const SizedBox(height: 8),
            LimitBar(
              label: l10n.flatRateRevenue,
              used: record.total,
              limit: TaxYear.of(year).flatRateRevenueLimit,
            ),
            const SizedBox(height: 8),
            Text(l10n.revenueRecordText, style: textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 12),
        if (record.lines.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.noRevenue, textAlign: TextAlign.center),
          ),
        for (final MapEntry(key: month, value: total)
            in record.months.entries) ...[
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          toBeginningOfSentenceCase(
                            DateFormat.MMMM(locale)
                                .format(DateTime(year, month)),
                            locale,
                          ),
                          style: textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        Currency.huf.format(total, locale),
                        style: textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                for (final line in record.lines)
                  if (line.date.month == month) _RevenueTile(line: line),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// A revenue received: its number, the invoice, the day, the amount and the
/// running total. Tapping it opens the invoice.
class _RevenueTile extends ConsumerWidget {
  const _RevenueTile({required this.line});

  final RevenueLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final invoice = line.invoice;
    final huf = Currency.huf;
    final partner = invoice.partnerName;
    return RecordTile(
      onTap: () => _editRevenue(context, ref, line),
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: Text('${line.number}', style: textTheme.labelMedium),
      ),
      title: partner.isEmpty ? invoice.number : partner,
      amount: huf.format(line.amount, locale),
      details: [
        if (partner.isNotEmpty) invoice.number,
        // Under its month, in the year of the page.
        DateFormat.MMMd(locale).format(line.date),
        l10n.paymentMethodName(line.payment.method),
        // What came in, in the invoice's own currency.
        if (invoice.currency != huf)
          invoice.currency.format(line.payment.amount, locale),
        if (line.payment.note.isNotEmpty) line.payment.note,
        if (invoice.description.isNotEmpty) invoice.description,
      ].join(' · '),
      footer: Text(
        l10n.cumulativeAmount(huf.format(line.cumulative, locale)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// The flat-rate tax of the year ([FlatRateTaxView]: a quarter or the
/// year's summary, chosen at the top, sent or saved from there); the
/// current quarter first, or [quarter] (`?quarter=` of the route, from the
/// dashboard's next payment). With EU reporting the VAT (reverse charge, EU
/// sales) on a tab beside it.
class FlatRateTaxPage extends ConsumerWidget {
  const FlatRateTaxPage({super.key, this.quarter});

  /// 1-4: the quarter shown first.
  final int? quarter;

  /// The page with [quarter] shown first.
  static String location(int quarter) =>
      '${Routes.flatRate.path}?quarter=$quarter';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(financeProvider);
    final year = ref.watch(businessYearProvider);
    final withVat = state.profile?.euReporting ?? false;
    Widget flatRate(Profile profile) => FlatRateTaxView(
      profile: profile,
      invoices: state.invoices,
      year: year,
      quarter: quarter,
    );
    return DefaultTabController(
      key: ValueKey(withVat),
      length: withVat ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: _Title(l10n.taxRegimeFlatRate),
          actions: const [YearBar()],
          bottom: !withVat
              ? null
              : TabBar(
                  labelColor: scheme.onPrimary,
                  unselectedLabelColor: scheme.onPrimary.withValues(alpha: 0.7),
                  indicatorColor: scheme.onPrimary,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: l10n.taxRegimeFlatRate),
                    Tab(text: l10n.vat),
                  ],
                ),
        ),
        drawer: mainDrawer(context, MainDestination.flatRate),
        body: _SoleProprietorContent(
          state: state,
          builder: (profile) => !withVat
              ? flatRate(profile)
              : TabBarView(
                  children: [
                    flatRate(profile),
                    VatTab(
                      invoices: state.invoices,
                      profile: profile,
                      year: year,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// An app bar's title, smaller on a narrow phone beside the year.
class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Text(text),
  );
}

/// [builder] with the sole proprietor once the data is loaded
/// ([FinanceContent]); a note for anyone else, or to complete the profile.
class _SoleProprietorContent extends StatelessWidget {
  const _SoleProprietorContent({required this.state, required this.builder});

  final FinanceState state;
  final Widget Function(Profile profile) builder;

  @override
  Widget build(BuildContext context) => FinanceContent(
    state: state,
    builder: (context) {
      final l10n = context.l10n;
      final profile = state.profile;
      if (profile == null || !profile.isSoleProprietor) {
        return _Note(text: l10n.businessOnlyText);
      }
      if (!profile.isComplete) {
        return _Note(
          text: l10n.businessIncompleteText,
          action: FilledButton(
            onPressed: () => context.pushNamed(Routes.profile.name),
            child: Text(l10n.profile),
          ),
        );
      }
      return builder(profile);
    },
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action case final action?) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    ),
  );
}
