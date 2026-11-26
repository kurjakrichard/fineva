import 'money.dart';

/// Every page of the app. The menu's pages are in MainDestination.
enum Routes {
  splash(name: 'splash', path: '/splash'),
  onboarding(name: 'onboarding', path: '/onboarding'),
  dashboard(name: 'dashboard', path: '/dashboard'),
  entries(name: 'entries', path: '/entries'),
  entry(name: 'entry', path: '/entry'),
  transfer(name: 'transfer', path: '/transfer'),
  business(name: 'business', path: '/business'),
  // An invoices only user's (Profile.invoicesOnly) menu.
  invoices(name: 'invoices', path: '/invoices'),
  revenueRecord(name: 'revenueRecord', path: '/revenue-record'),
  flatRate(name: 'flatRate', path: '/flat-rate'),
  invoice(name: 'invoice', path: '/invoice'),
  statistics(name: 'statistics', path: '/statistics'),
  accounts(name: 'accounts', path: '/accounts'),
  account(name: 'account', path: '/accounts/:id'),
  categories(name: 'categories', path: '/categories'),
  settings(name: 'settings', path: '/settings'),
  profile(name: 'profile', path: '/profile'),
  rates(name: 'rates', path: '/rates');

  const Routes({required this.name, required this.path});

  final String name;
  final String path;
}

/// Kind of an account. Stored by [name] in the database.
enum AccountType { cash, bank, card, savings }

/// Income or expense: the type of a category and of an entry. Stored by
/// [name] in the database.
enum EntryType { income, expense }

/// What Fineva is used for (the onboarding asks). Stored by [name].
enum UserType { personal, soleProprietor }

/// How a sole proprietor pays income tax. Stored by [name].
enum TaxRegime {
  /// Entrepreneurial personal income tax with itemized costs ("sima").
  itemized,

  /// Flat-rate tax (átalányadó): a fixed cost ratio of the revenue.
  flatRate,

  /// KATA: fixed monthly tax of small taxpayers.
  kata,
}

/// Whether a sole proprietor charges VAT. Stored by [name].
enum VatStatus {
  /// Subjective VAT exemption (alanyi adómentes).
  exempt,
  registered,
}

/// How often a VAT registered sole proprietor files the VAT return
/// (áfabevallás). Stored by [name].
enum VatPeriod { monthly, quarterly, yearly }

/// Revenue (kimenő számla: issued by the sole proprietor) or cost (bejövő
/// számla). Stored by [name].
enum InvoiceDirection { outgoing, incoming }

/// Where the partner of an invoice is; it decides the possible [VatCode]s.
/// Stored by [name].
enum PartnerLocation {
  /// Belföldi.
  domestic,

  /// Közösségen belüli: another EU member state.
  eu,

  /// Harmadik ország: outside the EU.
  thirdCountry,
}

/// Stored by [name].
enum PaymentMethod { transfer, cash, card }

/// The Hungarian VAT treatment of an invoice: a VAT rate, or why there is no
/// VAT on it. Codes with a [nav] are the case codes of NAV Online Számla.
/// Stored by [name].
enum VatCode {
  // Domestic, with VAT on the invoice.
  vat27(PartnerLocation.domestic, rate: 27),
  vat18(PartnerLocation.domestic, rate: 18),
  vat5(PartnerLocation.domestic, rate: 5),
  vat0(PartnerLocation.domestic, rate: 0),

  // Domestic, without VAT.
  /// Alanyi adómentes: the seller is exempt (under the yearly limit).
  aam(PartnerLocation.domestic, nav: 'AAM'),

  /// Tárgyi adómentes: an exempt activity (Áfa tv. 85-86. §).
  tam(PartnerLocation.domestic, nav: 'TAM'),

  /// Az áfa hatályán kívül.
  atk(PartnerLocation.domestic, nav: 'ATK'),

  /// Belföldi fordított adózás (Áfa tv. 142. §): the buyer pays the VAT.
  fad(PartnerLocation.domestic, nav: 'FAD', reverseCharge: true),

  // Intra-community.
  /// Közösségen belüli adómentes termékértékesítés.
  kbaet(PartnerLocation.eu, direction: InvoiceDirection.outgoing, nav: 'KBAET'),

  /// A service to a business in another member state (Áfa tv. 37. § (1)),
  /// the buyer pays the VAT there.
  eufad37(
    PartnerLocation.eu,
    direction: InvoiceDirection.outgoing,
    nav: 'EUFAD37',
  ),

  /// Another reverse charge supply in another member state.
  eufade(
    PartnerLocation.eu,
    direction: InvoiceDirection.outgoing,
    nav: 'EUFADE',
  ),

  /// A supply in another member state, not reverse charged.
  eue(PartnerLocation.eu, nav: 'EUE'),

