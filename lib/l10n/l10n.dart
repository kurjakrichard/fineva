import 'package:flutter/widgets.dart';

import '../data/built_in_categories.dart';
import '../data/models/models.dart';
import '../providers/business/flat_rate_tax.dart' show TaxKind;
import '../utils/utils.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// Short access to the translated texts: `context.l10n.save`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Language code for number and date formatting: 'en', 'hu'.
  String get localeName => Localizations.localeOf(this).languageCode;
}

/// Names of the app's own values in the app's language.
extension L10nNames on AppLocalizations {
  /// A built-in category's name in the app's language (from
  /// assets/categories.json, see [BuiltInCategories]), otherwise the
  /// user's name.
  String categoryName(EntryCategory category) {
    final key = category.systemKey;
    if (key == null) return category.name;
    return BuiltInCategories.current.name(key, localeName) ?? category.name;
  }

  /// "EUR – euró".
  String currencyLabel(Currency currency) =>
      '${currency.code} – ${currencyName(currency.code)}';

  String rateSourceName(RateSource source) => switch (source) {
    RateSource.mnb => rateSourceMnb,
    RateSource.ecb => rateSourceEcb,
    RateSource.manual => rateSourceManual,
  };

  String accountTypeName(AccountType type) => switch (type) {
    AccountType.cash => accountTypeCash,
    AccountType.bank => accountTypeBank,
    AccountType.card => accountTypeCard,
    AccountType.savings => accountTypeSavings,
  };

  String userTypeName(UserType type) => switch (type) {
    UserType.personal => userTypePersonal,
    UserType.soleProprietor => userTypeSoleProprietor,
  };

  String taxRegimeName(TaxRegime regime) => switch (regime) {
    TaxRegime.itemized => taxRegimeItemized,
    TaxRegime.flatRate => taxRegimeFlatRate,
    TaxRegime.kata => taxRegimeKata,
  };

  String vatStatusName(VatStatus status) => switch (status) {
    VatStatus.registered => vatRegistered,
    VatStatus.exempt => vatExempt,
  };

  /// The user's name, or "Unnamed user" for a user from before schema 3.
  String userName(Profile profile) =>
      profile.name.isEmpty ? unnamedUser : profile.name;

  /// One line: "Sole proprietor finances · Flat-rate tax · VAT exempt".
  String profileSummary(Profile profile) => [
    userTypeName(profile.userType),
    if (profile.isSoleProprietor) ...[
      taxRegimeName(profile.taxRegime),
      vatStatusName(profile.vatStatus),
      if (profile.euReporting) euReporting,
    ],
  ].join(' · ');

  String costRatioText(int ratio) => switch (ratio) {
    80 => costRatioListed,
    90 => costRatioRetail,
    _ => costRatioGeneral,
  };

  String vatPeriodName(VatPeriod period) => switch (period) {
    VatPeriod.monthly => vatPeriodMonthly,
    VatPeriod.quarterly => vatPeriodQuarterly,
    VatPeriod.yearly => vatPeriodYearly,
  };

  String invoiceDirectionName(InvoiceDirection direction) =>
      switch (direction) {
        InvoiceDirection.outgoing => invoiceOutgoing,
        InvoiceDirection.incoming => invoiceIncoming,
      };

  String partnerLocationName(PartnerLocation location) => switch (location) {
    PartnerLocation.domestic => partnerDomestic,
    PartnerLocation.eu => partnerEu,
    PartnerLocation.thirdCountry => partnerThirdCountry,
  };

  String paymentMethodName(PaymentMethod method) => switch (method) {
    PaymentMethod.transfer => paymentTransfer,
    PaymentMethod.cash => paymentCash,
    PaymentMethod.card => paymentCard,
  };

  String vatCodeName(VatCode code) => switch (code) {
    VatCode.vat27 => vatCode27,
    VatCode.vat18 => vatCode18,
    VatCode.vat5 => vatCode5,
    VatCode.vat0 => vatCode0,
    VatCode.aam => vatCodeAam,
    VatCode.tam => vatCodeTam,
    VatCode.atk => vatCodeAtk,
    VatCode.fad => vatCodeFad,
    VatCode.kbaet => vatCodeKbaet,
    VatCode.eufad37 => vatCodeEufad37,
    VatCode.eufade => vatCodeEufade,
    VatCode.eue => vatCodeEue,
    VatCode.euGoods => vatCodeEuGoods,
    VatCode.euServices => vatCodeEuServices,
    VatCode.eam => vatCodeEam,
    VatCode.ho => vatCodeHo,
    VatCode.nam => vatCodeNam,
    VatCode.importServices => vatCodeImportServices,
    VatCode.importGoods => vatCodeImportGoods,
  };

  String taxTreatmentName(TaxTreatment treatment) => switch (treatment) {
    TaxTreatment.none => taxTreatmentNone,
    TaxTreatment.revenue => taxTreatmentRevenue,
    TaxTreatment.nonTaxableIncome => taxTreatmentNonTaxableIncome,
    TaxTreatment.withdrawal => taxTreatmentWithdrawal,
    TaxTreatment.szocho => taxTreatmentSzocho,
    TaxTreatment.otherCost => taxTreatmentOtherCost,
    TaxTreatment.materialCost => taxTreatmentMaterialCost,
    TaxTreatment.bankCost => taxTreatmentBankCost,
    TaxTreatment.accountingCost => taxTreatmentAccountingCost,
    TaxTreatment.itCost => taxTreatmentItCost,
    TaxTreatment.nonDeductible => taxTreatmentNonDeductible,
    TaxTreatment.vat => taxTreatmentVat,
  };

  String taxKindName(TaxKind kind) => switch (kind) {
    TaxKind.szja => taxKindSzja,
    TaxKind.szocho => taxKindSzocho,
    TaxKind.tb => taxKindTb,
    TaxKind.localTax => taxKindLocalTax,
    TaxKind.chamberFee => taxKindChamberFee,
  };

  String entryTypeName(EntryType type) => switch (type) {
    EntryType.income => income,
    EntryType.expense => expense,
  };
}
