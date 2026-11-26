import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hu'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Fineva'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your finances in order'**
  String get tagline;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @entries.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get entries;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @addEntry.
  ///
  /// In en, this message translates to:
  /// **'New entry'**
  String get addEntry;

  /// No description provided for @editEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get editEntry;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @amountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero'**
  String get amountInvalid;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @noCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get noCategory;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Saving failed'**
  String get saveError;

  /// No description provided for @deleteError.
  ///
  /// In en, this message translates to:
  /// **'Deleting failed'**
  String get deleteError;

  /// No description provided for @deleteEntryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get deleteEntryConfirm;

  /// No description provided for @noEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries yet. Add one with the + button.'**
  String get noEntries;

  /// No description provided for @noAccounts.
  ///
  /// In en, this message translates to:
  /// **'Add an account first to record income and expenses.'**
  String get noAccounts;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get addAccount;

  /// No description provided for @editAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get editAccount;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @accountType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get accountType;

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBank.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get accountTypeBank;

  /// No description provided for @accountTypeCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get accountTypeCard;

  /// No description provided for @accountTypeSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get accountTypeSavings;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @currencyName.
  ///
  /// In en, this message translates to:
  /// **'{code, select, HUF{Hungarian forint} EUR{Euro} USD{US dollar} GBP{Pound sterling} CHF{Swiss franc} CZK{Czech koruna} PLN{Polish złoty} RON{Romanian leu} SEK{Swedish krona} NOK{Norwegian krone} DKK{Danish krone} ISK{Icelandic króna} TRY{Turkish lira} JPY{Japanese yen} CNY{Chinese yuan} HKD{Hong Kong dollar} KRW{South Korean won} SGD{Singapore dollar} INR{Indian rupee} IDR{Indonesian rupiah} MYR{Malaysian ringgit} PHP{Philippine peso} THB{Thai baht} ILS{Israeli new shekel} AUD{Australian dollar} NZD{New Zealand dollar} CAD{Canadian dollar} MXN{Mexican peso} BRL{Brazilian real} ZAR{South African rand} other{{code}}}'**
  String currencyName(String code);

  /// No description provided for @initialBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get initialBalance;

  /// No description provided for @initialBalanceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get initialBalanceInvalid;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Delete the account {name}?} =1{Delete the account {name} and its entry?} other{Delete the account {name} and its {count} entries?}}'**
  String deleteAccountConfirm(String name, int count);

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get addCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @deleteCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this category? Its entries stay, without a category.'**
  String get deleteCategoryConfirm;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Device setting'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {message}'**
  String errorMessage(String message);

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'The data couldn\'t be loaded: {message}'**
  String loadError(String message);

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Fineva!'**
  String get welcomeTitle;

  /// No description provided for @welcomeText.
  ///
  /// In en, this message translates to:
  /// **'Let\'s set it up in a few steps.'**
  String get welcomeText;

  /// No description provided for @usageTitle.
  ///
  /// In en, this message translates to:
  /// **'What will you use Fineva for?'**
  String get usageTitle;

  /// No description provided for @userTypePersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal finances'**
  String get userTypePersonal;

  /// No description provided for @userTypePersonalText.
  ///
  /// In en, this message translates to:
  /// **'Your own income, expenses and accounts'**
  String get userTypePersonalText;

  /// No description provided for @userTypeSoleProprietor.
  ///
  /// In en, this message translates to:
  /// **'Sole proprietor finances'**
  String get userTypeSoleProprietor;

  /// No description provided for @userTypeSoleProprietorText.
  ///
  /// In en, this message translates to:
  /// **'Your business\'s income and expenses, set up for your taxation'**
  String get userTypeSoleProprietorText;

  /// No description provided for @businessTitle.
  ///
  /// In en, this message translates to:
  /// **'Your business'**
  String get businessTitle;

  /// No description provided for @taxRegime.
  ///
  /// In en, this message translates to:
  /// **'Taxation'**
  String get taxRegime;

  /// No description provided for @taxRegimeItemized.
  ///
  /// In en, this message translates to:
  /// **'Entrepreneurial personal income tax'**
  String get taxRegimeItemized;

  /// No description provided for @taxRegimeItemizedText.
  ///
  /// In en, this message translates to:
  /// **'Taxed on your actual, documented costs'**
  String get taxRegimeItemizedText;

  /// No description provided for @taxRegimeFlatRate.
  ///
  /// In en, this message translates to:
  /// **'Flat-rate tax'**
  String get taxRegimeFlatRate;

  /// No description provided for @taxRegimeFlatRateText.
  ///
  /// In en, this message translates to:
  /// **'Your revenue minus a fixed cost ratio is taxed'**
  String get taxRegimeFlatRateText;

  /// No description provided for @taxRegimeKata.
  ///
  /// In en, this message translates to:
  /// **'KATA'**
  String get taxRegimeKata;

  /// No description provided for @taxRegimeKataText.
  ///
  /// In en, this message translates to:
  /// **'Fixed monthly tax, for sales to private persons'**
  String get taxRegimeKataText;

  /// No description provided for @vat.
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get vat;

  /// No description provided for @vatRegistered.
  ///
  /// In en, this message translates to:
  /// **'VAT registered'**
  String get vatRegistered;

  /// No description provided for @vatRegisteredText.
  ///
  /// In en, this message translates to:
  /// **'You charge VAT and file VAT returns'**
  String get vatRegisteredText;

  /// No description provided for @vatExempt.
  ///
  /// In en, this message translates to:
  /// **'VAT exempt'**
  String get vatExempt;

  /// No description provided for @vatExemptText.
  ///
  /// In en, this message translates to:
  /// **'Your yearly revenue is under the VAT exemption limit'**
  String get vatExemptText;

  /// No description provided for @euReporting.
  ///
  /// In en, this message translates to:
  /// **'EU reporting'**
  String get euReporting;

  /// No description provided for @euReportingText.
  ///
  /// In en, this message translates to:
  /// **'EU VAT number, recapitulative statement of intra-EU transactions'**
  String get euReportingText;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @latestEntries.
  ///
  /// In en, this message translates to:
  /// **'Latest entries'**
  String get latestEntries;

  /// No description provided for @allEntries.
  ///
  /// In en, this message translates to:
  /// **'All entries'**
  String get allEntries;

  /// No description provided for @detailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get detailsTitle;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'1234 Budapest, Main street 1.'**
  String get addressHint;

  /// No description provided for @taxId.
  ///
  /// In en, this message translates to:
  /// **'Tax identification number'**
  String get taxId;

  /// No description provided for @taxIdHelper.
  ///
  /// In en, this message translates to:
  /// **'10 digits starting with 8, on your tax card'**
  String get taxIdHelper;

  /// No description provided for @taxIdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not a valid tax identification number'**
  String get taxIdInvalid;

  /// No description provided for @taxNumber.
  ///
  /// In en, this message translates to:
  /// **'Tax number'**
  String get taxNumber;

  /// No description provided for @taxNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not a valid tax number (12345678-1-12)'**
  String get taxNumberInvalid;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @newUser.
  ///
  /// In en, this message translates to:
  /// **'New user'**
  String get newUser;

  /// No description provided for @newUserText.
  ///
  /// In en, this message translates to:
  /// **'Set up Fineva for someone else, with their own accounts and entries'**
  String get newUserText;

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete user'**
  String get deleteUser;

  /// No description provided for @deleteUserConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} with all their accounts, entries and categories?'**
  String deleteUserConfirm(String name);

  /// No description provided for @switchUser.
  ///
  /// In en, this message translates to:
  /// **'Switch user'**
  String get switchUser;

  /// No description provided for @unnamedUser.
  ///
  /// In en, this message translates to:
  /// **'Unnamed user'**
  String get unnamedUser;

  /// No description provided for @whoUses.
  ///
  /// In en, this message translates to:
  /// **'Who uses Fineva now?'**
  String get whoUses;

  /// No description provided for @welcomeBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBackTitle;

  /// No description provided for @welcomeBackText.
  ///
  /// In en, this message translates to:
  /// **'Choose the user, then check the details. Skip goes straight on.'**
  String get welcomeBackText;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @onboardingAtStart.
  ///
  /// In en, this message translates to:
  /// **'Onboarding at every start'**
  String get onboardingAtStart;

  /// No description provided for @onboardingAtStartText.
  ///
  /// In en, this message translates to:
  /// **'Choose the user and check the details when Fineva starts'**
  String get onboardingAtStartText;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Back up data'**
  String get backup;

  /// No description provided for @backupText.
  ///
  /// In en, this message translates to:
  /// **'Save every user\'s data into a file'**
  String get backupText;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSaved;

  /// No description provided for @backupError.
  ///
  /// In en, this message translates to:
  /// **'The backup couldn\'t be saved'**
  String get backupError;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore data'**
  String get restore;

  /// No description provided for @restoreText.
  ///
  /// In en, this message translates to:
  /// **'Replace all data with a backup'**
  String get restoreText;

  /// No description provided for @restoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restoring replaces all current data, of every user, with the backup. Go on?'**
  String get restoreConfirm;

  /// No description provided for @restored.
  ///
  /// In en, this message translates to:
  /// **'Data restored'**
  String get restored;

  /// No description provided for @restoreInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is not a Fineva backup'**
  String get restoreInvalid;

  /// No description provided for @restoreNewer.
  ///
  /// In en, this message translates to:
  /// **'This backup was made by a newer Fineva. Update the app first.'**
  String get restoreNewer;

  /// No description provided for @restoreError.
  ///
  /// In en, this message translates to:
  /// **'The data couldn\'t be restored'**
  String get restoreError;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @cashFlow.
  ///
  /// In en, this message translates to:
  /// **'Cash flow'**
  String get cashFlow;

  /// No description provided for @netResult.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get netResult;

  /// No description provided for @savingsRate.
  ///
  /// In en, this message translates to:
  /// **'Savings rate'**
  String get savingsRate;

  /// No description provided for @closingBalance.
  ///
  /// In en, this message translates to:
  /// **'Closing balance'**
  String get closingBalance;

  /// No description provided for @changeInPeriod.
  ///
  /// In en, this message translates to:
  /// **'Change in the period:'**
  String get changeInPeriod;

  /// No description provided for @categoryTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String categoryTotal(String amount);

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @choosePeriod.
  ///
  /// In en, this message translates to:
  /// **'Choose period'**
  String get choosePeriod;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// No description provided for @periodQuarter.
  ///
  /// In en, this message translates to:
  /// **'Quarter'**
  String get periodQuarter;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// No description provided for @periodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get periodCustom;

  /// No description provided for @quarterOfYear.
  ///
  /// In en, this message translates to:
  /// **'Q{quarter} {year}'**
  String quarterOfYear(int quarter, int year);

  /// No description provided for @quarterOfYearShort.
  ///
  /// In en, this message translates to:
  /// **'Q{quarter} {year}'**
  String quarterOfYearShort(int quarter, int year);

  /// No description provided for @noEntriesInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No entries in this period.'**
  String get noEntriesInPeriod;

  /// No description provided for @allEntriesCount.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String allEntriesCount(int count);

  /// No description provided for @previousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousPeriod;

  /// No description provided for @nextPeriod.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextPeriod;

  /// No description provided for @euVatNumber.
  ///
  /// In en, this message translates to:
  /// **'EU VAT number'**
  String get euVatNumber;

  /// No description provided for @euVatNumberHelper.
  ///
  /// In en, this message translates to:
  /// **'HU and the first 8 digits of your tax number'**
  String get euVatNumberHelper;

  /// No description provided for @euVatNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'EU reporting needs your EU VAT number'**
  String get euVatNumberRequired;

  /// No description provided for @euVatNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not a valid EU VAT number (HU12345678)'**
  String get euVatNumberInvalid;

  /// No description provided for @euVatNumberMismatch.
  ///
  /// In en, this message translates to:
  /// **'It doesn\'t match your tax number: HU and its first 8 digits'**
  String get euVatNumberMismatch;

  /// No description provided for @taxNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'A sole proprietor needs a Hungarian tax number'**
  String get taxNumberRequired;

  /// No description provided for @taxNumberHelper.
  ///
  /// In en, this message translates to:
  /// **'Your tax number: 12345678-1-12'**
  String get taxNumberHelper;

  /// No description provided for @costRatio.
  ///
  /// In en, this message translates to:
  /// **'Cost ratio'**
  String get costRatio;

  /// No description provided for @costRatioGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get costRatioGeneral;

  /// No description provided for @costRatioListed.
  ///
  /// In en, this message translates to:
  /// **'Activities listed in the law'**
  String get costRatioListed;

  /// No description provided for @costRatioRetail.
  ///
  /// In en, this message translates to:
  /// **'Retail trade'**
  String get costRatioRetail;

  /// No description provided for @mainOccupation.
  ///
  /// In en, this message translates to:
  /// **'Main occupation'**
  String get mainOccupation;

  /// No description provided for @mainOccupationText.
  ///
  /// In en, this message translates to:
  /// **'No employment of at least 36 hours a week beside it: the minimum contributions apply'**
  String get mainOccupationText;

  /// No description provided for @vatPeriod.
  ///
  /// In en, this message translates to:
  /// **'VAT return'**
  String get vatPeriod;

  /// No description provided for @vatPeriodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get vatPeriodMonthly;

  /// No description provided for @vatPeriodQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get vatPeriodQuarterly;

  /// No description provided for @vatPeriodYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get vatPeriodYearly;

  /// No description provided for @business.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get business;

  /// No description provided for @businessOnlyText.
  ///
  /// In en, this message translates to:
  /// **'Only for sole proprietors.'**
  String get businessOnlyText;

  /// No description provided for @businessIncompleteText.
  ///
  /// In en, this message translates to:
  /// **'Your tax number is missing. Complete your profile to keep the business records.'**
  String get businessIncompleteText;

  /// No description provided for @invoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoices;

  /// No description provided for @previousYear.
  ///
  /// In en, this message translates to:
  /// **'Previous year'**
  String get previousYear;

  /// No description provided for @nextYear.
  ///
  /// In en, this message translates to:
  /// **'Next year'**
  String get nextYear;

  /// No description provided for @addInvoice.
  ///
  /// In en, this message translates to:
  /// **'New invoice'**
  String get addInvoice;

  /// No description provided for @editInvoice.
  ///
  /// In en, this message translates to:
  /// **'Edit invoice'**
  String get editInvoice;

  /// No description provided for @deleteInvoiceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this invoice?'**
  String get deleteInvoiceConfirm;

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get amountRequired;

  /// No description provided for @invoiceOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing (revenue)'**
  String get invoiceOutgoing;

  /// No description provided for @invoiceIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming (cost)'**
  String get invoiceIncoming;

  /// No description provided for @invoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get invoiceNumber;

  /// No description provided for @invoiceNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the invoice number'**
  String get invoiceNumberRequired;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentMethod;

  /// No description provided for @paymentTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get paymentTransfer;

  /// No description provided for @paymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCash;

  /// No description provided for @paymentCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentCard;

  /// No description provided for @invoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get invoiceDescription;

  /// No description provided for @partner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get partner;

  /// No description provided for @partnerDomestic.
  ///
  /// In en, this message translates to:
  /// **'Domestic'**
  String get partnerDomestic;

  /// No description provided for @partnerEu.
  ///
  /// In en, this message translates to:
  /// **'EU'**
  String get partnerEu;

  /// No description provided for @partnerThirdCountry.
  ///
  /// In en, this message translates to:
  /// **'Third country'**
  String get partnerThirdCountry;

  /// No description provided for @partnerName.
  ///
  /// In en, this message translates to:
  /// **'Partner name'**
  String get partnerName;

  /// No description provided for @foreignTaxNumber.
  ///
  /// In en, this message translates to:
  /// **'Tax number'**
  String get foreignTaxNumber;

  /// No description provided for @partnerEuVatNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Country code and number, e.g. DE123456789'**
  String get partnerEuVatNumberInvalid;

  /// No description provided for @dates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get dates;

  /// No description provided for @issueDate.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get issueDate;

  /// No description provided for @fulfillmentDate.
  ///
  /// In en, this message translates to:
  /// **'Fulfilled'**
  String get fulfillmentDate;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get dueDate;

  /// No description provided for @exchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get exchangeRate;

  /// No description provided for @exchangeRateHelper.
  ///
  /// In en, this message translates to:
  /// **'HUF for 1 {code}'**
  String exchangeRateHelper(String code);

  /// No description provided for @exchangeRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the exchange rate'**
  String get exchangeRateInvalid;

  /// No description provided for @vatCode.
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get vatCode;

  /// No description provided for @netAmount.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get netAmount;

  /// No description provided for @vatAmount.
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get vatAmount;

  /// No description provided for @grossAmount.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get grossAmount;

  /// No description provided for @reverseChargeText.
  ///
  /// In en, this message translates to:
  /// **'Reverse charge: you pay the {rate}% VAT, and deduct it if you are VAT registered.'**
  String reverseChargeText(int rate);

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @paidRevenueText.
  ///
  /// In en, this message translates to:
  /// **'Flat-rate revenue counts when it is paid'**
  String get paidRevenueText;

  /// No description provided for @paidCostText.
  ///
  /// In en, this message translates to:
  /// **'When you paid it'**
  String get paidCostText;

  /// No description provided for @paidDate.
  ///
  /// In en, this message translates to:
  /// **'Paid on'**
  String get paidDate;

  /// No description provided for @paidAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid amount'**
  String get paidAmount;

  /// No description provided for @vatCode27.
  ///
  /// In en, this message translates to:
  /// **'27% VAT'**
  String get vatCode27;

  /// No description provided for @vatCode18.
  ///
  /// In en, this message translates to:
  /// **'18% VAT'**
  String get vatCode18;

  /// No description provided for @vatCode5.
  ///
  /// In en, this message translates to:
  /// **'5% VAT'**
  String get vatCode5;

  /// No description provided for @vatCode0.
  ///
  /// In en, this message translates to:
  /// **'0% VAT'**
  String get vatCode0;

  /// No description provided for @vatCodeAam.
  ///
  /// In en, this message translates to:
  /// **'AAM – subjective VAT exemption'**
  String get vatCodeAam;

  /// No description provided for @vatCodeTam.
  ///
  /// In en, this message translates to:
  /// **'TAM – exempt activity'**
  String get vatCodeTam;

  /// No description provided for @vatCodeAtk.
  ///
  /// In en, this message translates to:
  /// **'ATK – outside the scope of VAT'**
  String get vatCodeAtk;

  /// No description provided for @vatCodeFad.
  ///
  /// In en, this message translates to:
  /// **'FAD – domestic reverse charge'**
  String get vatCodeFad;

  /// No description provided for @vatCodeKbaet.
  ///
  /// In en, this message translates to:
  /// **'KBAET – exempt intra-EU supply of goods'**
  String get vatCodeKbaet;

  /// No description provided for @vatCodeEufad37.
  ///
  /// In en, this message translates to:
  /// **'EUFAD37 – service to an EU business (reverse charge)'**
  String get vatCodeEufad37;

  /// No description provided for @vatCodeEufade.
  ///
  /// In en, this message translates to:
  /// **'EUFADE – other reverse charge supply in the EU'**
  String get vatCodeEufade;

  /// No description provided for @vatCodeEue.
  ///
  /// In en, this message translates to:
  /// **'EUE – supply in another member state'**
  String get vatCodeEue;

  /// No description provided for @vatCodeEuGoods.
  ///
  /// In en, this message translates to:
  /// **'Intra-EU acquisition of goods (reverse charge)'**
  String get vatCodeEuGoods;

  /// No description provided for @vatCodeEuServices.
  ///
  /// In en, this message translates to:
  /// **'Service from the EU (reverse charge)'**
  String get vatCodeEuServices;

  /// No description provided for @vatCodeEam.
  ///
  /// In en, this message translates to:
  /// **'EAM – export, exempt'**
  String get vatCodeEam;

  /// No description provided for @vatCodeHo.
  ///
  /// In en, this message translates to:
  /// **'HO – supply in a third country'**
  String get vatCodeHo;

  /// No description provided for @vatCodeNam.
  ///
  /// In en, this message translates to:
  /// **'NAM – other international exemption'**
  String get vatCodeNam;

  /// No description provided for @vatCodeImportServices.
  ///
  /// In en, this message translates to:
  /// **'Service from a third country (reverse charge)'**
  String get vatCodeImportServices;

  /// No description provided for @vatCodeImportGoods.
  ///
  /// In en, this message translates to:
  /// **'Import of goods (reverse charge)'**
  String get vatCodeImportGoods;

  /// No description provided for @incomeRecord.
  ///
  /// In en, this message translates to:
  /// **'Income record {year}'**
  String incomeRecord(int year);

  /// No description provided for @costRecord.
  ///
  /// In en, this message translates to:
  /// **'Cost record {year}'**
  String costRecord(int year);

  /// No description provided for @grossTotal.
  ///
  /// In en, this message translates to:
  /// **'Gross total'**
  String get grossTotal;

  /// No description provided for @openTotal.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openTotal;

  /// No description provided for @flatRateRevenue.
  ///
  /// In en, this message translates to:
  /// **'Flat-rate revenue (paid, net)'**
  String get flatRateRevenue;

  /// No description provided for @kataRevenue.
  ///
  /// In en, this message translates to:
  /// **'KATA revenue'**
  String get kataRevenue;

  /// No description provided for @kataTaxText.
  ///
  /// In en, this message translates to:
  /// **'KATA tax: {amount} a month'**
  String kataTaxText(String amount);

  /// No description provided for @noInvoices.
  ///
  /// In en, this message translates to:
  /// **'No invoices in this year.'**
  String get noInvoices;

  /// No description provided for @openAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} open'**
  String openAmount(String amount);

  /// No description provided for @flatRateYear.
  ///
  /// In en, this message translates to:
  /// **'Flat-rate taxation {year}'**
  String flatRateYear(int year);

  /// No description provided for @flatRateOverLimit.
  ///
  /// In en, this message translates to:
  /// **'Over the revenue limit: flat-rate taxation ends.'**
  String get flatRateOverLimit;

  /// No description provided for @taxFreeRevenue.
  ///
  /// In en, this message translates to:
  /// **'Tax-free revenue'**
  String get taxFreeRevenue;

  /// No description provided for @taxFreeRevenueHint.
  ///
  /// In en, this message translates to:
  /// **'{income} tax-free income at a {ratio}% cost ratio'**
  String taxFreeRevenueHint(String income, int ratio);

  /// No description provided for @yearlyTaxes.
  ///
  /// In en, this message translates to:
  /// **'Taxes of the year'**
  String get yearlyTaxes;

  /// No description provided for @taxYearUnknown.
  ///
  /// In en, this message translates to:
  /// **'The amounts of {year} are not known yet: those of {known} are used.'**
  String taxYearUnknown(int year, int known);

  /// No description provided for @quarterName.
  ///
  /// In en, this message translates to:
  /// **'Q{quarter}'**
  String quarterName(int quarter);

  /// No description provided for @deadline.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String deadline(String date);

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @flatRateIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get flatRateIncome;

  /// No description provided for @taxableIncome.
  ///
  /// In en, this message translates to:
  /// **'Taxable income'**
  String get taxableIncome;

  /// No description provided for @taxFreeIncomeHint.
  ///
  /// In en, this message translates to:
  /// **'Tax free: {amount}'**
  String taxFreeIncomeHint(String amount);

  /// No description provided for @szja.
  ///
  /// In en, this message translates to:
  /// **'Personal income tax (15%)'**
  String get szja;

  /// No description provided for @tbContribution.
  ///
  /// In en, this message translates to:
  /// **'Social security contribution (18.5%)'**
  String get tbContribution;

  /// No description provided for @szocho.
  ///
  /// In en, this message translates to:
  /// **'Social contribution tax (13%)'**
  String get szocho;

  /// No description provided for @localTax.
  ///
  /// In en, this message translates to:
  /// **'Local business tax'**
  String get localTax;

  /// No description provided for @chamberFee.
  ///
  /// In en, this message translates to:
  /// **'Chamber fee'**
  String get chamberFee;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @baseHint.
  ///
  /// In en, this message translates to:
  /// **'Base: {amount}'**
  String baseHint(String amount);

  /// No description provided for @toTransfer.
  ///
  /// In en, this message translates to:
  /// **'To transfer'**
  String get toTransfer;

  /// No description provided for @taxCode.
  ///
  /// In en, this message translates to:
  /// **'Tax code {code}'**
  String taxCode(String code);

  /// No description provided for @municipalityAccount.
  ///
  /// In en, this message translates to:
  /// **'to the municipality\'s account'**
  String get municipalityAccount;

  /// No description provided for @taxKindSzja.
  ///
  /// In en, this message translates to:
  /// **'NAV personal income tax'**
  String get taxKindSzja;

  /// No description provided for @taxKindSzocho.
  ///
  /// In en, this message translates to:
  /// **'NAV social contribution tax'**
  String get taxKindSzocho;

  /// No description provided for @taxKindTb.
  ///
  /// In en, this message translates to:
  /// **'NAV social security contribution'**
  String get taxKindTb;

  /// No description provided for @taxKindLocalTax.
  ///
  /// In en, this message translates to:
  /// **'Local business tax'**
  String get taxKindLocalTax;

  /// No description provided for @taxKindChamberFee.
  ///
  /// In en, this message translates to:
  /// **'Hungarian Chamber of Commerce and Industry'**
  String get taxKindChamberFee;

  /// No description provided for @copyAccount.
  ///
  /// In en, this message translates to:
  /// **'Copy the account number'**
  String get copyAccount;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied: {text}'**
  String copied(String text);

  /// No description provided for @vatPayable.
  ///
  /// In en, this message translates to:
  /// **'Payable VAT'**
  String get vatPayable;

  /// No description provided for @vatDeductible.
  ///
  /// In en, this message translates to:
  /// **'Deductible VAT'**
  String get vatDeductible;

  /// No description provided for @reverseCharge.
  ///
  /// In en, this message translates to:
  /// **'Reverse charge'**
  String get reverseCharge;

  /// No description provided for @vatTotalRounded.
  ///
  /// In en, this message translates to:
  /// **'Total (in thousands)'**
  String get vatTotalRounded;

  /// No description provided for @vatExemptReverseChargeText.
  ///
  /// In en, this message translates to:
  /// **'As VAT exempt you pay the reverse charge VAT without deduction.'**
  String get vatExemptReverseChargeText;

  /// No description provided for @vatToPay.
  ///
  /// In en, this message translates to:
  /// **'Balance: to pay'**
  String get vatToPay;

  /// No description provided for @vatToReclaim.
  ///
  /// In en, this message translates to:
  /// **'Balance: to reclaim or carry forward'**
  String get vatToReclaim;

  /// No description provided for @salesWithoutVat.
  ///
  /// In en, this message translates to:
  /// **'Sales without VAT'**
  String get salesWithoutVat;

  /// No description provided for @vatDateRuleText.
  ///
  /// In en, this message translates to:
  /// **'By VAT date: an outgoing invoice counts on its payment date if paid within {days} days of the fulfillment, otherwise on the fulfillment + {days} days; an incoming one on its fulfillment date.'**
  String vatDateRuleText(int days);

  /// No description provided for @vatDateLine.
  ///
  /// In en, this message translates to:
  /// **'VAT date: {date} (the payment date within {days} days of the fulfillment, otherwise the fulfillment + {days} days)'**
  String vatDateLine(String date, int days);

  /// No description provided for @taxTreatment.
  ///
  /// In en, this message translates to:
  /// **'Business tax'**
  String get taxTreatment;

  /// No description provided for @taxTreatmentNone.
  ///
  /// In en, this message translates to:
  /// **'Not a business item'**
  String get taxTreatmentNone;

  /// No description provided for @taxTreatmentRevenue.
  ///
  /// In en, this message translates to:
  /// **'Taxable revenue'**
  String get taxTreatmentRevenue;

  /// No description provided for @taxTreatmentNonTaxableIncome.
  ///
  /// In en, this message translates to:
  /// **'Non-taxable income'**
  String get taxTreatmentNonTaxableIncome;

  /// No description provided for @taxTreatmentWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Cost: withdrawal (gross)'**
  String get taxTreatmentWithdrawal;

  /// No description provided for @taxTreatmentSzocho.
  ///
  /// In en, this message translates to:
  /// **'Cost: SZOCHO'**
  String get taxTreatmentSzocho;

  /// No description provided for @taxTreatmentOtherCost.
  ///
  /// In en, this message translates to:
  /// **'Cost: other'**
  String get taxTreatmentOtherCost;

  /// No description provided for @taxTreatmentMaterialCost.
  ///
  /// In en, this message translates to:
  /// **'Cost: material'**
  String get taxTreatmentMaterialCost;

  /// No description provided for @taxTreatmentBankCost.
  ///
  /// In en, this message translates to:
  /// **'Cost: bank charges'**
  String get taxTreatmentBankCost;

  /// No description provided for @taxTreatmentAccountingCost.
  ///
  /// In en, this message translates to:
  /// **'Cost: accounting'**
  String get taxTreatmentAccountingCost;

  /// No description provided for @taxTreatmentItCost.
  ///
  /// In en, this message translates to:
  /// **'Cost: IT'**
  String get taxTreatmentItCost;

  /// No description provided for @taxTreatmentNonDeductible.
  ///
  /// In en, this message translates to:
  /// **'Non-deductible spending'**
  String get taxTreatmentNonDeductible;

  /// No description provided for @taxTreatmentVat.
  ///
  /// In en, this message translates to:
  /// **'VAT (not a cost)'**
  String get taxTreatmentVat;

  /// No description provided for @entryExchangeRateHelper.
  ///
  /// In en, this message translates to:
  /// **'{main} / 1 {code} on the day'**
  String entryExchangeRateHelper(String main, String code);

  /// No description provided for @itemizedTab.
  ///
  /// In en, this message translates to:
  /// **'Itemized tax'**
  String get itemizedTab;

  /// No description provided for @assets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assets;

  /// No description provided for @itemizedSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Business categories'**
  String get itemizedSetupTitle;

  /// No description provided for @itemizedSetupText.
  ///
  /// In en, this message translates to:
  /// **'The itemized tax is calculated from the entries of the categories with a business tax treatment. Add the categories of the cash-flow ledger (taxable revenue, withdrawal, costs, …), or set the treatment of your own categories.'**
  String get itemizedSetupText;

  /// No description provided for @addBusinessCategories.
  ///
  /// In en, this message translates to:
  /// **'Add the business categories'**
  String get addBusinessCategories;

  /// No description provided for @missingExchangeRates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry of a foreign currency account has no exchange rate: it is left out.} other{{count} entries of foreign currency accounts have no exchange rate: they are left out.}}'**
  String missingExchangeRates(int count);

  /// No description provided for @itemizedYear.
  ///
  /// In en, this message translates to:
  /// **'Itemized tax {year}'**
  String itemizedYear(int year);

  /// No description provided for @taxableRevenue.
  ///
  /// In en, this message translates to:
  /// **'Taxable revenue'**
  String get taxableRevenue;

  /// No description provided for @costs.
  ///
  /// In en, this message translates to:
  /// **'Costs'**
  String get costs;

  /// No description provided for @depreciationHint.
  ///
  /// In en, this message translates to:
  /// **'Depreciation included: {amount}'**
  String depreciationHint(String amount);

  /// No description provided for @taxBase.
  ///
  /// In en, this message translates to:
  /// **'Tax base'**
  String get taxBase;

  /// No description provided for @vszja.
  ///
  /// In en, this message translates to:
  /// **'Entrepreneurial income tax (9%)'**
  String get vszja;

  /// No description provided for @dividendBase.
  ///
  /// In en, this message translates to:
  /// **'Entrepreneurial dividend base'**
  String get dividendBase;

  /// No description provided for @dividendSzja.
  ///
  /// In en, this message translates to:
  /// **'SZJA on the dividend base (15%)'**
  String get dividendSzja;

  /// No description provided for @szochoOnDividend.
  ///
  /// In en, this message translates to:
  /// **'SZOCHO on the dividend base, after the year'**
  String get szochoOnDividend;

  /// No description provided for @szochoCapHint.
  ///
  /// In en, this message translates to:
  /// **'Up to the cap of {cap}, {paid} paid on the withdrawal'**
  String szochoCapHint(String cap, String paid);

  /// No description provided for @byTreatment.
  ///
  /// In en, this message translates to:
  /// **'By business category'**
  String get byTreatment;

  /// No description provided for @depreciation.
  ///
  /// In en, this message translates to:
  /// **'Depreciation'**
  String get depreciation;

  /// No description provided for @lossCarried.
  ///
  /// In en, this message translates to:
  /// **'Loss of the quarter before'**
  String get lossCarried;

  /// No description provided for @depreciationOfYear.
  ///
  /// In en, this message translates to:
  /// **'Depreciation this year: {amount}'**
  String depreciationOfYear(String amount);

  /// No description provided for @addAsset.
  ///
  /// In en, this message translates to:
  /// **'New asset'**
  String get addAsset;

  /// No description provided for @editAsset.
  ///
  /// In en, this message translates to:
  /// **'Edit asset'**
  String get editAsset;

  /// No description provided for @noAssets.
  ///
  /// In en, this message translates to:
  /// **'No assets yet.'**
  String get noAssets;

  /// No description provided for @assetRemaining.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String assetRemaining(String amount);

  /// No description provided for @deleteAssetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this asset?'**
  String get deleteAssetConfirm;

  /// No description provided for @purchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Put into use'**
  String get purchaseDate;

  /// No description provided for @supplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplier;

  /// No description provided for @assetCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get assetCost;

  /// No description provided for @depreciationRate.
  ///
  /// In en, this message translates to:
  /// **'Yearly depreciation rate'**
  String get depreciationRate;

  /// No description provided for @depreciationRateHelper.
  ///
  /// In en, this message translates to:
  /// **'E.g. 33 for computers, 14.5 for other machines; 100 writes off a small asset at once'**
  String get depreciationRateHelper;

  /// No description provided for @depreciationRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'A rate from 0 to 100'**
  String get depreciationRateInvalid;

  /// No description provided for @vatPeriodBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance of the period'**
  String get vatPeriodBalance;

  /// No description provided for @vatCarriedIn.
  ///
  /// In en, this message translates to:
  /// **'Carried forward from before'**
  String get vatCarriedIn;

  /// No description provided for @searchEntries.
  ///
  /// In en, this message translates to:
  /// **'Note, category, account, amount'**
  String get searchEntries;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear the search'**
  String get clearSearch;

  /// No description provided for @filterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get filterType;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @noMatchingEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries match the search and filters.'**
  String get noMatchingEntries;

  /// No description provided for @entryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String entryCount(int count);

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @balanceAt.
  ///
  /// In en, this message translates to:
  /// **'Balance on {date}'**
  String balanceAt(String date);

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @removeFilter.
  ///
  /// In en, this message translates to:
  /// **'Remove the filter'**
  String get removeFilter;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @userTypeFixed.
  ///
  /// In en, this message translates to:
  /// **'A user\'s kind can\'t change after it is created.'**
  String get userTypeFixed;

  /// No description provided for @bookingText.
  ///
  /// In en, this message translates to:
  /// **'The payment is booked as an entry on the account, so it is in the entries and the balances.'**
  String get bookingText;

  /// No description provided for @bookedOn.
  ///
  /// In en, this message translates to:
  /// **'Booked on'**
  String get bookedOn;

  /// No description provided for @notBooked.
  ///
  /// In en, this message translates to:
  /// **'Not booked'**
  String get notBooked;

  /// No description provided for @paidExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate of the payment'**
  String get paidExchangeRate;

  /// No description provided for @paidExchangeRateHelper.
  ///
  /// In en, this message translates to:
  /// **'Empty: the invoice\'s rate'**
  String get paidExchangeRateHelper;

  /// No description provided for @openInvoices.
  ///
  /// In en, this message translates to:
  /// **'Open invoices'**
  String get openInvoices;

  /// No description provided for @receivables.
  ///
  /// In en, this message translates to:
  /// **'Owed to you'**
  String get receivables;

  /// No description provided for @payables.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get payables;

  /// No description provided for @exchangeRates.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates'**
  String get exchangeRates;

  /// No description provided for @exchangeRatesText.
  ///
  /// In en, this message translates to:
  /// **'Main currency, source, rates typed in'**
  String get exchangeRatesText;

  /// No description provided for @updateRates.
  ///
  /// In en, this message translates to:
  /// **'Download the rates now'**
  String get updateRates;

  /// No description provided for @mainCurrency.
  ///
  /// In en, this message translates to:
  /// **'Main currency'**
  String get mainCurrency;

  /// No description provided for @mainCurrencyText.
  ///
  /// In en, this message translates to:
  /// **'The dashboard and the statistics show everything in it. It can\'t be changed later.'**
  String get mainCurrencyText;

  /// No description provided for @mainCurrencySoleProprietor.
  ///
  /// In en, this message translates to:
  /// **'Always the forint for a sole proprietor: the taxes are in forints.'**
  String get mainCurrencySoleProprietor;

  /// No description provided for @rateSource.
  ///
  /// In en, this message translates to:
  /// **'Source of the rates'**
  String get rateSource;

  /// No description provided for @rateSourceMnb.
  ///
  /// In en, this message translates to:
  /// **'MNB'**
  String get rateSourceMnb;

  /// No description provided for @rateSourceEcb.
  ///
  /// In en, this message translates to:
  /// **'ECB'**
  String get rateSourceEcb;

  /// No description provided for @rateSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get rateSourceManual;

  /// No description provided for @rateSourceText.
  ///
  /// In en, this message translates to:
  /// **'MNB: the Magyar Nemzeti Bank\'s official rates. ECB: the European Central Bank\'s reference rates. Manual: only the rates typed in. A rate typed in always goes before a downloaded one of the same day.'**
  String get rateSourceText;

  /// No description provided for @ratesAtStart.
  ///
  /// In en, this message translates to:
  /// **'Download at every start'**
  String get ratesAtStart;

  /// No description provided for @ratesAtStartText.
  ///
  /// In en, this message translates to:
  /// **'The missing rates, if there is a network'**
  String get ratesAtStartText;

  /// No description provided for @ratesDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading the rates…'**
  String get ratesDownloading;

  /// No description provided for @ratesDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The download failed: {error}'**
  String ratesDownloadFailed(String error);

  /// No description provided for @ratesDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded at {time}: {count, plural, =0{no new rate} =1{1 rate} other{{count} rates}}'**
  String ratesDownloaded(String time, int count);

  /// No description provided for @currentRates.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rates'**
  String get currentRates;

  /// No description provided for @noForeignCurrency.
  ///
  /// In en, this message translates to:
  /// **'Every account and invoice is in {code}.'**
  String noForeignCurrency(String code);

  /// No description provided for @missingRates.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate: {codes}'**
  String missingRates(String codes);

  /// No description provided for @manualRates.
  ///
  /// In en, this message translates to:
  /// **'Rates typed in'**
  String get manualRates;

  /// No description provided for @noManualRates.
  ///
  /// In en, this message translates to:
  /// **'None yet.'**
  String get noManualRates;

  /// No description provided for @newManualRate.
  ///
  /// In en, this message translates to:
  /// **'Manual rate'**
  String get newManualRate;

  /// No description provided for @manualRateValue.
  ///
  /// In en, this message translates to:
  /// **'Rate: 1 {code} = ? {main}'**
  String manualRateValue(String code, String main);

  /// No description provided for @manualRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Give a positive number'**
  String get manualRateInvalid;

  /// No description provided for @accountNotFound.
  ///
  /// In en, this message translates to:
  /// **'This account no longer exists.'**
  String get accountNotFound;

  /// No description provided for @noAccountEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries on this account yet. Add one with the + button.'**
  String get noAccountEntries;

  /// No description provided for @dayBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get dayBalance;

  /// No description provided for @entry.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get entry;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard the changes'**
  String get discardChanges;

  /// No description provided for @paysInvoice.
  ///
  /// In en, this message translates to:
  /// **'The payment of'**
  String get paysInvoice;

  /// No description provided for @bookedEntryText.
  ///
  /// In en, this message translates to:
  /// **'The payment of an invoice: it is changed on the invoice.'**
  String get bookedEntryText;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @openingBalanceHelper.
  ///
  /// In en, this message translates to:
  /// **'It becomes the account\'s opening entry; later it is changed or deleted there.'**
  String get openingBalanceHelper;

  /// No description provided for @openingDate.
  ///
  /// In en, this message translates to:
  /// **'Opening date'**
  String get openingDate;

  /// No description provided for @accountHasEntries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It has an entry (the opening one counts too): only an account without entries can be deleted.} other{It has {count} entries (the opening one counts too): only an account without entries can be deleted.}}'**
  String accountHasEntries(int count);

  /// No description provided for @openingEntry.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get openingEntry;

  /// No description provided for @newOpeningEntry.
  ///
  /// In en, this message translates to:
  /// **'Give the opening balance'**
  String get newOpeningEntry;

  /// No description provided for @openingAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Give an amount other than 0 (negative if overdrawn)'**
  String get openingAmountInvalid;

  /// No description provided for @mainCurrencyFixed.
  ///
  /// In en, this message translates to:
  /// **'Chosen when the user was made; it can\'t be changed.'**
  String get mainCurrencyFixed;

  /// No description provided for @rateManual.
  ///
  /// In en, this message translates to:
  /// **'typed in'**
  String get rateManual;

  /// No description provided for @noDownloadedRate.
  ///
  /// In en, this message translates to:
  /// **'no downloaded rate'**
  String get noDownloadedRate;

  /// No description provided for @useDownloadedRate.
  ///
  /// In en, this message translates to:
  /// **'Back to the downloaded rate'**
  String get useDownloadedRate;

  /// No description provided for @revaluation.
  ///
  /// In en, this message translates to:
  /// **'Revaluation difference'**
  String get revaluation;

  /// No description provided for @openingEntries.
  ///
  /// In en, this message translates to:
  /// **'Opening entries'**
  String get openingEntries;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @newTransfer.
  ///
  /// In en, this message translates to:
  /// **'New transfer'**
  String get newTransfer;

  /// No description provided for @editTransfer.
  ///
  /// In en, this message translates to:
  /// **'Edit transfer'**
  String get editTransfer;

  /// No description provided for @transferFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get transferFrom;

  /// No description provided for @transferTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get transferTo;

  /// No description provided for @transferReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get transferReceived;

  /// No description provided for @transferSameAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose another account'**
  String get transferSameAccount;

  /// No description provided for @transferRateMade.
  ///
  /// In en, this message translates to:
  /// **'1 {code} = {rate}: made from the two amounts'**
  String transferRateMade(String code, String rate);

  /// No description provided for @transferWorth.
  ///
  /// In en, this message translates to:
  /// **'Worth'**
  String get transferWorth;

  /// No description provided for @deleteTransferConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this transfer (both its sides)?'**
  String get deleteTransferConfirm;

  /// No description provided for @transferText.
  ///
  /// In en, this message translates to:
  /// **'Money moved between two of your accounts: no income or expense, the same worth on both sides.'**
  String get transferText;

  /// No description provided for @transferNotFound.
  ///
  /// In en, this message translates to:
  /// **'This transfer no longer exists.'**
  String get transferNotFound;

  /// No description provided for @transferToAccount.
  ///
  /// In en, this message translates to:
  /// **'To {name}'**
  String transferToAccount(String name);

  /// No description provided for @transferFromAccount.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String transferFromAccount(String name);

  /// No description provided for @switchUserConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch to {name}?'**
  String switchUserConfirm(String name);

  /// No description provided for @switchUserAction.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchUserAction;

  /// No description provided for @balanceAfterEntry.
  ///
  /// In en, this message translates to:
  /// **'Balance after it'**
  String get balanceAfterEntry;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get sort;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'The newest first'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'The oldest first'**
  String get sortOldest;

  /// No description provided for @sortLargest.
  ///
  /// In en, this message translates to:
  /// **'The largest amount first'**
  String get sortLargest;

  /// No description provided for @sortSmallest.
  ///
  /// In en, this message translates to:
  /// **'The smallest amount first'**
  String get sortSmallest;

  /// No description provided for @accountDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get accountDescription;

  /// No description provided for @bankAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account number or IBAN'**
  String get bankAccountNumber;

  /// No description provided for @bankAccountNumberHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional: 12345678-12345678-12345678 or HU42 1177 …'**
  String get bankAccountNumberHelper;

  /// No description provided for @bankAccountNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not a valid account number or IBAN'**
  String get bankAccountNumberInvalid;

  /// No description provided for @swiftCode.
  ///
  /// In en, this message translates to:
  /// **'SWIFT / BIC'**
  String get swiftCode;

  /// No description provided for @swiftCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'8 or 11 letters and digits, e.g. OTPVHUHB'**
  String get swiftCodeInvalid;

  /// No description provided for @accountClosed.
  ///
  /// In en, this message translates to:
  /// **'Account closed'**
  String get accountClosed;

  /// No description provided for @accountClosedText.
  ///
  /// In en, this message translates to:
  /// **'Its entries stay, no new ones can go on it'**
  String get accountClosedText;

  /// No description provided for @closedDate.
  ///
  /// In en, this message translates to:
  /// **'Closed on'**
  String get closedDate;

  /// No description provided for @closeAccountBalance.
  ///
  /// In en, this message translates to:
  /// **'Its balance is {balance} on that day: only a 0 balance can be closed (move the rest first).'**
  String closeAccountBalance(String balance);

  /// No description provided for @closeAccountLaterEntries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It has an entry after that day.} other{It has {count} entries after that day.}}'**
  String closeAccountLaterEntries(int count);

  /// No description provided for @closedOn.
  ///
  /// In en, this message translates to:
  /// **'Closed on {date}'**
  String closedOn(String date);

  /// No description provided for @closedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Closed accounts'**
  String get closedAccounts;

  /// No description provided for @previousPeriodValue.
  ///
  /// In en, this message translates to:
  /// **'previous: {amount}'**
  String previousPeriodValue(String amount);

  /// No description provided for @outgoingInvoices.
  ///
  /// In en, this message translates to:
  /// **'Outgoing invoices'**
  String get outgoingInvoices;

  /// No description provided for @revenueRecord.
  ///
  /// In en, this message translates to:
  /// **'Revenue record'**
  String get revenueRecord;

  /// No description provided for @outgoingInvoicesYear.
  ///
  /// In en, this message translates to:
  /// **'Outgoing invoices {year}'**
  String outgoingInvoicesYear(int year);

  /// No description provided for @incomingInvoicesYear.
  ///
  /// In en, this message translates to:
  /// **'Incoming invoices {year}'**
  String incomingInvoicesYear(int year);

  /// No description provided for @revenueRecordText.
  ///
  /// In en, this message translates to:
  /// **'A revenue counts on the day it is received, with the paid net amount of the outgoing invoice in forints. An invoice gets here when it is paid.'**
  String get revenueRecordText;

  /// No description provided for @revenueReceived.
  ///
  /// In en, this message translates to:
  /// **'Revenue received'**
  String get revenueReceived;

  /// No description provided for @noRevenue.
  ///
  /// In en, this message translates to:
  /// **'No revenue received in this year.'**
  String get noRevenue;

  /// No description provided for @cumulativeAmount.
  ///
  /// In en, this message translates to:
  /// **'Cumulative {amount}'**
  String cumulativeAmount(String amount);

  /// No description provided for @nextTaxPayment.
  ///
  /// In en, this message translates to:
  /// **'Next tax payment'**
  String get nextTaxPayment;

  /// No description provided for @latestInvoices.
  ///
  /// In en, this message translates to:
  /// **'Latest invoices'**
  String get latestInvoices;

  /// No description provided for @revenueOfYear.
  ///
  /// In en, this message translates to:
  /// **'Revenue {year}'**
  String revenueOfYear(int year);

  /// No description provided for @rateSourceOwnBank.
  ///
  /// In en, this message translates to:
  /// **'Own bank'**
  String get rateSourceOwnBank;

  /// No description provided for @rateSourceReported.
  ///
  /// In en, this message translates to:
  /// **'I chose it and reported it to NAV'**
  String get rateSourceReported;

  /// No description provided for @rateSourceBusinessText.
  ///
  /// In en, this message translates to:
  /// **'On an invoice in another currency the rate of your own credit institution is typed in (the default). The MNB\'s or the ECB\'s rate can be used only if you chose it and reported it to NAV. The choice is for the whole year: its rates are downloaded from 1 January.'**
  String get rateSourceBusinessText;

  /// No description provided for @rateSourceNotReported.
  ///
  /// In en, this message translates to:
  /// **'Not reported: your own bank\'s rate is typed in.'**
  String get rateSourceNotReported;

  /// No description provided for @rateDayFulfillment.
  ///
  /// In en, this message translates to:
  /// **'fulfillment'**
  String get rateDayFulfillment;

  /// No description provided for @rateDayIssue.
  ///
  /// In en, this message translates to:
  /// **'issue'**
  String get rateDayIssue;

  /// No description provided for @invoiceRateHelper.
  ///
  /// In en, this message translates to:
  /// **'HUF for 1 {code} · {source}, {date} ({day})'**
  String invoiceRateHelper(String code, String source, String date, String day);

  /// No description provided for @noOfficialRate.
  ///
  /// In en, this message translates to:
  /// **'No {source} rate of {date} yet'**
  String noOfficialRate(String source, String date);

  /// No description provided for @downloadingRates.
  ///
  /// In en, this message translates to:
  /// **'Downloading the rates…'**
  String get downloadingRates;

  /// No description provided for @rateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The download failed. Try again, or check the network.'**
  String get rateDownloadFailed;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @addPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get addPayment;

  /// No description provided for @noPayments.
  ///
  /// In en, this message translates to:
  /// **'Not paid yet.'**
  String get noPayments;

  /// No description provided for @paidOfGross.
  ///
  /// In en, this message translates to:
  /// **'Paid {paid} of {gross}'**
  String paidOfGross(String paid, String gross);

  /// No description provided for @wholeAmount.
  ///
  /// In en, this message translates to:
  /// **'the whole amount'**
  String get wholeAmount;

  /// No description provided for @paymentAtMost.
  ///
  /// In en, this message translates to:
  /// **'At most {amount}'**
  String paymentAtMost(String amount);

  /// No description provided for @paymentsTooMuch.
  ///
  /// In en, this message translates to:
  /// **'The payments add up to more than the invoice.'**
  String get paymentsTooMuch;

  /// No description provided for @deletePaymentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this payment?'**
  String get deletePaymentConfirm;

  /// No description provided for @openInvoice.
  ///
  /// In en, this message translates to:
  /// **'Open the invoice'**
  String get openInvoice;

  /// No description provided for @addRevenue.
  ///
  /// In en, this message translates to:
  /// **'New revenue'**
  String get addRevenue;

  /// No description provided for @chooseInvoiceText.
  ///
  /// In en, this message translates to:
  /// **'Record what came in on the bank account or in the till: choose its invoice, or record a new one.'**
  String get chooseInvoiceText;

  /// No description provided for @noOpenInvoices.
  ///
  /// In en, this message translates to:
  /// **'No open invoices.'**
  String get noOpenInvoices;

  /// No description provided for @paymentInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get paymentInvoice;

  /// No description provided for @chooseInvoice.
  ///
  /// In en, this message translates to:
  /// **'Which invoice was paid?'**
  String get chooseInvoice;

  /// No description provided for @reportMadeOn.
  ///
  /// In en, this message translates to:
  /// **'Made on {date}'**
  String reportMadeOn(String date);

  /// No description provided for @reportRecordNumber.
  ///
  /// In en, this message translates to:
  /// **'No.'**
  String get reportRecordNumber;

  /// No description provided for @reportDocument.
  ///
  /// In en, this message translates to:
  /// **'Document no.'**
  String get reportDocument;

  /// No description provided for @reportReceived.
  ///
  /// In en, this message translates to:
  /// **'Received on'**
  String get reportReceived;

  /// No description provided for @reportForeignAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount in currency'**
  String get reportForeignAmount;

  /// No description provided for @reportRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue (HUF)'**
  String get reportRevenue;

  /// No description provided for @reportCumulative.
  ///
  /// In en, this message translates to:
  /// **'Cumulative (HUF)'**
  String get reportCumulative;

  /// No description provided for @reportRevenueLimit.
  ///
  /// In en, this message translates to:
  /// **'Revenue limit {year}: {amount}'**
  String reportRevenueLimit(int year, String amount);

  /// No description provided for @reportRateNote.
  ///
  /// In en, this message translates to:
  /// **'A revenue in another currency counts at the rate of its invoice: of its fulfillment, or of its issue if that was earlier.'**
  String get reportRateNote;

  /// No description provided for @reportFileName.
  ///
  /// In en, this message translates to:
  /// **'revenue-record-{year}'**
  String reportFileName(int year);

  /// No description provided for @sendReport.
  ///
  /// In en, this message translates to:
  /// **'Send or save'**
  String get sendReport;

  /// No description provided for @sendAs.
  ///
  /// In en, this message translates to:
  /// **'Send as {format}'**
  String sendAs(String format);

  /// No description provided for @saveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as {format}'**
  String saveAs(String format);

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get fileSaved;

  /// No description provided for @reportError.
  ///
  /// In en, this message translates to:
  /// **'The file couldn\'t be made.'**
  String get reportError;

  /// No description provided for @reportReturnMonth.
  ///
  /// In en, this message translates to:
  /// **'Month of the return'**
  String get reportReturnMonth;

  /// No description provided for @cumulativeRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue so far this year'**
  String get cumulativeRevenue;

  /// No description provided for @taxesSoFar.
  ///
  /// In en, this message translates to:
  /// **'Taxes so far this year'**
  String get taxesSoFar;

  /// No description provided for @flatRateSummary.
  ///
  /// In en, this message translates to:
  /// **'Year summary'**
  String get flatRateSummary;

  /// No description provided for @taxesOfYear.
  ///
  /// In en, this message translates to:
  /// **'Taxes of the year'**
  String get taxesOfYear;

  /// No description provided for @quarters.
  ///
  /// In en, this message translates to:
  /// **'Quarters'**
  String get quarters;

  /// No description provided for @flatRateQuarterTitle.
  ///
  /// In en, this message translates to:
  /// **'Flat-rate tax {year} – Q{quarter}'**
  String flatRateQuarterTitle(int year, int quarter);

  /// No description provided for @flatRateSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Flat-rate tax {year} – year summary'**
  String flatRateSummaryTitle(int year);

  /// No description provided for @flatRateQuarterFile.
  ///
  /// In en, this message translates to:
  /// **'flat-rate-tax-{year}-q{quarter}'**
  String flatRateQuarterFile(int year, int quarter);

  /// No description provided for @flatRateSummaryFile.
  ///
  /// In en, this message translates to:
  /// **'flat-rate-tax-{year}-summary'**
  String flatRateSummaryFile(int year);

  /// No description provided for @reportItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get reportItem;

  /// No description provided for @reportBase.
  ///
  /// In en, this message translates to:
  /// **'Base (HUF)'**
  String get reportBase;

  /// No description provided for @reportAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (HUF)'**
  String get reportAmount;

  /// No description provided for @reportPayee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get reportPayee;

  /// No description provided for @reportTaxCode.
  ///
  /// In en, this message translates to:
  /// **'Tax code'**
  String get reportTaxCode;

  /// No description provided for @reportAccount.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get reportAccount;

  /// No description provided for @taxFreeIncome.
  ///
  /// In en, this message translates to:
  /// **'Tax-free income'**
  String get taxFreeIncome;

  /// No description provided for @deadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get deadlineLabel;

  /// No description provided for @flatRateCost.
  ///
  /// In en, this message translates to:
  /// **'Costs'**
  String get flatRateCost;

  /// No description provided for @costRatioHint.
  ///
  /// In en, this message translates to:
  /// **'{ratio}% cost ratio'**
  String costRatioHint(int ratio);

  /// No description provided for @taxFreePart.
  ///
  /// In en, this message translates to:
  /// **'Tax-free part'**
  String get taxFreePart;

  /// No description provided for @taxFreePartHint.
  ///
  /// In en, this message translates to:
  /// **'Half the minimum wage of the year: {amount}'**
  String taxFreePartHint(String amount);

  /// No description provided for @taxFreeRevenueNote.
  ///
  /// In en, this message translates to:
  /// **'No tax up to a revenue of {amount} (with this cost ratio).'**
  String taxFreeRevenueNote(String amount);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hu':
      return AppLocalizationsHu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