  /// Közösségen belüli termékbeszerzés: the VAT is self-assessed.
  euGoods(
    PartnerLocation.eu,
    direction: InvoiceDirection.incoming,
    reverseCharge: true,
  ),

  /// A service from another member state: the VAT is self-assessed.
  euServices(
    PartnerLocation.eu,
    direction: InvoiceDirection.incoming,
    reverseCharge: true,
  ),

  // Third country.
  /// Termékexport: exempt.
  eam(
    PartnerLocation.thirdCountry,
    direction: InvoiceDirection.outgoing,
    nav: 'EAM',
  ),

  /// Harmadik országban teljesített ügylet.
  ho(PartnerLocation.thirdCountry, nav: 'HO'),

  /// Other exemption of international transactions.
  nam(
    PartnerLocation.thirdCountry,
    direction: InvoiceDirection.outgoing,
    nav: 'NAM',
  ),

  /// A service from a third country: the VAT is self-assessed.
  importServices(
    PartnerLocation.thirdCountry,
    direction: InvoiceDirection.incoming,
    reverseCharge: true,
  ),

  /// Termékimport: the VAT is self-assessed (or paid at customs).
  importGoods(
    PartnerLocation.thirdCountry,
    direction: InvoiceDirection.incoming,
    reverseCharge: true,
  );

  const VatCode(
    this.location, {
    this.direction,
    this.rate,
    this.nav,
    this.reverseCharge = false,
  });

  final PartnerLocation location;

  /// Null: for both directions.
  final InvoiceDirection? direction;

  /// VAT rate on the invoice in percent; null if the invoice has no VAT.
  final int? rate;

  /// The NAV Online Számla case code.
  final String? nav;

  /// The buyer pays the VAT. On an incoming invoice it is self-assessed at
  /// [reverseChargeRate]: payable, and deductible if the buyer is VAT
  /// registered.
  final bool reverseCharge;

  static const int reverseChargeRate = 27;

  /// The codes an invoice of [direction] with a partner in [location] can
  /// have.
  static List<VatCode> available(
    InvoiceDirection direction,
    PartnerLocation location,
  ) => [
    for (final code in values)
      if (code.location == location &&
          (code.direction == null || code.direction == direction))
        code,
  ];
}

/// How the entries of a category count in the itemized taxation of a sole
/// proprietor (vállalkozói SZJA), as the columns of the cash-flow ledger
/// workbook. Stored by [name].
enum TaxTreatment {
  /// Not a business entry.
  none(null),

  /// Adóalapba számító bevétel.
  revenue(EntryType.income),

  /// Adóalapba nem számító bevétel: own money paid in, transfers, refunds.
  nonTaxableIncome(EntryType.income),

  /// Vállalkozói kivét, gross.
  withdrawal(EntryType.expense, isCost: true),

  /// SZOCHO on the withdrawal.
  szocho(EntryType.expense, isCost: true),
  otherCost(EntryType.expense, isCost: true),

  /// Anyagköltség: also reduces the local business tax base.
  materialCost(EntryType.expense, isCost: true),
  bankCost(EntryType.expense, isCost: true),
  accountingCost(EntryType.expense, isCost: true),
  itCost(EntryType.expense, isCost: true),

  /// Adóalapba nem számító kiadás: taxes and contributions deducted from
  /// the withdrawal, transfers, private spending.
  nonDeductible(EntryType.expense),

  /// Deductible VAT paid: not a cost.
  vat(EntryType.expense);

  const TaxTreatment(this.type, {this.isCost = false});

  /// The type of the categories it fits; null for every type.
  final EntryType? type;

  /// Reduces the tax base.
  final bool isCost;

  /// The treatments a category of [type] can have.
  static List<TaxTreatment> of(EntryType type) => [
    for (final t in values)
      if (t.type == null || t.type == type) t,
  ];
}

/// Whose categories: a personal user's or a sole proprietor's. Only the
/// current user's kind is shown; a new user gets only their own kind.
/// Stored by [name].
enum CategoryScope { personal, business }

/// Where exchange rates come from: the Magyar Nemzeti Bank (HUF per unit),
/// the European Central Bank (units per EUR), or typed in. Stored by
/// [name].
enum RateSource {
  mnb,
  ecb,
  manual;

  /// The currency the downloaded rates are given in; null for manual ones
  /// (each has its own base).
  Currency? get pivot => switch (this) {
    mnb => Currency.huf,
    ecb => Currency.eur,
    manual => null,
  };

  /// The usual source for a user whose main currency is [main]: the MNB for
  /// the forint, the ECB otherwise.
  static RateSource defaultFor(Currency main) =>
      main == Currency.huf ? mnb : ecb;
}
