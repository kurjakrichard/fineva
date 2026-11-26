import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';

/// The lines saying whose a record is and when it was made: the name, tax
/// number and tax identification number, the address, the day made.
List<String> profileHeader(
  Profile profile,
  AppLocalizations l10n, {
  DateTime? madeOn,
}) => [
  [
    profile.name,
    if (profile.taxNumber.isNotEmpty) '${l10n.taxNumber}: ${profile.taxNumber}',
    if (profile.taxId.isNotEmpty) '${l10n.taxId}: ${profile.taxId}',
  ].join(' · '),
  if (profile.address.isNotEmpty) profile.address,
  l10n.reportMadeOn(
    DateFormat.yMMMd(l10n.localeName).format(madeOn ?? DateTime.now()),
  ),
];
