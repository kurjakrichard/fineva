import 'package:equatable/equatable.dart';

import '../../utils/utils.dart';
import 'db_model.dart';

/// A user: name, address and tax identifiers, and what they chose in the
/// onboarding: personal or sole proprietor finances, and the sole
/// proprietor's taxation. Every user has their own accounts and categories
/// (and so entries). None until the first onboarding is finished.
///
/// The business fields (and [taxNumber]) are kept for a personal profile
/// too, so switching back to sole proprietor restores them.
class Profile extends Equatable implements DbModel {
  const Profile({
    this.id,
    this.name = '',
    this.address = '',
    this.taxId = '',
    this.taxNumber = '',
    this.userType = UserType.personal,
    this.taxRegime = TaxRegime.flatRate,
    this.vatStatus = VatStatus.exempt,
    this.euReporting = false,
    this.euVatNumber = '',
    this.vatPeriod = VatPeriod.quarterly,
    this.costRatio = 45,
    this.mainOccupation = true,
    this.mainCurrency = Currency.huf,
    this.rateSource = RateSource.mnb,
    this.rateSourceReported = false,
  });

  /// The cost ratios (költséghányad) of flat-rate taxation in percent:
  /// general, the activities the law lists, retail.
  static const List<int> costRatios = [45, 80, 90];

  static const String table = 'profiles';

  /// Null until saved.
  @override
  final int? id;

  /// The user's name. Empty only in a profile saved before schema 3.
  final String name;

  /// Postal address in one line: "1234 Budapest, Fő utca 1."
  final String address;

  /// Tax identification number of a private person (adóazonosító jel): 10
  /// digits, see [parseTaxId]. Empty if not given.
  final String taxId;

  /// Tax number of a sole proprietor (adószám) as 12345678-1-12, see
  /// [parseTaxNumber]. Empty if not given.
  final String taxNumber;

  final UserType userType;
  final TaxRegime taxRegime;
  final VatStatus vatStatus;

  /// Has an EU VAT number and files the recapitulative statement of
  /// intra-EU transactions (közösségi adószám, összesítő nyilatkozat).
  final bool euReporting;

  /// The EU VAT number (közösségi adószám) as HU12345678, see
  /// [parseEuVatNumber]. Required for [euReporting], empty otherwise.
  final String euVatNumber;

  /// How often the VAT return is filed, if [VatStatus.registered].
  final VatPeriod vatPeriod;

  /// The cost ratio of flat-rate taxation in percent, one of [costRatios].
  final int costRatio;

  /// Főfoglalkozású: no employment of at least 36 hours a week beside the
  /// business, so the minimum contribution bases apply (flat-rate tax).
  final bool mainOccupation;

  /// The currency the dashboard and the statistics show everything in,
  /// converted at [rateSource]'s rates. Always HUF for a sole proprietor
  /// (the taxes are in forints); a personal user chooses it.
  final Currency mainCurrency;

  /// Where the rates for [mainCurrency] come from; manual rates are used
  /// with any source, on their own day before a downloaded one. For a sole
  /// proprietor see [rateSourceInUse].
  final RateSource rateSource;

  /// A sole proprietor's choice of the MNB's or the ECB's rate is reported
  /// to NAV (since schema 16); without it (the law's default) the rate of
  /// their own credit institution is typed in.
  final bool rateSourceReported;

  /// The rates used: [rateSource], but for a sole proprietor only if
  /// [rateSourceReported], otherwise their own bank's typed in (manual).
  /// The choice is for a whole year.
  RateSource get rateSourceInUse =>
      isSoleProprietor && !rateSourceReported ? RateSource.manual : rateSource;

  bool get isSoleProprietor => userType == UserType.soleProprietor;

  /// Keeps only invoices: a flat-rate, VAT exempt sole proprietor (the
  /// revenue record and the taxes come from the outgoing invoices). No
  /// accounts, entries or balances: their menu is the invoices, the
  /// revenue record and the flat-rate tax, a paid invoice isn't booked.
  /// (One who wants accounts makes a personal user.)
  bool get invoicesOnly =>
      isSoleProprietor &&
      taxRegime == TaxRegime.flatRate &&
      vatStatus == VatStatus.exempt;

