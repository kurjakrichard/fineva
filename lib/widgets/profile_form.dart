import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../utils/utils.dart';
import 'choice_card.dart';
import 'main_currency_field.dart';
import 'tax_number_field.dart';

/// Personal or sole proprietor finances. A sole proprietor needs a valid
/// Hungarian tax number, asked for right under the choice: put it in a
/// [Form], which doesn't validate without one.
///
/// The kind is chosen only for a new user (without id): a user's kind
/// doesn't change, their data and categories are of that kind.
class UserTypeChoice extends StatelessWidget {
  const UserTypeChoice({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final Profile profile;
  final ValueChanged<Profile> onChanged;

  bool get _canChoose => profile.id == null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceCard(
          icon: Icons.person,
          title: l10n.userTypePersonal,
          subtitle: l10n.userTypePersonalText,
          selected: !profile.isSoleProprietor,
          onTap: _canChoose
              ? () => onChanged(profile.copyWith(userType: UserType.personal))
              : null,
        ),
        ChoiceCard(
          icon: Icons.storefront,
          title: l10n.userTypeSoleProprietor,
          subtitle: l10n.userTypeSoleProprietorText,
          selected: profile.isSoleProprietor,
          onTap: _canChoose
              ? () => onChanged(
                  profile.copyWith(userType: UserType.soleProprietor),
                )
              : null,
        ),
        if (!_canChoose)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              l10n.userTypeFixed,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (profile.isSoleProprietor) ...[
          const SizedBox(height: 12),
          TaxNumberField(
            initialValue: profile.taxNumber,
            required: true,
            requiredText: l10n.taxNumberRequired,
            helperText: l10n.taxNumberHelper,
            onChanged: (taxNumber) =>
                onChanged(profile.copyWith(taxNumber: taxNumber)),
          ),
        ],
      ],
    );
  }
}

/// The user's name, address and tax identification number. Put it in a
/// [Form]: the name is required, the tax identification number is checked
/// when given, and passed to [onChanged] in its stored form once it is
/// valid (see [parseTaxId]). (A sole proprietor's tax number is asked by
/// [UserTypeChoice].)
class UserDataForm extends StatelessWidget {
  const UserDataForm({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final Profile profile;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The fields validate while typed only once they were wrong.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        TextFormField(
          initialValue: profile.name,
          decoration: InputDecoration(labelText: l10n.name),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          autovalidateMode: AutovalidateMode.onUserInteractionIfError,
          validator: (text) =>
              (text ?? '').trim().isEmpty ? l10n.nameRequired : null,
          onChanged: (text) => onChanged(profile.copyWith(name: text.trim())),
        ),
        TextFormField(
          initialValue: profile.address,
          decoration: InputDecoration(
            labelText: l10n.address,
            hintText: l10n.addressHint,
          ),
          keyboardType: TextInputType.streetAddress,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.fullStreetAddress],
          onChanged: (text) =>
              onChanged(profile.copyWith(address: text.trim())),
        ),
        TextFormField(
          initialValue: profile.taxId,
          decoration: InputDecoration(
            labelText: l10n.taxId,
            helperText: l10n.taxIdHelper,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          textInputAction: TextInputAction.done,
          autovalidateMode: AutovalidateMode.onUserInteractionIfError,
          validator: (text) => _validate(text, parseTaxId, l10n.taxIdInvalid),
          onChanged: (text) => onChanged(
            profile.copyWith(taxId: parseTaxId(text) ?? text.trim()),
          ),
        ),
        // Chosen once, by a new personal user; a sole proprietor's is HUF.
        if (!profile.isSoleProprietor && profile.id == null)
          MainCurrencyField(
            value: profile.mainCurrency,
            onChanged: (currency) => onChanged(
              profile.copyWith(
                mainCurrency: currency,
                // The usual source of the currency.
                rateSource: RateSource.defaultFor(currency),
              ),
            ),
          ),
      ],
    );
  }

  // Empty is fine; otherwise [parse] must accept it.
  static String? _validate(
    String? text,
    String? Function(String) parse,
    String error,
  ) {
    if (text == null || text.trim().isEmpty) return null;
    return parse(text) == null ? error : null;
  }
}

