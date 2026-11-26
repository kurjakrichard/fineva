import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';
import 'business_itemized.dart';
import 'business_tabs.dart';

/// A sole proprietor's records of a year, driven by the profile: the
/// invoices (for KATA only these, with the revenue limit), for flat-rate
/// taxation the income record and the quarterly taxes, for VAT the
/// summary of each return period.
class BusinessPage extends ConsumerStatefulWidget {
  static BusinessPage builder(BuildContext context, GoRouterState state) =>
      const BusinessPage();

  const BusinessPage({super.key});

  @override
  ConsumerState<BusinessPage> createState() => _BusinessPageState();
}

class _BusinessPageState extends ConsumerState<BusinessPage> {
  InvoiceDirection _direction = InvoiceDirection.outgoing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(financeProvider);
    final profile = state.profile;
    final compact = ScreenSize.of(context).isCompact;
    final year = ref.watch(businessYearProvider);

    final Widget body;
    var tabs = <(String, Widget)>[];
    if (profile == null || !profile.isSoleProprietor) {
      body = _Message(text: l10n.businessOnlyText);
    } else if (!profile.isComplete) {
      body = _Message(
        text: l10n.businessIncompleteText,
        action: FilledButton(
          onPressed: () => context.pushNamed(Routes.profile.name),
          child: Text(l10n.profile),
        ),
      );
    } else {
      tabs = [
        (
          l10n.invoices,
          InvoicesTab(
            invoices: state.invoices,
            profile: profile,
            year: year,
            direction: _direction,
            onDirectionChanged: (d) => setState(() => _direction = d),
          ),
        ),
        if (profile.taxRegime == TaxRegime.flatRate)
          (
            l10n.taxRegimeFlatRate,
            FlatRateTaxView(
              profile: profile,
              invoices: state.invoices,
              year: year,
            ),
          ),
        if (profile.taxRegime == TaxRegime.itemized) ...[
          (l10n.itemizedTab, ItemizedTaxTab(state: state, year: year)),
          (l10n.assets, AssetsTab(assets: state.assets, year: year)),
        ],
        if (profile.vatStatus == VatStatus.registered || profile.euReporting)
          (
            l10n.vat,
            VatTab(invoices: state.invoices, profile: profile, year: year),
          ),
      ];
      body = tabs.length == 1
          ? tabs.single.$2
          : TabBarView(children: [for (final tab in tabs) tab.$2]);
    }

    return DefaultTabController(
      // New tabs when the profile changes them.
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.business),
          actions: const [YearBar()],
          bottom: tabs.length < 2
              ? null
              : TabBar(
                  isScrollable: compact,
                  tabAlignment: compact
                      ? TabAlignment.start
                      : TabAlignment.center,
                  labelColor: scheme.onPrimary,
                  unselectedLabelColor: scheme.onPrimary.withValues(alpha: 0.7),
                  indicatorColor: scheme.onPrimary,
                  dividerColor: Colors.transparent,
                  tabs: [for (final tab in tabs) Tab(text: tab.$1)],
                ),
        ),
        drawer: mainDrawer(context, MainDestination.business),
        floatingActionButton: tabs.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () =>
                    context.pushNamed(Routes.invoice.name, extra: _direction),
                icon: const Icon(Icons.add),
                label: Text(l10n.addInvoice),
              ),
        body: body,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}
