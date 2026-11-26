// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fineva';

  @override
  String get tagline => 'Your finances in order';

  @override
  String get accounts => 'Accounts';

  @override
  String get categories => 'Categories';

  @override
  String get settings => 'Settings';

  @override
  String get entries => 'Entries';

  @override
  String get balance => 'Balance';

  @override
  String get income => 'Income';

  @override
  String get expense => 'Expense';

  @override
  String get addEntry => 'New entry';

  @override
  String get editEntry => 'Edit entry';

  @override
  String get amount => 'Amount';

  @override
  String get amountInvalid => 'Enter an amount greater than zero';

  @override
  String get account => 'Account';

  @override
  String get category => 'Category';

  @override
  String get noCategory => 'No category';

  @override
  String get date => 'Date';

  @override
  String get note => 'Note';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get saveError => 'Saving failed';

  @override
  String get deleteError => 'Deleting failed';

  @override
  String get deleteEntryConfirm => 'Delete this entry?';

  @override
  String get noEntries => 'No entries yet. Add one with the + button.';

  @override
  String get noAccounts =>
      'Add an account first to record income and expenses.';

  @override
  String get addAccount => 'New account';

  @override
  String get editAccount => 'Edit account';

  @override
  String get name => 'Name';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get accountType => 'Type';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeBank => 'Bank account';

  @override
  String get accountTypeCard => 'Card';

  @override
  String get accountTypeSavings => 'Savings';

  @override
  String get currency => 'Currency';

  @override
  String currencyName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'HUF': 'Hungarian forint',
      'EUR': 'Euro',
      'USD': 'US dollar',
      'GBP': 'Pound sterling',
      'CHF': 'Swiss franc',
      'CZK': 'Czech koruna',
      'PLN': 'Polish złoty',
      'RON': 'Romanian leu',
      'SEK': 'Swedish krona',
      'NOK': 'Norwegian krone',
      'DKK': 'Danish krone',
      'ISK': 'Icelandic króna',
      'TRY': 'Turkish lira',
      'JPY': 'Japanese yen',
      'CNY': 'Chinese yuan',
      'HKD': 'Hong Kong dollar',
      'KRW': 'South Korean won',
      'SGD': 'Singapore dollar',
      'INR': 'Indian rupee',
      'IDR': 'Indonesian rupiah',
      'MYR': 'Malaysian ringgit',
      'PHP': 'Philippine peso',
      'THB': 'Thai baht',
      'ILS': 'Israeli new shekel',
      'AUD': 'Australian dollar',
      'NZD': 'New Zealand dollar',
      'CAD': 'Canadian dollar',
      'MXN': 'Mexican peso',
      'BRL': 'Brazilian real',
      'ZAR': 'South African rand',
      'other': '$code',
    });
    return '$_temp0';
  }

  @override
  String get initialBalance => 'Opening balance';

  @override
  String get initialBalanceInvalid => 'Enter a number';

  @override
  String deleteAccountConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete the account $name and its $count entries?',
      one: 'Delete the account $name and its entry?',
      zero: 'Delete the account $name?',
    );
    return '$_temp0';
  }

  @override
  String get addCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get deleteCategoryConfirm =>
      'Delete this category? Its entries stay, without a category.';

  @override
  String get color => 'Color';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'Device setting';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String errorMessage(String message) {
    return 'Something went wrong: $message';
  }

  @override
  String loadError(String message) {
    return 'The data couldn\'t be loaded: $message';
  }

  @override
  String get welcomeTitle => 'Welcome to Fineva!';

  @override
  String get welcomeText => 'Let\'s set it up in a few steps.';

  @override
  String get usageTitle => 'What will you use Fineva for?';

  @override
  String get userTypePersonal => 'Personal finances';

  @override
  String get userTypePersonalText => 'Your own income, expenses and accounts';

  @override
  String get userTypeSoleProprietor => 'Sole proprietor finances';

  @override
  String get userTypeSoleProprietorText =>
      'Your business\'s income and expenses, set up for your taxation';

  @override
  String get businessTitle => 'Your business';

  @override
  String get taxRegime => 'Taxation';

  @override
  String get taxRegimeItemized => 'Entrepreneurial personal income tax';

  @override
  String get taxRegimeItemizedText => 'Taxed on your actual, documented costs';

  @override
  String get taxRegimeFlatRate => 'Flat-rate tax';

  @override
  String get taxRegimeFlatRateText =>
      'Your revenue minus a fixed cost ratio is taxed';

  @override
  String get taxRegimeKata => 'KATA';

  @override
  String get taxRegimeKataText =>
      'Fixed monthly tax, for sales to private persons';

  @override
  String get vat => 'VAT';

  @override
  String get vatRegistered => 'VAT registered';

  @override
  String get vatRegisteredText => 'You charge VAT and file VAT returns';

  @override
  String get vatExempt => 'VAT exempt';

  @override
  String get vatExemptText =>
      'Your yearly revenue is under the VAT exemption limit';

  @override
  String get euReporting => 'EU reporting';

  @override
  String get euReportingText =>
      'EU VAT number, recapitulative statement of intra-EU transactions';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get started';

  @override
  String get profile => 'Profile';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get latestEntries => 'Latest entries';

  @override
  String get allEntries => 'All entries';

  @override
  String get detailsTitle => 'Your details';

  @override
  String get address => 'Address';

  @override
  String get addressHint => '1234 Budapest, Main street 1.';

  @override
  String get taxId => 'Tax identification number';

  @override
  String get taxIdHelper => '10 digits starting with 8, on your tax card';

  @override
  String get taxIdInvalid => 'Not a valid tax identification number';

  @override
  String get taxNumber => 'Tax number';

  @override
  String get taxNumberInvalid => 'Not a valid tax number (12345678-1-12)';

  @override
  String get statistics => 'Statistics';

  @override
  String get newUser => 'New user';

  @override
  String get newUserText =>
      'Set up Fineva for someone else, with their own accounts and entries';

  @override
  String get deleteUser => 'Delete user';

  @override
  String deleteUserConfirm(String name) {
    return 'Delete $name with all their accounts, entries and categories?';
  }

  @override
  String get switchUser => 'Switch user';

  @override
  String get unnamedUser => 'Unnamed user';

  @override
  String get whoUses => 'Who uses Fineva now?';

  @override
  String get welcomeBackTitle => 'Welcome back!';

  @override
  String get welcomeBackText =>
      'Choose the user, then check the details. Skip goes straight on.';

  @override
  String get skip => 'Skip';

  @override
  String get onboardingAtStart => 'Onboarding at every start';

  @override
  String get onboardingAtStartText =>
      'Choose the user and check the details when Fineva starts';

  @override
  String get data => 'Data';

  @override
  String get backup => 'Back up data';

  @override
  String get backupText => 'Save every user\'s data into a file';

  @override
  String get backupSaved => 'Backup saved';

  @override
  String get backupError => 'The backup couldn\'t be saved';

  @override
  String get restore => 'Restore data';

  @override
  String get restoreText => 'Replace all data with a backup';

  @override
  String get restoreConfirm =>
      'Restoring replaces all current data, of every user, with the backup. Go on?';

  @override
  String get restored => 'Data restored';

  @override
  String get restoreInvalid => 'This file is not a Fineva backup';

  @override
  String get restoreNewer =>
      'This backup was made by a newer Fineva. Update the app first.';

  @override
  String get restoreError => 'The data couldn\'t be restored';

  @override
  String get summary => 'Summary';

  @override
  String get cashFlow => 'Cash flow';

  @override
  String get netResult => 'Net';

  @override
  String get savingsRate => 'Savings rate';

  @override
  String get closingBalance => 'Closing balance';

  @override
  String get changeInPeriod => 'Change in the period:';

  @override
  String categoryTotal(String amount) {
    return 'Total: $amount';
  }

  @override
  String get allTime => 'All time';

  @override
  String get period => 'Period';

  @override
  String get choosePeriod => 'Choose period';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodQuarter => 'Quarter';

  @override
  String get periodYear => 'Year';

  @override
  String get periodCustom => 'Custom';

  @override
  String quarterOfYear(int quarter, int year) {
    return 'Q$quarter $year';
  }

  @override
  String quarterOfYearShort(int quarter, int year) {
    return 'Q$quarter $year';
  }

  @override
  String get noEntriesInPeriod => 'No entries in this period.';

  @override
  String allEntriesCount(int count) {
    return 'All ($count)';
  }

  @override
  String get previousPeriod => 'Previous';

  @override
  String get nextPeriod => 'Next';

  @override
  String get euVatNumber => 'EU VAT number';

  @override
  String get euVatNumberHelper =>
      'HU and the first 8 digits of your tax number';

  @override
  String get euVatNumberRequired => 'EU reporting needs your EU VAT number';

  @override
  String get euVatNumberInvalid => 'Not a valid EU VAT number (HU12345678)';

  @override
  String get euVatNumberMismatch =>
      'It doesn\'t match your tax number: HU and its first 8 digits';

  @override
  String get taxNumberRequired =>
      'A sole proprietor needs a Hungarian tax number';

  @override
  String get taxNumberHelper => 'Your tax number: 12345678-1-12';

  @override
  String get costRatio => 'Cost ratio';

  @override
  String get costRatioGeneral => 'General';

  @override
  String get costRatioListed => 'Activities listed in the law';

  @override
  String get costRatioRetail => 'Retail trade';

  @override
  String get mainOccupation => 'Main occupation';

  @override
  String get mainOccupationText =>
      'No employment of at least 36 hours a week beside it: the minimum contributions apply';

  @override
  String get vatPeriod => 'VAT return';

  @override
  String get vatPeriodMonthly => 'Monthly';

  @override
  String get vatPeriodQuarterly => 'Quarterly';

  @override
  String get vatPeriodYearly => 'Yearly';

  @override
  String get business => 'Business';

  @override
  String get businessOnlyText => 'Only for sole proprietors.';

  @override
  String get businessIncompleteText =>
      'Your tax number is missing. Complete your profile to keep the business records.';

  @override
  String get invoices => 'Invoices';

  @override
  String get previousYear => 'Previous year';

  @override
  String get nextYear => 'Next year';

  @override
  String get addInvoice => 'New invoice';

  @override
  String get editInvoice => 'Edit invoice';

  @override
  String get deleteInvoiceConfirm => 'Delete this invoice?';

  @override
  String get amountRequired => 'Enter an amount';

  @override
  String get invoiceOutgoing => 'Outgoing (revenue)';

  @override
  String get invoiceIncoming => 'Incoming (cost)';

  @override
  String get invoiceNumber => 'Invoice number';

  @override
  String get invoiceNumberRequired => 'Enter the invoice number';

  @override
  String get paymentMethod => 'Payment';

  @override
  String get paymentTransfer => 'Transfer';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentCard => 'Card';

  @override
  String get invoiceDescription => 'Description';

  @override
  String get partner => 'Partner';

  @override
  String get partnerDomestic => 'Domestic';

  @override
  String get partnerEu => 'EU';

  @override
  String get partnerThirdCountry => 'Third country';

  @override
  String get partnerName => 'Partner name';

  @override
  String get foreignTaxNumber => 'Tax number';

  @override
  String get partnerEuVatNumberInvalid =>
      'Country code and number, e.g. DE123456789';

  @override
  String get dates => 'Dates';

  @override
  String get issueDate => 'Issued';

  @override
  String get fulfillmentDate => 'Fulfilled';

  @override
  String get dueDate => 'Due';

  @override
  String get exchangeRate => 'Exchange rate';

  @override
  String exchangeRateHelper(String code) {
    return 'HUF for 1 $code';
  }

  @override
  String get exchangeRateInvalid => 'Enter the exchange rate';

  @override
  String get vatCode => 'VAT';

  @override
  String get netAmount => 'Net';

  @override
  String get vatAmount => 'VAT';

  @override
  String get grossAmount => 'Gross';

  @override
  String reverseChargeText(int rate) {
    return 'Reverse charge: you pay the $rate% VAT, and deduct it if you are VAT registered.';
  }

  @override
  String get paid => 'Paid';

  @override
  String get paidRevenueText => 'Flat-rate revenue counts when it is paid';

  @override
  String get paidCostText => 'When you paid it';

  @override
  String get paidDate => 'Paid on';

  @override
  String get paidAmount => 'Paid amount';

  @override
  String get vatCode27 => '27% VAT';

  @override
  String get vatCode18 => '18% VAT';

  @override
  String get vatCode5 => '5% VAT';

  @override
  String get vatCode0 => '0% VAT';

  @override
  String get vatCodeAam => 'AAM – subjective VAT exemption';

  @override
  String get vatCodeTam => 'TAM – exempt activity';

  @override
  String get vatCodeAtk => 'ATK – outside the scope of VAT';

  @override
  String get vatCodeFad => 'FAD – domestic reverse charge';

  @override
  String get vatCodeKbaet => 'KBAET – exempt intra-EU supply of goods';

  @override
  String get vatCodeEufad37 =>
      'EUFAD37 – service to an EU business (reverse charge)';

  @override
  String get vatCodeEufade => 'EUFADE – other reverse charge supply in the EU';

  @override
  String get vatCodeEue => 'EUE – supply in another member state';

  @override
  String get vatCodeEuGoods => 'Intra-EU acquisition of goods (reverse charge)';

  @override
  String get vatCodeEuServices => 'Service from the EU (reverse charge)';

  @override
  String get vatCodeEam => 'EAM – export, exempt';

  @override
  String get vatCodeHo => 'HO – supply in a third country';

  @override
  String get vatCodeNam => 'NAM – other international exemption';

  @override
  String get vatCodeImportServices =>
      'Service from a third country (reverse charge)';

  @override
  String get vatCodeImportGoods => 'Import of goods (reverse charge)';

  @override
  String incomeRecord(int year) {
    return 'Income record $year';
  }

  @override
  String costRecord(int year) {
    return 'Cost record $year';
  }

  @override
  String get grossTotal => 'Gross total';

  @override
  String get openTotal => 'Open';

  @override
  String get flatRateRevenue => 'Flat-rate revenue (paid, net)';

  @override
  String get kataRevenue => 'KATA revenue';

  @override
  String kataTaxText(String amount) {
    return 'KATA tax: $amount a month';
  }

  @override
  String get noInvoices => 'No invoices in this year.';

  @override
  String openAmount(String amount) {
    return '$amount open';
  }

  @override
  String flatRateYear(int year) {
    return 'Flat-rate taxation $year';
  }

  @override
  String get flatRateOverLimit =>
      'Over the revenue limit: flat-rate taxation ends.';

  @override
  String get taxFreeRevenue => 'Tax-free revenue';

  @override
  String taxFreeRevenueHint(String income, int ratio) {
    return '$income tax-free income at a $ratio% cost ratio';
  }

  @override
  String get yearlyTaxes => 'Taxes of the year';

  @override
  String taxYearUnknown(int year, int known) {
    return 'The amounts of $year are not known yet: those of $known are used.';
  }

  @override
  String quarterName(int quarter) {
    return 'Q$quarter';
  }

  @override
  String deadline(String date) {
    return 'Due $date';
  }

  @override
  String get revenue => 'Revenue';

  @override
  String get flatRateIncome => 'Income';

  @override
  String get taxableIncome => 'Taxable income';

  @override
  String taxFreeIncomeHint(String amount) {
    return 'Tax free: $amount';
  }

  @override
  String get szja => 'Personal income tax (15%)';

  @override
  String get tbContribution => 'Social security contribution (18.5%)';

  @override
  String get szocho => 'Social contribution tax (13%)';

  @override
  String get localTax => 'Local business tax';

  @override
  String get chamberFee => 'Chamber fee';

  @override
  String get total => 'Total';

  @override
  String baseHint(String amount) {
    return 'Base: $amount';
  }

  @override
  String get toTransfer => 'To transfer';

  @override
  String taxCode(String code) {
    return 'Tax code $code';
  }

  @override
  String get municipalityAccount => 'to the municipality\'s account';

  @override
  String get taxKindSzja => 'NAV personal income tax';

  @override
  String get taxKindSzocho => 'NAV social contribution tax';

  @override
  String get taxKindTb => 'NAV social security contribution';

  @override
  String get taxKindLocalTax => 'Local business tax';

  @override
  String get taxKindChamberFee => 'Hungarian Chamber of Commerce and Industry';

  @override
  String get copyAccount => 'Copy the account number';

  @override
  String copied(String text) {
    return 'Copied: $text';
  }

  @override
  String get vatPayable => 'Payable VAT';

  @override
  String get vatDeductible => 'Deductible VAT';

  @override
  String get reverseCharge => 'Reverse charge';

  @override
  String get vatTotalRounded => 'Total (in thousands)';

  @override
  String get vatExemptReverseChargeText =>
      'As VAT exempt you pay the reverse charge VAT without deduction.';

  @override
  String get vatToPay => 'Balance: to pay';

  @override
  String get vatToReclaim => 'Balance: to reclaim or carry forward';

  @override
  String get salesWithoutVat => 'Sales without VAT';

  @override
  String vatDateRuleText(int days) {
    return 'By VAT date: an outgoing invoice counts on its payment date if paid within $days days of the fulfillment, otherwise on the fulfillment + $days days; an incoming one on its fulfillment date.';
  }

  @override
  String vatDateLine(String date, int days) {
    return 'VAT date: $date (the payment date within $days days of the fulfillment, otherwise the fulfillment + $days days)';
  }

  @override
  String get taxTreatment => 'Business tax';

  @override
  String get taxTreatmentNone => 'Not a business item';

  @override
  String get taxTreatmentRevenue => 'Taxable revenue';

  @override
  String get taxTreatmentNonTaxableIncome => 'Non-taxable income';

  @override
  String get taxTreatmentWithdrawal => 'Cost: withdrawal (gross)';

  @override
  String get taxTreatmentSzocho => 'Cost: SZOCHO';

  @override
  String get taxTreatmentOtherCost => 'Cost: other';

  @override
  String get taxTreatmentMaterialCost => 'Cost: material';

  @override
  String get taxTreatmentBankCost => 'Cost: bank charges';

  @override
  String get taxTreatmentAccountingCost => 'Cost: accounting';

  @override
  String get taxTreatmentItCost => 'Cost: IT';

  @override
  String get taxTreatmentNonDeductible => 'Non-deductible spending';

  @override
  String get taxTreatmentVat => 'VAT (not a cost)';

  @override
  String entryExchangeRateHelper(String main, String code) {
    return '$main / 1 $code on the day';
  }

  @override
  String get itemizedTab => 'Itemized tax';

  @override
  String get assets => 'Assets';

  @override
  String get itemizedSetupTitle => 'Business categories';

  @override
  String get itemizedSetupText =>
      'The itemized tax is calculated from the entries of the categories with a business tax treatment. Add the categories of the cash-flow ledger (taxable revenue, withdrawal, costs, …), or set the treatment of your own categories.';

  @override
  String get addBusinessCategories => 'Add the business categories';

  @override
  String missingExchangeRates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count entries of foreign currency accounts have no exchange rate: they are left out.',
      one: '1 entry of a foreign currency account has no exchange rate: it is left out.',
    );
    return '$_temp0';
  }

  @override
  String itemizedYear(int year) {
    return 'Itemized tax $year';
  }

  @override
  String get taxableRevenue => 'Taxable revenue';

  @override
  String get costs => 'Costs';

  @override
  String depreciationHint(String amount) {
    return 'Depreciation included: $amount';
  }

  @override
  String get taxBase => 'Tax base';

  @override
  String get vszja => 'Entrepreneurial income tax (9%)';

  @override
  String get dividendBase => 'Entrepreneurial dividend base';

  @override
  String get dividendSzja => 'SZJA on the dividend base (15%)';

  @override
  String get szochoOnDividend => 'SZOCHO on the dividend base, after the year';

  @override
  String szochoCapHint(String cap, String paid) {
    return 'Up to the cap of $cap, $paid paid on the withdrawal';
  }

  @override
  String get byTreatment => 'By business category';

  @override
  String get depreciation => 'Depreciation';

  @override
  String get lossCarried => 'Loss of the quarter before';

  @override
  String depreciationOfYear(String amount) {
    return 'Depreciation this year: $amount';
  }

  @override
  String get addAsset => 'New asset';

  @override
  String get editAsset => 'Edit asset';

  @override
  String get noAssets => 'No assets yet.';

  @override
  String assetRemaining(String amount) {
    return '$amount left';
  }

  @override
  String get deleteAssetConfirm => 'Delete this asset?';

  @override
  String get purchaseDate => 'Put into use';

  @override
  String get supplier => 'Supplier';

  @override
  String get assetCost => 'Cost';

  @override
  String get depreciationRate => 'Yearly depreciation rate';

  @override
  String get depreciationRateHelper =>
      'E.g. 33 for computers, 14.5 for other machines; 100 writes off a small asset at once';

  @override
  String get depreciationRateInvalid => 'A rate from 0 to 100';

  @override
  String get vatPeriodBalance => 'Balance of the period';

  @override
  String get vatCarriedIn => 'Carried forward from before';

  @override
  String get searchEntries => 'Note, category, account, amount';

  @override
  String get clearSearch => 'Clear the search';

  @override
  String get filterType => 'Type';

  @override
  String get filterAll => 'All';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get noMatchingEntries => 'No entries match the search and filters.';

  @override
  String entryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get icon => 'Icon';

  @override
  String balanceAt(String date) {
    return 'Balance on $date';
  }

  @override
  String get search => 'Search';

  @override
  String get filters => 'Filters';

  @override
  String get removeFilter => 'Remove the filter';

  @override
  String get done => 'Done';

  @override
  String get userTypeFixed =>
      'A user\'s kind can\'t change after it is created.';

  @override
  String get bookingText =>
      'The payment is booked as an entry on the account, so it is in the entries and the balances.';

  @override
  String get bookedOn => 'Booked on';

  @override
  String get notBooked => 'Not booked';

  @override
  String get paidExchangeRate => 'Exchange rate of the payment';

  @override
  String get paidExchangeRateHelper => 'Empty: the invoice\'s rate';

  @override
  String get openInvoices => 'Open invoices';

  @override
  String get receivables => 'Owed to you';

  @override
  String get payables => 'You owe';

  @override
  String get exchangeRates => 'Exchange rates';

  @override
  String get exchangeRatesText => 'Main currency, source, rates typed in';

  @override
  String get updateRates => 'Download the rates now';

  @override
  String get mainCurrency => 'Main currency';

  @override
  String get mainCurrencyText =>
      'The dashboard and the statistics show everything in it. It can\'t be changed later.';

  @override
  String get mainCurrencySoleProprietor =>
      'Always the forint for a sole proprietor: the taxes are in forints.';

  @override
  String get rateSource => 'Source of the rates';

  @override
  String get rateSourceMnb => 'MNB';

  @override
  String get rateSourceEcb => 'ECB';

  @override
  String get rateSourceManual => 'Manual';

  @override
  String get rateSourceText =>
      'MNB: the Magyar Nemzeti Bank\'s official rates. ECB: the European Central Bank\'s reference rates. Manual: only the rates typed in. A rate typed in always goes before a downloaded one of the same day.';

  @override
  String get ratesAtStart => 'Download at every start';

  @override
  String get ratesAtStartText => 'The missing rates, if there is a network';

  @override
  String get ratesDownloading => 'Downloading the rates…';

  @override
  String ratesDownloadFailed(String error) {
    return 'The download failed: $error';
  }

  @override
  String ratesDownloaded(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rates',
      one: '1 rate',
      zero: 'no new rate',
    );
    return 'Downloaded at $time: $_temp0';
  }

  @override
  String get currentRates => 'Today\'s rates';

  @override
  String noForeignCurrency(String code) {
    return 'Every account and invoice is in $code.';
  }

  @override
  String missingRates(String codes) {
    return 'No exchange rate: $codes';
  }

  @override
  String get manualRates => 'Rates typed in';

  @override
  String get noManualRates => 'None yet.';

  @override
  String get newManualRate => 'Manual rate';

  @override
  String manualRateValue(String code, String main) {
    return 'Rate: 1 $code = ? $main';
  }

  @override
  String get manualRateInvalid => 'Give a positive number';

  @override
  String get accountNotFound => 'This account no longer exists.';

  @override
  String get noAccountEntries =>
      'No entries on this account yet. Add one with the + button.';

  @override
  String get dayBalance => 'Balance';

  @override
  String get entry => 'Entry';

  @override
  String get edit => 'Edit';

  @override
  String get discardChanges => 'Discard the changes';

  @override
  String get paysInvoice => 'The payment of';

  @override
  String get bookedEntryText =>
      'The payment of an invoice: it is changed on the invoice.';

  @override
  String get close => 'Close';

  @override
  String get openingBalanceHelper =>
      'It becomes the account\'s opening entry; later it is changed or deleted there.';

  @override
  String get openingDate => 'Opening date';

  @override
  String accountHasEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'It has $count entries (the opening one counts too): only an account without entries can be deleted.',
      one: 'It has an entry (the opening one counts too): only an account without entries can be deleted.',
    );
    return '$_temp0';
  }

  @override
  String get openingEntry => 'Opening balance';

  @override
  String get newOpeningEntry => 'Give the opening balance';

  @override
  String get openingAmountInvalid =>
      'Give an amount other than 0 (negative if overdrawn)';

  @override
  String get mainCurrencyFixed =>
      'Chosen when the user was made; it can\'t be changed.';

  @override
  String get rateManual => 'typed in';

  @override
  String get noDownloadedRate => 'no downloaded rate';

  @override
  String get useDownloadedRate => 'Back to the downloaded rate';

  @override
  String get revaluation => 'Revaluation difference';

  @override
  String get openingEntries => 'Opening entries';

  @override
  String get transfer => 'Transfer';

  @override
  String get newTransfer => 'New transfer';

  @override
  String get editTransfer => 'Edit transfer';

  @override
  String get transferFrom => 'From';

  @override
  String get transferTo => 'To';

  @override
  String get transferReceived => 'Received';

  @override
  String get transferSameAccount => 'Choose another account';

  @override
  String transferRateMade(String code, String rate) {
    return '1 $code = $rate: made from the two amounts';
  }

  @override
  String get transferWorth => 'Worth';

  @override
  String get deleteTransferConfirm => 'Delete this transfer (both its sides)?';

  @override
  String get transferText =>
      'Money moved between two of your accounts: no income or expense, the same worth on both sides.';

  @override
  String get transferNotFound => 'This transfer no longer exists.';

  @override
  String transferToAccount(String name) {
    return 'To $name';
  }

  @override
  String transferFromAccount(String name) {
    return 'From $name';
  }

  @override
  String switchUserConfirm(String name) {
    return 'Switch to $name?';
  }

  @override
  String get switchUserAction => 'Switch';

  @override
  String get balanceAfterEntry => 'Balance after it';

  @override
  String get sort => 'Order';

  @override
  String get sortNewest => 'The newest first';

  @override
  String get sortOldest => 'The oldest first';

  @override
  String get sortLargest => 'The largest amount first';

  @override
  String get sortSmallest => 'The smallest amount first';

  @override
  String get accountDescription => 'Description';

  @override
  String get bankAccountNumber => 'Account number or IBAN';

  @override
  String get bankAccountNumberHelper =>
      'Optional: 12345678-12345678-12345678 or HU42 1177 …';

  @override
  String get bankAccountNumberInvalid => 'Not a valid account number or IBAN';

  @override
  String get swiftCode => 'SWIFT / BIC';

  @override
  String get swiftCodeInvalid => '8 or 11 letters and digits, e.g. OTPVHUHB';

  @override
  String get accountClosed => 'Account closed';

  @override
  String get accountClosedText => 'Its entries stay, no new ones can go on it';

  @override
  String get closedDate => 'Closed on';

  @override
  String closeAccountBalance(String balance) {
    return 'Its balance is $balance on that day: only a 0 balance can be closed (move the rest first).';
  }

  @override
  String closeAccountLaterEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'It has $count entries after that day.',
      one: 'It has an entry after that day.',
    );
    return '$_temp0';
  }

  @override
  String closedOn(String date) {
    return 'Closed on $date';
  }

  @override
  String get closedAccounts => 'Closed accounts';

  @override
  String previousPeriodValue(String amount) {
    return 'previous: $amount';
  }

  @override
  String get outgoingInvoices => 'Outgoing invoices';

  @override
  String get revenueRecord => 'Revenue record';

  @override
  String outgoingInvoicesYear(int year) {
    return 'Outgoing invoices $year';
  }

  @override
  String incomingInvoicesYear(int year) {
    return 'Incoming invoices $year';
  }

  @override
  String get revenueRecordText =>
      'A revenue counts on the day it is received, with the paid net amount of the outgoing invoice in forints. An invoice gets here when it is paid.';

  @override
  String get revenueReceived => 'Revenue received';

  @override
  String get noRevenue => 'No revenue received in this year.';

  @override
  String cumulativeAmount(String amount) {
    return 'Cumulative $amount';
  }

  @override
  String get nextTaxPayment => 'Next tax payment';

  @override
  String get latestInvoices => 'Latest invoices';

  @override
  String revenueOfYear(int year) {
    return 'Revenue $year';
  }

  @override
  String get rateSourceOwnBank => 'Own bank';

  @override
  String get rateSourceReported => 'I chose it and reported it to NAV';

  @override
  String get rateSourceBusinessText =>
      'On an invoice in another currency the rate of your own credit institution is typed in (the default). The MNB\'s or the ECB\'s rate can be used only if you chose it and reported it to NAV. The choice is for the whole year: its rates are downloaded from 1 January.';

  @override
  String get rateSourceNotReported =>
      'Not reported: your own bank\'s rate is typed in.';

  @override
  String get rateDayFulfillment => 'fulfillment';

  @override
  String get rateDayIssue => 'issue';

  @override
  String invoiceRateHelper(
    String code,
    String source,
    String date,
    String day,
  ) {
    return 'HUF for 1 $code · $source, $date ($day)';
  }

  @override
  String noOfficialRate(String source, String date) {
    return 'No $source rate of $date yet';
  }

  @override
  String get downloadingRates => 'Downloading the rates…';

  @override
  String get rateDownloadFailed =>
      'The download failed. Try again, or check the network.';

  @override
  String get payments => 'Payments';

  @override
  String get addPayment => 'Payment';

  @override
  String get noPayments => 'Not paid yet.';

  @override
  String paidOfGross(String paid, String gross) {
    return 'Paid $paid of $gross';
  }

  @override
  String get wholeAmount => 'the whole amount';

  @override
  String paymentAtMost(String amount) {
    return 'At most $amount';
  }

  @override
  String get paymentsTooMuch => 'The payments add up to more than the invoice.';

  @override
  String get deletePaymentConfirm => 'Delete this payment?';

  @override
  String get openInvoice => 'Open the invoice';

  @override
  String get addRevenue => 'New revenue';

  @override
  String get chooseInvoiceText =>
      'Record what came in on the bank account or in the till: choose its invoice, or record a new one.';

  @override
  String get noOpenInvoices => 'No open invoices.';

  @override
  String get paymentInvoice => 'Invoice';

  @override
  String get chooseInvoice => 'Which invoice was paid?';

  @override
  String reportMadeOn(String date) {
    return 'Made on $date';
  }

  @override
  String get reportRecordNumber => 'No.';

  @override
  String get reportDocument => 'Document no.';

  @override
  String get reportReceived => 'Received on';

  @override
  String get reportForeignAmount => 'Amount in currency';

  @override
  String get reportRevenue => 'Revenue (HUF)';

  @override
  String get reportCumulative => 'Cumulative (HUF)';

  @override
  String reportRevenueLimit(int year, String amount) {
    return 'Revenue limit $year: $amount';
  }

  @override
  String get reportRateNote =>
      'A revenue in another currency counts at the rate of its invoice: of its fulfillment, or of its issue if that was earlier.';

  @override
  String reportFileName(int year) {
    return 'revenue-record-$year';
  }

  @override
  String get sendReport => 'Send or save';

  @override
  String sendAs(String format) {
    return 'Send as $format';
  }

  @override
  String saveAs(String format) {
    return 'Save as $format';
  }

  @override
  String get fileSaved => 'Saved.';

  @override
  String get reportError => 'The file couldn\'t be made.';

  @override
  String get reportReturnMonth => 'Month of the return';

  @override
  String get cumulativeRevenue => 'Revenue so far this year';

  @override
  String get taxesSoFar => 'Taxes so far this year';

  @override
  String get flatRateSummary => 'Year summary';

  @override
  String get taxesOfYear => 'Taxes of the year';

  @override
  String get quarters => 'Quarters';

  @override
  String flatRateQuarterTitle(int year, int quarter) {
    return 'Flat-rate tax $year – Q$quarter';
  }

  @override
  String flatRateSummaryTitle(int year) {
    return 'Flat-rate tax $year – year summary';
  }

  @override
  String flatRateQuarterFile(int year, int quarter) {
    return 'flat-rate-tax-$year-q$quarter';
  }

  @override
  String flatRateSummaryFile(int year) {
    return 'flat-rate-tax-$year-summary';
  }

  @override
  String get reportItem => 'Item';

  @override
  String get reportBase => 'Base (HUF)';

  @override
  String get reportAmount => 'Amount (HUF)';

  @override
  String get reportPayee => 'Payee';

  @override
  String get reportTaxCode => 'Tax code';

  @override
  String get reportAccount => 'Account number';

  @override
  String get taxFreeIncome => 'Tax-free income';

  @override
  String get deadlineLabel => 'Deadline';

  @override
  String get flatRateCost => 'Costs';

  @override
  String costRatioHint(int ratio) {
    return '$ratio% cost ratio';
  }

  @override
  String get taxFreePart => 'Tax-free part';

  @override
  String taxFreePartHint(String amount) {
    return 'Half the minimum wage of the year: $amount';
  }

  @override
  String taxFreeRevenueNote(String amount) {
    return 'No tax up to a revenue of $amount (with this cost ratio).';
  }
}