  /// Can record incoming invoices: everyone but an [invoicesOnly] user
  /// without EU reporting (one with it self-assesses the VAT of the EU
  /// services they buy).
  bool get incomingInvoices => !invoicesOnly || euReporting;

  /// Everything the onboarding requires is there: a name, and for a sole
  /// proprietor a valid tax number (and EU VAT number for EU reporting).
  /// Users saved by older versions may lack them.
  bool get isComplete =>
      name.isNotEmpty &&
      (!isSoleProprietor ||
          (parseTaxNumber(taxNumber) != null &&
              (!euReporting || parseEuVatNumber(euVatNumber) != null)));

  factory Profile.fromMap(Map<String, Object?> map) => Profile(
    id: map['id'] as int,
    name: map['name'] as String,
    address: map['address'] as String,
    taxId: map['tax_id'] as String,
    taxNumber: map['tax_number'] as String,
    userType: UserType.values.byName(map['user_type'] as String),
    taxRegime: TaxRegime.values.byName(map['tax_regime'] as String),
    vatStatus: VatStatus.values.byName(map['vat_status'] as String),
    euReporting: map['eu_reporting'] == 1,
    euVatNumber: map['eu_vat_number'] as String,
    vatPeriod: VatPeriod.values.byName(map['vat_period'] as String),
    costRatio: map['cost_ratio'] as int,
    mainOccupation: map['main_occupation'] == 1,
    mainCurrency: Currency.fromCode(map['main_currency'] as String),
    rateSource: RateSource.values.byName(map['rate_source'] as String),
    rateSourceReported: map['rate_source_reported'] == 1,
  );

  @override
  Map<String, Object?> toMap() => {
    'name': name,
    'address': address,
    'tax_id': taxId,
    'tax_number': taxNumber,
    'user_type': userType.name,
    'tax_regime': taxRegime.name,
    'vat_status': vatStatus.name,
    'eu_reporting': euReporting ? 1 : 0,
    'eu_vat_number': euVatNumber,
    'vat_period': vatPeriod.name,
    'cost_ratio': costRatio,
    'main_occupation': mainOccupation ? 1 : 0,
    'main_currency': mainCurrency.code,
    'rate_source': rateSource.name,
    'rate_source_reported': rateSourceReported ? 1 : 0,
  };

  Profile copyWith({
    String? name,
    String? address,
    String? taxId,
    String? taxNumber,
    UserType? userType,
    TaxRegime? taxRegime,
    VatStatus? vatStatus,
    bool? euReporting,
    String? euVatNumber,
    VatPeriod? vatPeriod,
    int? costRatio,
    bool? mainOccupation,
    Currency? mainCurrency,
    RateSource? rateSource,
    bool? rateSourceReported,
  }) => Profile(
    id: id,
    name: name ?? this.name,
    address: address ?? this.address,
    taxId: taxId ?? this.taxId,
    taxNumber: taxNumber ?? this.taxNumber,
    userType: userType ?? this.userType,
    taxRegime: taxRegime ?? this.taxRegime,
    vatStatus: vatStatus ?? this.vatStatus,
    euReporting: euReporting ?? this.euReporting,
    euVatNumber: euVatNumber ?? this.euVatNumber,
    vatPeriod: vatPeriod ?? this.vatPeriod,
    costRatio: costRatio ?? this.costRatio,
    mainOccupation: mainOccupation ?? this.mainOccupation,
    mainCurrency: mainCurrency ?? this.mainCurrency,
    rateSource: rateSource ?? this.rateSource,
    rateSourceReported: rateSourceReported ?? this.rateSourceReported,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    taxId,
    taxNumber,
    userType,
    taxRegime,
    vatStatus,
    euReporting,
    euVatNumber,
    vatPeriod,
    costRatio,
    mainOccupation,
    mainCurrency,
    rateSource,
    rateSourceReported,
  ];
}