/// A sole proprietor's taxation, VAT and EU reporting. Put it in a [Form]:
/// with EU reporting the EU VAT number is required, and must match the tax
/// number if there is one.
class BusinessProfileForm extends StatelessWidget {
  const BusinessProfileForm({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final Profile profile;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.taxRegime, style: titleStyle),
        const SizedBox(height: 8),
        for (final regime in TaxRegime.values)
          ChoiceCard(
            title: l10n.taxRegimeName(regime),
            subtitle: switch (regime) {
              TaxRegime.itemized => l10n.taxRegimeItemizedText,
              TaxRegime.flatRate => l10n.taxRegimeFlatRateText,
              TaxRegime.kata => l10n.taxRegimeKataText,
            },
            selected: profile.taxRegime == regime,
            onTap: () => onChanged(profile.copyWith(taxRegime: regime)),
          ),
        if (profile.taxRegime == TaxRegime.flatRate) ...[
          const SizedBox(height: 16),
          Text(l10n.costRatio, style: titleStyle),
          const SizedBox(height: 8),
          for (final ratio in Profile.costRatios)
            ChoiceCard(
              title: '$ratio%',
              subtitle: l10n.costRatioText(ratio),
              selected: profile.costRatio == ratio,
              onTap: () => onChanged(profile.copyWith(costRatio: ratio)),
            ),
          const SizedBox(height: 8),
          _SwitchCard(
            title: l10n.mainOccupation,
            subtitle: l10n.mainOccupationText,
            value: profile.mainOccupation,
            onChanged: (value) =>
                onChanged(profile.copyWith(mainOccupation: value)),
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.vat, style: titleStyle),
        const SizedBox(height: 8),
        for (final status in VatStatus.values)
          ChoiceCard(
            title: l10n.vatStatusName(status),
            subtitle: switch (status) {
              VatStatus.exempt => l10n.vatExemptText,
              VatStatus.registered => l10n.vatRegisteredText,
            },
            selected: profile.vatStatus == status,
            onTap: () => onChanged(profile.copyWith(vatStatus: status)),
          ),
        if (profile.vatStatus == VatStatus.registered) ...[
          const SizedBox(height: 16),
          Text(l10n.vatPeriod, style: titleStyle),
          const SizedBox(height: 8),
          SegmentedButton<VatPeriod>(
            segments: [
              for (final period in VatPeriod.values)
                ButtonSegment(
                  value: period,
                  label: Text(l10n.vatPeriodName(period)),
                ),
            ],
            selected: {profile.vatPeriod},
            onSelectionChanged: (value) =>
                onChanged(profile.copyWith(vatPeriod: value.first)),
          ),
        ],
        const SizedBox(height: 16),
        _SwitchCard(
          title: l10n.euReporting,
          subtitle: l10n.euReportingText,
          value: profile.euReporting,
          onChanged: (value) => onChanged(
            profile.copyWith(
              euReporting: value,
              euVatNumber: value ? _suggestedEuVatNumber() : null,
            ),
          ),
        ),
        if (profile.euReporting) ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: profile.euVatNumber,
            decoration: InputDecoration(
              labelText: l10n.euVatNumber,
              hintText: 'HU12345678',
              helperText: l10n.euVatNumberHelper,
            ),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[HUhu\d ]')),
              LengthLimitingTextInputFormatter(12),
            ],
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteractionIfError,
            validator: (text) => _validateEuVatNumber(text ?? '', l10n),
            onChanged: (text) => onChanged(
              profile.copyWith(
                euVatNumber: parseEuVatNumber(text) ?? text.trim(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // The one the tax number gives, if there is no EU VAT number yet.
  String? _suggestedEuVatNumber() {
    if (profile.euVatNumber.isNotEmpty) return null;
    final taxNumber = parseTaxNumber(profile.taxNumber);
    return taxNumber == null ? null : 'HU${taxNumberBase(taxNumber)}';
  }

  String? _validateEuVatNumber(String text, AppLocalizations l10n) {
    if (text.trim().isEmpty) return l10n.euVatNumberRequired;
    final euVatNumber = parseEuVatNumber(text);
    if (euVatNumber == null) return l10n.euVatNumberInvalid;
    final taxNumber = parseTaxNumber(profile.taxNumber);
    if (taxNumber != null && 'HU${taxNumberBase(taxNumber)}' != euVatNumber) {
      return l10n.euVatNumberMismatch;
    }
    return null;
  }
}

/// A switch with a title and an explanation in an outlined card, like a
/// [ChoiceCard].
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    ),
  );
}
