// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'Fineva';

  @override
  String get tagline => 'Pénzügyeid rendben';

  @override
  String get accounts => 'Számlák';

  @override
  String get categories => 'Kategóriák';

  @override
  String get settings => 'Beállítások';

  @override
  String get entries => 'Tételek';

  @override
  String get balance => 'Egyenleg';

  @override
  String get income => 'Bevétel';

  @override
  String get expense => 'Kiadás';

  @override
  String get addEntry => 'Új tétel';

  @override
  String get editEntry => 'Tétel szerkesztése';

  @override
  String get amount => 'Összeg';

  @override
  String get amountInvalid => 'Adj meg nullánál nagyobb összeget';

  @override
  String get account => 'Számla';

  @override
  String get category => 'Kategória';

  @override
  String get noCategory => 'Nincs kategória';

  @override
  String get date => 'Dátum';

  @override
  String get note => 'Megjegyzés';

  @override
  String get save => 'Mentés';

  @override
  String get cancel => 'Mégse';

  @override
  String get delete => 'Törlés';

  @override
  String get saveError => 'A mentés nem sikerült';

  @override
  String get deleteError => 'A törlés nem sikerült';

  @override
  String get deleteEntryConfirm => 'Törlöd ezt a tételt?';

  @override
  String get noEntries => 'Még nincs tétel. A + gombbal adhatsz hozzá.';

  @override
  String get noAccounts =>
      'Bevételek és kiadások rögzítéséhez először adj hozzá egy számlát.';

  @override
  String get addAccount => 'Új számla';

  @override
  String get editAccount => 'Számla szerkesztése';

  @override
  String get name => 'Név';

  @override
  String get nameRequired => 'A név megadása kötelező';

  @override
  String get accountType => 'Típus';

  @override
  String get accountTypeCash => 'Készpénz';

  @override
  String get accountTypeBank => 'Bankszámla';

  @override
  String get accountTypeCard => 'Bankkártya';

  @override
  String get accountTypeSavings => 'Megtakarítás';

  @override
  String get currency => 'Pénznem';

  @override
  String currencyName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'HUF': 'forint',
      'EUR': 'euró',
      'USD': 'amerikai dollár',
      'GBP': 'angol font',
      'CHF': 'svájci frank',
      'CZK': 'cseh korona',
      'PLN': 'lengyel zloty',
      'RON': 'román lej',
      'SEK': 'svéd korona',
      'NOK': 'norvég korona',
      'DKK': 'dán korona',
      'ISK': 'izlandi korona',
      'TRY': 'török líra',
      'JPY': 'japán jen',
      'CNY': 'kínai jüan',
      'HKD': 'hongkongi dollár',
      'KRW': 'dél-koreai von',
      'SGD': 'szingapúri dollár',
      'INR': 'indiai rúpia',
      'IDR': 'indonéz rúpia',
      'MYR': 'maláj ringgit',
      'PHP': 'fülöp-szigeteki peso',
      'THB': 'thai baht',
      'ILS': 'izraeli sékel',
      'AUD': 'ausztrál dollár',
      'NZD': 'új-zélandi dollár',
      'CAD': 'kanadai dollár',
      'MXN': 'mexikói peso',
      'BRL': 'brazil reál',
      'ZAR': 'dél-afrikai rand',
      'other': '$code',
    });
    return '$_temp0';
  }

  @override
  String get initialBalance => 'Nyitó egyenleg';

  @override
  String get initialBalanceInvalid => 'Adj meg egy számot';

  @override
  String deleteAccountConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Törlöd ezt a számlát ($name) és a hozzá tartozó $count tételt?',
      zero: 'Törlöd ezt a számlát: $name?',
    );
    return '$_temp0';
  }

  @override
  String get addCategory => 'Új kategória';

  @override
  String get editCategory => 'Kategória szerkesztése';

  @override
  String get deleteCategoryConfirm =>
      'Törlöd ezt a kategóriát? A tételei megmaradnak, kategória nélkül.';

  @override
  String get color => 'Szín';

  @override
  String get language => 'Nyelv';

  @override
  String get theme => 'Téma';

  @override
  String get themeSystem => 'Az eszköz beállítása szerint';

  @override
  String get themeLight => 'Világos';

  @override
  String get themeDark => 'Sötét';

  @override
  String errorMessage(String message) {
    return 'Hiba történt: $message';
  }

  @override
  String loadError(String message) {
    return 'Az adatokat nem sikerült betölteni: $message';
  }

  @override
  String get welcomeTitle => 'Üdv a Finevában!';

  @override
  String get welcomeText => 'Állítsuk be néhány lépésben.';

  @override
  String get usageTitle => 'Mire használod a Finevát?';

  @override
  String get userTypePersonal => 'Egyéni pénzügyek';

  @override
  String get userTypePersonalText => 'Saját bevételeid, kiadásaid és számláid';

  @override
  String get userTypeSoleProprietor => 'Egyéni vállalkozói pénzügyek';

  @override
  String get userTypeSoleProprietorText =>
      'Vállalkozásod bevételei és kiadásai, az adózásodhoz igazítva';

  @override
  String get businessTitle => 'A vállalkozásod';

  @override
  String get taxRegime => 'Adózás';

  @override
  String get taxRegimeItemized => 'Vállalkozói SZJA (sima)';

  @override
  String get taxRegimeItemizedText => 'A tényleges, igazolt költségeid alapján';

  @override
  String get taxRegimeFlatRate => 'Átalányadó';

  @override
  String get taxRegimeFlatRateText =>
      'A bevételből a költséghányad levonásával';

  @override
  String get taxRegimeKata => 'KATA';

  @override
  String get taxRegimeKataText =>
      'Tételes havi adó, magánszemélyek felé értékesítéshez';

  @override
  String get vat => 'ÁFA';

  @override
  String get vatRegistered => 'Áfás';

  @override
  String get vatRegisteredText => 'Áfát számolsz fel és áfabevallást adsz be';

  @override
  String get vatExempt => 'Nem áfás (alanyi adómentes)';

  @override
  String get vatExemptText =>
      'Az éves bevételed az alanyi adómentesség határa alatt van';

  @override
  String get euReporting => 'Közösségi bevallás';

  @override
  String get euReportingText =>
      'Közösségi adószám, összesítő nyilatkozat az EU-s ügyletekről';

  @override
  String get back => 'Vissza';

  @override
  String get next => 'Tovább';

  @override
  String get getStarted => 'Kezdés';

  @override
  String get profile => 'Profil';

  @override
  String get dashboard => 'Áttekintés';

  @override
  String get latestEntries => 'Legutóbbi tételek';

  @override
  String get allEntries => 'Összes tétel';

  @override
  String get detailsTitle => 'Adataid';

  @override
  String get address => 'Cím';

  @override
  String get addressHint => '1234 Budapest, Fő utca 1.';

  @override
  String get taxId => 'Adóazonosító jel';

  @override
  String get taxIdHelper => '8-cal kezdődő 10 jegyű szám, az adókártyádon';

  @override
  String get taxIdInvalid => 'Érvénytelen adóazonosító jel';

  @override
  String get taxNumber => 'Adószám';

  @override
  String get taxNumberInvalid => 'Érvénytelen adószám (12345678-1-12)';

  @override
  String get statistics => 'Statisztika';

  @override
  String get newUser => 'Új felhasználó';

  @override
  String get newUserText =>
      'Fineva beállítása valaki másnak, saját számlákkal és tételekkel';

  @override
  String get deleteUser => 'Felhasználó törlése';

  @override
  String deleteUserConfirm(String name) {
    return 'Törlöd $name felhasználót az összes számlájával, tételével és kategóriájával együtt?';
  }

  @override
  String get switchUser => 'Felhasználóváltás';

  @override
  String get unnamedUser => 'Névtelen felhasználó';

  @override
  String get whoUses => 'Ki használja most a Finevát?';

  @override
  String get welcomeBackTitle => 'Üdv újra!';

  @override
  String get welcomeBackText =>
      'Válaszd ki a felhasználót, aztán nézd át az adatokat. A Kihagyás egyből továbbvisz.';

  @override
  String get skip => 'Kihagyás';

  @override
  String get onboardingAtStart => 'Bevezető minden indításkor';

  @override
  String get onboardingAtStartText =>
      'Indításkor felhasználóválasztás és az adatok átnézése';

  @override
  String get data => 'Adatok';

  @override
  String get backup => 'Adatok mentése';

  @override
  String get backupText => 'Minden felhasználó adatainak mentése egy fájlba';

  @override
  String get backupSaved => 'A mentés elkészült';

  @override
  String get backupError => 'A mentést nem sikerült elkészíteni';

  @override
  String get restore => 'Adatok visszatöltése';

  @override
  String get restoreText => 'Az összes adat cseréje egy mentésre';

  @override
  String get restoreConfirm =>
      'A visszatöltés minden felhasználó jelenlegi adatait lecseréli a mentésre. Folytatod?';

  @override
  String get restored => 'Az adatok visszatöltve';

  @override
  String get restoreInvalid => 'Ez a fájl nem Fineva-mentés';

  @override
  String get restoreNewer =>
      'Ezt a mentést a Fineva egy újabb változata készítette. Előbb frissítsd az alkalmazást.';

  @override
  String get restoreError => 'Az adatokat nem sikerült visszatölteni';

  @override
  String get summary => 'Összegzés';

  @override
  String get cashFlow => 'Pénzforgalom';

  @override
  String get netResult => 'Különbség';

  @override
  String get savingsRate => 'Megtakarítási ráta';

  @override
  String get closingBalance => 'Záró egyenleg';

  @override
  String get changeInPeriod => 'Változás az időszakban:';

  @override
  String categoryTotal(String amount) {
    return 'Összesen: $amount';
  }

  @override
  String get allTime => 'Teljes időszak';

  @override
  String get period => 'Időszak';

  @override
  String get choosePeriod => 'Időszak választása';

  @override
  String get periodWeek => 'Hét';

  @override
  String get periodMonth => 'Hónap';

  @override
  String get periodQuarter => 'Negyedév';

  @override
  String get periodYear => 'Év';

  @override
  String get periodCustom => 'Egyéni';

  @override
  String quarterOfYear(int quarter, int year) {
    return '$year. $quarter. negyedév';
  }

  @override
  String quarterOfYearShort(int quarter, int year) {
    return '$year. Q$quarter';
  }

  @override
  String get noEntriesInPeriod => 'Ebben az időszakban nincs tétel.';

  @override
  String allEntriesCount(int count) {
    return 'Összes ($count)';
  }

  @override
  String get previousPeriod => 'Előző';

  @override
  String get nextPeriod => 'Következő';

  @override
  String get euVatNumber => 'Közösségi adószám';

  @override
  String get euVatNumberHelper => 'HU és az adószámod első 8 számjegye';

  @override
  String get euVatNumberRequired =>
      'A közösségi bevalláshoz meg kell adnod a közösségi adószámot';

  @override
  String get euVatNumberInvalid => 'Érvénytelen közösségi adószám (HU12345678)';

  @override
  String get euVatNumberMismatch =>
      'Nem egyezik az adószámoddal: HU és az első 8 számjegye';

  @override
  String get taxNumberRequired =>
      'Egyéni vállalkozóként meg kell adnod a magyar adószámodat';

  @override
  String get taxNumberHelper => 'Az adószámod: 12345678-1-12';

  @override
  String get costRatio => 'Költséghányad';

  @override
  String get costRatioGeneral => 'Általános';

  @override
  String get costRatioListed => 'A törvényben felsorolt tevékenységek';

  @override
  String get costRatioRetail => 'Kiskereskedelem';

  @override
  String get mainOccupation => 'Főfoglalkozású';

  @override
  String get mainOccupationText =>
      'Nincs mellette legalább heti 36 órás munkaviszonyod: járulékminimumot fizetsz';

  @override
  String get vatPeriod => 'Áfabevallás';

  @override
  String get vatPeriodMonthly => 'Havi';

  @override
  String get vatPeriodQuarterly => 'Negyedéves';

  @override
  String get vatPeriodYearly => 'Éves';

  @override
  String get business => 'Vállalkozás';

  @override
  String get businessOnlyText => 'Csak egyéni vállalkozóknak.';

  @override
  String get businessIncompleteText =>
      'Hiányzik az adószámod. Töltsd ki a profilodat a vállalkozói nyilvántartáshoz.';

  @override
  String get invoices => 'Számlák';

  @override
  String get previousYear => 'Előző év';

  @override
  String get nextYear => 'Következő év';

  @override
  String get addInvoice => 'Új számla';

  @override
  String get editInvoice => 'Számla szerkesztése';

  @override
  String get deleteInvoiceConfirm => 'Törlöd ezt a számlát?';

  @override
  String get amountRequired => 'Adj meg egy összeget';

  @override
  String get invoiceOutgoing => 'Kimenő (bevétel)';

  @override
  String get invoiceIncoming => 'Bejövő (költség)';

  @override
  String get invoiceNumber => 'Bizonylat sorszáma';

  @override
  String get invoiceNumberRequired => 'Add meg a bizonylat sorszámát';

  @override
  String get paymentMethod => 'Fizetési mód';

  @override
  String get paymentTransfer => 'Átutalás';

  @override
  String get paymentCash => 'Készpénz';

  @override
  String get paymentCard => 'Bankkártya';

  @override
  String get invoiceDescription => 'Gazdasági esemény leírása';

  @override
  String get partner => 'Partner';

  @override
  String get partnerDomestic => 'Belföld';

  @override
  String get partnerEu => 'EU';

  @override
  String get partnerThirdCountry => 'Harmadik ország';

  @override
  String get partnerName => 'Partner neve';

  @override
  String get foreignTaxNumber => 'Külföldi adóazonosító';

  @override
  String get partnerEuVatNumberInvalid => 'Országkód és szám, pl. DE123456789';

  @override
  String get dates => 'Dátumok';

  @override
  String get issueDate => 'Kiállítás kelte';

  @override
  String get fulfillmentDate => 'Teljesítés';

  @override
  String get dueDate => 'Fizetési határidő';

  @override
  String get exchangeRate => 'Árfolyam';

  @override
  String exchangeRateHelper(String code) {
    return 'Ft / 1 $code';
  }

  @override
  String get exchangeRateInvalid => 'Add meg az árfolyamot';

  @override
  String get vatCode => 'Áfa';

  @override
  String get netAmount => 'Nettó';

  @override
  String get vatAmount => 'Áfa';

  @override
  String get grossAmount => 'Bruttó';

  @override
  String reverseChargeText(int rate) {
    return 'Fordított adózás: a $rate% áfát te fizeted, és ha áfás vagy, le is vonod.';
  }

  @override
  String get paid => 'Kiegyenlítve';

  @override
  String get paidRevenueText =>
      'Az átalányadós bevétel a kiegyenlítéskor számít';

  @override
  String get paidCostText => 'Mikor fizetted ki';

  @override
  String get paidDate => 'Kiegyenlítés napja';

  @override
  String get paidAmount => 'Kiegyenlített összeg';

  @override
  String get vatCode27 => '27% áfa';

  @override
  String get vatCode18 => '18% áfa';

  @override
  String get vatCode5 => '5% áfa';

  @override
  String get vatCode0 => '0% áfa';

  @override
  String get vatCodeAam => 'AAM – alanyi adómentes';

  @override
  String get vatCodeTam => 'TAM – tárgyi adómentes';

  @override
  String get vatCodeAtk => 'ATK – az áfa tárgyi hatályán kívül';

  @override
  String get vatCodeFad => 'FAD – belföldi fordított adózás';

  @override
  String get vatCodeKbaet =>
      'KBAET – közösségen belüli adómentes termékértékesítés';

  @override
  String get vatCodeEufad37 =>
      'EUFAD37 – szolgáltatás EU-s vállalkozásnak (fordított adózás)';

  @override
  String get vatCodeEufade =>
      'EUFADE – egyéb fordítottan adózó ügylet másik tagállamban';

  @override
  String get vatCodeEue =>
      'EUE – másik tagállamban teljesített, nem fordítottan adózó ügylet';

  @override
  String get vatCodeEuGoods =>
      'Közösségen belüli termékbeszerzés (fordított adózás)';

  @override
  String get vatCodeEuServices =>
      'EU-ból igénybe vett szolgáltatás (fordított adózás)';

  @override
  String get vatCodeEam => 'EAM – termékexport, adómentes';

  @override
  String get vatCodeHo => 'HO – harmadik országban teljesített ügylet';

  @override
  String get vatCodeNam => 'NAM – egyéb nemzetközi adómentesség';

  @override
  String get vatCodeImportServices =>
      'Harmadik országból igénybe vett szolgáltatás (fordított adózás)';

  @override
  String get vatCodeImportGoods => 'Termékimport (fordított adózás)';

  @override
  String incomeRecord(int year) {
    return 'Bevételi nyilvántartás $year';
  }

  @override
  String costRecord(int year) {
    return 'Költségnyilvántartás $year';
  }

  @override
  String get grossTotal => 'Bruttó összesen';

  @override
  String get openTotal => 'Nyitott';

  @override
  String get flatRateRevenue => 'Átalányadós bevétel (kiegyenlített, nettó)';

  @override
  String get kataRevenue => 'KATA bevétel';

  @override
  String kataTaxText(String amount) {
    return 'KATA: havi $amount';
  }

  @override
  String get noInvoices => 'Ebben az évben nincs számla.';

  @override
  String openAmount(String amount) {
    return '$amount nyitott';
  }

  @override
  String flatRateYear(int year) {
    return 'Átalányadózás $year';
  }

  @override
  String get flatRateOverLimit =>
      'Túllépted a bevételi határt: kiesel az átalányadózás alól.';

  @override
  String get taxFreeRevenue => 'Adómentes bevételi küszöb';

  @override
  String taxFreeRevenueHint(String income, int ratio) {
    return '$income adómentes jövedelem $ratio% költséghányaddal';
  }

  @override
  String get yearlyTaxes => 'Éves adók összesen';

  @override
  String taxYearUnknown(int year, int known) {
    return 'A $year. év adatai még nincsenek meg, a $known. éviekkel számol.';
  }

  @override
  String quarterName(int quarter) {
    return '$quarter. negyedév';
  }

  @override
  String deadline(String date) {
    return 'Határidő: $date';
  }

  @override
  String get revenue => 'Bevétel';

  @override
  String get flatRateIncome => 'Jövedelem';

  @override
  String get taxableIncome => 'Adóköteles jövedelem';

  @override
  String taxFreeIncomeHint(String amount) {
    return 'Adómentes: $amount';
  }

  @override
  String get szja => 'SZJA (15%)';

  @override
  String get tbContribution => 'TB-járulék (18,5%)';

  @override
  String get szocho => 'Szociális hozzájárulási adó (13%)';

  @override
  String get localTax => 'Helyi iparűzési adó';

  @override
  String get chamberFee => 'Kamarai hozzájárulás';

  @override
  String get total => 'Összesen';

  @override
  String baseHint(String amount) {
    return 'Alap: $amount';
  }

  @override
  String get toTransfer => 'Utalandó';

  @override
  String taxCode(String code) {
    return 'Adónem $code';
  }

  @override
  String get municipalityAccount => 'az önkormányzat számlájára';

  @override
  String get taxKindSzja => 'NAV Személyi jövedelemadó';

  @override
  String get taxKindSzocho => 'NAV Szociális hozzájárulási adó';

  @override
  String get taxKindTb => 'NAV Társadalombiztosítási járulék';

  @override
  String get taxKindLocalTax => 'Helyi iparűzési adó';

  @override
  String get taxKindChamberFee => 'Magyar Kereskedelmi és Iparkamara';

  @override
  String get copyAccount => 'Számlaszám másolása';

  @override
  String copied(String text) {
    return 'Másolva: $text';
  }

  @override
  String get vatPayable => 'Fizetendő áfa';

  @override
  String get vatDeductible => 'Levonható áfa';

  @override
  String get reverseCharge => 'Fordított adózás';

  @override
  String get vatTotalRounded => 'Összesen (ezerre kerekítve)';

  @override
  String get vatExemptReverseChargeText =>
      'Alanyi adómentesként a fordított adózású beszerzések áfáját levonás nélkül fizeted.';

  @override
  String get vatToPay => 'Egyenleg: fizetendő';

  @override
  String get vatToReclaim => 'Egyenleg: visszaigényelhető / továbbvihető';

  @override
  String get salesWithoutVat => 'Áfa nélküli értékesítés';

  @override
  String vatDateRuleText(int days) {
    return 'Áfa napja szerint: a kimenő számla a kiegyenlítés napján számít, ha a teljesítéstől $days napon belül fizették, egyébként a teljesítés + $days napon; a bejövő a teljesítés napján.';
  }

  @override
  String vatDateLine(String date, int days) {
    return 'Áfa napja: $date (a kiegyenlítés napja, ha a teljesítéstől $days napon belül volt, egyébként teljesítés + $days nap)';
  }

  @override
  String get taxTreatment => 'Vállalkozói adózás';

  @override
  String get taxTreatmentNone => 'Nem vállalkozói tétel';

  @override
  String get taxTreatmentRevenue => 'Adóalapba számító bevétel';

  @override
  String get taxTreatmentNonTaxableIncome => 'Adóalapba nem számító bevétel';

  @override
  String get taxTreatmentWithdrawal => 'Költség: vállalkozói kivét (bruttó)';

  @override
  String get taxTreatmentSzocho => 'Költség: SZOCHO';

  @override
  String get taxTreatmentOtherCost => 'Költség: egyéb kiadás';

  @override
  String get taxTreatmentMaterialCost => 'Költség: anyagköltség';

  @override
  String get taxTreatmentBankCost => 'Költség: bankköltség';

  @override
  String get taxTreatmentAccountingCost => 'Költség: könyvelés';

  @override
  String get taxTreatmentItCost => 'Költség: informatika';

  @override
  String get taxTreatmentNonDeductible => 'Adóalapba nem számító kiadás';

  @override
  String get taxTreatmentVat => 'ÁFA (nem költség)';

  @override
  String entryExchangeRateHelper(String main, String code) {
    return '$main / 1 $code aznap';
  }

  @override
  String get itemizedTab => 'Vállalkozói SZJA';

  @override
  String get assets => 'Eszközök';

  @override
  String get itemizedSetupTitle => 'Vállalkozói kategóriák';

  @override
  String get itemizedSetupText =>
      'A vállalkozói SZJA azoknak a kategóriáknak a tételeiből számol, amelyeknek van vállalkozói adózása. Add hozzá a pénzforgalmi nyilvántartás kategóriáit (adóalapba számító bevétel, vállalkozói kivét, költségek, …), vagy állítsd be a saját kategóriáidét.';

  @override
  String get addBusinessCategories => 'Vállalkozói kategóriák hozzáadása';

  @override
  String missingExchangeRates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devizás tételnek nincs árfolyama: kimarad a számításból.',
    );
    return '$_temp0';
  }

  @override
  String itemizedYear(int year) {
    return 'Vállalkozói SZJA $year';
  }

  @override
  String get taxableRevenue => 'Adóalapba számító bevétel';

  @override
  String get costs => 'Költségek';

  @override
  String depreciationHint(String amount) {
    return 'Benne értékcsökkenés: $amount';
  }

  @override
  String get taxBase => 'Adóalap';

  @override
  String get vszja => 'Vállalkozói SZJA (9%)';

  @override
  String get dividendBase => 'Vállalkozói osztalékalap';

  @override
  String get dividendSzja => 'SZJA az osztalékalap után (15%)';

  @override
  String get szochoOnDividend => 'SZOCHO az osztalékalap után, év végén';

  @override
  String szochoCapHint(String cap, String paid) {
    return 'Legfeljebb $cap, ebből a kivét után fizetve $paid';
  }

  @override
  String get byTreatment => 'Vállalkozói kategóriák szerint';

  @override
  String get depreciation => 'Értékcsökkenés';

  @override
  String get lossCarried => 'Előző negyedév vesztesége';

  @override
  String depreciationOfYear(String amount) {
    return 'Éves értékcsökkenés: $amount';
  }

  @override
  String get addAsset => 'Új eszköz';

  @override
  String get editAsset => 'Eszköz szerkesztése';

  @override
  String get noAssets => 'Még nincs eszköz.';

  @override
  String assetRemaining(String amount) {
    return 'Maradvány: $amount';
  }

  @override
  String get deleteAssetConfirm => 'Törlöd ezt az eszközt?';

  @override
  String get purchaseDate => 'Üzembe helyezés';

  @override
  String get supplier => 'Szállító';

  @override
  String get assetCost => 'Beszerzési érték';

  @override
  String get depreciationRate => 'Éves értékcsökkenési kulcs';

  @override
  String get depreciationRateHelper =>
      'Pl. számítógép 33, egyéb gép 14,5; 100 = kisértékű eszköz egy összegben';

  @override
  String get depreciationRateInvalid => '0 és 100 közötti kulcs';

  @override
  String get vatPeriodBalance => 'Az időszak egyenlege';

  @override
  String get vatCarriedIn => 'Előző időszakról áthozott';

  @override
  String get searchEntries => 'Megjegyzés, kategória, számla, összeg';

  @override
  String get clearSearch => 'Keresés törlése';

  @override
  String get filterType => 'Típus';

  @override
  String get filterAll => 'Mind';

  @override
  String get clearFilters => 'Szűrők törlése';

  @override
  String get noMatchingEntries =>
      'Nincs a keresésnek és a szűrőknek megfelelő tétel.';

  @override
  String entryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tétel',
    );
    return '$_temp0';
  }

  @override
  String get icon => 'Ikon';

  @override
  String balanceAt(String date) {
    return 'Egyenleg: $date';
  }

  @override
  String get search => 'Keresés';

  @override
  String get filters => 'Szűrők';

  @override
  String get removeFilter => 'Szűrő törlése';

  @override
  String get done => 'Kész';

  @override
  String get userTypeFixed =>
      'A felhasználó típusa a létrehozása után nem változtatható.';

  @override
  String get bookingText =>
      'A kiegyenlítés tételként kerül a számlára, így megjelenik a tételek és az egyenlegek között.';

  @override
  String get bookedOn => 'Könyvelés számlára';

  @override
  String get notBooked => 'Nincs könyvelve';

  @override
  String get paidExchangeRate => 'Árfolyam a kiegyenlítéskor';

  @override
  String get paidExchangeRateHelper => 'Üresen: a számla árfolyama';

  @override
  String get openInvoices => 'Nyitott számlák';

  @override
  String get receivables => 'Követelés';

  @override
  String get payables => 'Tartozás';

  @override
  String get exchangeRates => 'Árfolyamok';

  @override
  String get exchangeRatesText => 'Fő pénznem, forrás, kézi árfolyamok';

  @override
  String get updateRates => 'Árfolyamok letöltése most';

  @override
  String get mainCurrency => 'Fő pénznem';

  @override
  String get mainCurrencyText =>
      'Az áttekintés és a statisztika mindent ebben mutat. Később nem módosítható.';

  @override
  String get mainCurrencySoleProprietor =>
      'Egyéni vállalkozónál mindig forint: az adózás forintban megy.';

  @override
  String get rateSource => 'Árfolyamforrás';

  @override
  String get rateSourceMnb => 'MNB';

  @override
  String get rateSourceEcb => 'EKB';

  @override
  String get rateSourceManual => 'Kézi';

  @override
  String get rateSourceText =>
      'MNB: a Magyar Nemzeti Bank hivatalos árfolyama. EKB: az Európai Központi Bank referencia-árfolyama. Kézi: csak a megadott árfolyamok. A kézzel megadott árfolyam az adott napon mindig a letöltött előtt jár.';

  @override
  String get ratesAtStart => 'Letöltés minden induláskor';

  @override
  String get ratesAtStartText => 'A hiányzó árfolyamok, ha van hálózat';

  @override
  String get ratesDownloading => 'Árfolyamok letöltése…';

  @override
  String ratesDownloadFailed(String error) {
    return 'A letöltés nem sikerült: $error';
  }

  @override
  String ratesDownloaded(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count árfolyam',
      zero: 'nincs új árfolyam',
    );
    return 'Letöltve $time-kor: $_temp0';
  }

  @override
  String get currentRates => 'Mai árfolyamok';

  @override
  String noForeignCurrency(String code) {
    return 'Minden számla és bizonylat $code pénznemű.';
  }

  @override
  String missingRates(String codes) {
    return 'Nincs árfolyam: $codes';
  }

  @override
  String get manualRates => 'Kézi árfolyamok';

  @override
  String get noManualRates => 'Még nincs.';

  @override
  String get newManualRate => 'Kézi árfolyam';

  @override
  String manualRateValue(String code, String main) {
    return 'Árfolyam: 1 $code = ? $main';
  }

  @override
  String get manualRateInvalid => 'Pozitív számot adj meg';

  @override
  String get accountNotFound => 'Ez a számla már nincs meg.';

  @override
  String get noAccountEntries =>
      'Ezen a számlán még nincs tétel. A + gombbal adhatsz hozzá.';

  @override
  String get dayBalance => 'Egyenleg';

  @override
  String get entry => 'Tétel';

  @override
  String get edit => 'Szerkesztés';

  @override
  String get discardChanges => 'A változások elvetése';

  @override
  String get paysInvoice => 'Ennek a kifizetése';

  @override
  String get bookedEntryText =>
      'Egy bizonylat kifizetése: a bizonylatnál módosítható.';

  @override
  String get close => 'Bezárás';

  @override
  String get openingBalanceHelper =>
      'A számla nyitó tétele lesz; később ott módosítható vagy törölhető.';

  @override
  String get openingDate => 'Nyitás dátuma';

  @override
  String accountHasEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tétel van rajta (a nyitó tétel is annak számít): csak tétel nélküli számla törölhető.',
    );
    return '$_temp0';
  }

  @override
  String get openingEntry => 'Nyitó egyenleg';

  @override
  String get newOpeningEntry => 'Nyitó egyenleg megadása';

  @override
  String get openingAmountInvalid =>
      '0-tól eltérő összeget adj meg (negatívat, ha mínuszban van)';

  @override
  String get mainCurrencyFixed =>
      'A felhasználó létrehozásakor választottad; nem módosítható.';

  @override
  String get rateManual => 'kézi';

  @override
  String get noDownloadedRate => 'nincs letöltött árfolyam';

  @override
  String get useDownloadedRate => 'Vissza a letöltött árfolyamra';

  @override
  String get revaluation => 'Átértékelési különbözet';

  @override
  String get openingEntries => 'Nyitó tételek';

  @override
  String get transfer => 'Átvezetés';

  @override
  String get newTransfer => 'Új átvezetés';

  @override
  String get editTransfer => 'Átvezetés szerkesztése';

  @override
  String get transferFrom => 'Honnan';

  @override
  String get transferTo => 'Hová';

  @override
  String get transferReceived => 'Jóváírt összeg';

  @override
  String get transferSameAccount => 'Másik számlát válassz';

  @override
  String transferRateMade(String code, String rate) {
    return '1 $code = $rate: a két összegből';
  }

  @override
  String get transferWorth => 'Érték';

  @override
  String get deleteTransferConfirm =>
      'Törlöd ezt az átvezetést (mindkét oldalát)?';

  @override
  String get transferText =>
      'Pénz két saját számlád között: se bevétel, se kiadás, a két oldal ugyanannyit ér.';

  @override
  String get transferNotFound => 'Ez az átvezetés már nincs meg.';

  @override
  String transferToAccount(String name) {
    return 'Ide: $name';
  }

  @override
  String transferFromAccount(String name) {
    return 'Innen: $name';
  }

  @override
  String switchUserConfirm(String name) {
    return 'Biztos, hogy átváltasz erre a felhasználóra: $name?';
  }

  @override
  String get switchUserAction => 'Átváltás';

  @override
  String get balanceAfterEntry => 'Egyenleg a tétel után';

  @override
  String get sort => 'Rendezés';

  @override
  String get sortNewest => 'Legújabb elöl';

  @override
  String get sortOldest => 'Legrégebbi elöl';

  @override
  String get sortLargest => 'Legnagyobb összeg elöl';

  @override
  String get sortSmallest => 'Legkisebb összeg elöl';

  @override
  String get accountDescription => 'Leírás';

  @override
  String get bankAccountNumber => 'Számlaszám vagy IBAN';

  @override
  String get bankAccountNumberHelper =>
      'Nem kötelező: 12345678-12345678-12345678 vagy HU42 1177 …';

  @override
  String get bankAccountNumberInvalid => 'Nem érvényes számlaszám vagy IBAN';

  @override
  String get swiftCode => 'SWIFT / BIC';

  @override
  String get swiftCodeInvalid => '8 vagy 11 betű és szám, pl. OTPVHUHB';

  @override
  String get accountClosed => 'Számla lezárva';

  @override
  String get accountClosedText => 'A tételei megmaradnak, új nem kerülhet rá';

  @override
  String get closedDate => 'Lezárás napja';

  @override
  String closeAccountBalance(String balance) {
    return 'Az egyenlege aznap $balance: csak 0 egyenlegű számla zárható le (előbb vezesd át a maradékot).';
  }

  @override
  String closeAccountLaterEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tétele van a nap után.',
    );
    return '$_temp0';
  }

  @override
  String closedOn(String date) {
    return 'Lezárva: $date';
  }

  @override
  String get closedAccounts => 'Lezárt számlák';

  @override
  String previousPeriodValue(String amount) {
    return 'előző: $amount';
  }

  @override
  String get outgoingInvoices => 'Kimenő számlák';

  @override
  String get revenueRecord => 'Bevételi nyilvántartás';

  @override
  String outgoingInvoicesYear(int year) {
    return 'Kimenő számlák $year';
  }

  @override
  String incomingInvoicesYear(int year) {
    return 'Bejövő számlák $year';
  }

  @override
  String get revenueRecordText =>
      'A bevétel a befolyás napján számít, a kimenő számla kiegyenlített nettó összegével, forintban. A számla a kiegyenlítésével kerül ide.';

  @override
  String get revenueReceived => 'Befolyt bevétel';

  @override
  String get noRevenue => 'Ebben az évben nincs befolyt bevétel.';

  @override
  String cumulativeAmount(String amount) {
    return 'Halmozott: $amount';
  }

  @override
  String get nextTaxPayment => 'Következő adófizetés';

  @override
  String get latestInvoices => 'Legutóbbi számlák';

  @override
  String revenueOfYear(int year) {
    return '$year. évi bevétel';
  }

  @override
  String get rateSourceOwnBank => 'Saját hitelintézet';

  @override
  String get rateSourceReported =>
      'Ezt választottam, és bejelentettem a NAV-nak';

  @override
  String get rateSourceBusinessText =>
      'A más pénznemű számlán a saját hitelintézeted árfolyamát adod meg (ez az alapeset). Az MNB vagy az EKB árfolyama csak akkor használható, ha ezt választottad, és bejelentetted a NAV-nak. A választás egész évre szól: az árfolyamait január 1-jétől tölti le a program.';

  @override
  String get rateSourceNotReported =>
      'Bejelentés nélkül a saját hitelintézeted árfolyamát adod meg.';

  @override
  String get rateDayFulfillment => 'teljesítés';

  @override
  String get rateDayIssue => 'kiállítás';

  @override
  String invoiceRateHelper(
    String code,
    String source,
    String date,
    String day,
  ) {
    return 'Ft / 1 $code · $source, $date ($day)';
  }

  @override
  String noOfficialRate(String source, String date) {
    return 'Még nincs $source-árfolyam: $date';
  }

  @override
  String get downloadingRates => 'Árfolyamok letöltése…';

  @override
  String get rateDownloadFailed =>
      'A letöltés nem sikerült. Próbáld újra, vagy nézd meg a hálózatot.';

  @override
  String get payments => 'Kiegyenlítések';

  @override
  String get addPayment => 'Kiegyenlítés';

  @override
  String get noPayments => 'Még nincs kiegyenlítés.';

  @override
  String paidOfGross(String paid, String gross) {
    return 'Kiegyenlítve $paid / $gross';
  }

  @override
  String get wholeAmount => 'a teljes összeg';

  @override
  String paymentAtMost(String amount) {
    return 'Legfeljebb $amount';
  }

  @override
  String get paymentsTooMuch =>
      'A kiegyenlítések többet tesznek ki, mint a számla.';

  @override
  String get deletePaymentConfirm => 'Törlöd ezt a kiegyenlítést?';

  @override
  String get openInvoice => 'Számla megnyitása';

  @override
  String get addRevenue => 'Új bevétel';

  @override
  String get chooseInvoiceText =>
      'Rögzítsd, ami a bankszámlára vagy a pénztárba befolyt: válaszd ki a számláját, vagy rögzíts újat.';

  @override
  String get noOpenInvoices => 'Nincs nyitott számla.';

  @override
  String get paymentInvoice => 'Számla';

  @override
  String get chooseInvoice => 'Melyik számlát fizették?';

  @override
  String reportMadeOn(String date) {
    return 'Készült: $date';
  }

  @override
  String get reportRecordNumber => 'Sorszám';

  @override
  String get reportDocument => 'Bizonylat sorszáma';

  @override
  String get reportReceived => 'Befolyás napja';

  @override
  String get reportForeignAmount => 'Devizaösszeg';

  @override
  String get reportRevenue => 'Bevétel (Ft)';

  @override
  String get reportCumulative => 'Halmozott (Ft)';

  @override
  String reportRevenueLimit(int year, String amount) {
    return 'Bevételi határ $year: $amount';
  }

  @override
  String get reportRateNote =>
      'A devizás bevétel a számlája árfolyamán számít: a teljesítés napjáén, vagy a kiállításén, ha az korábbi.';

  @override
  String reportFileName(int year) {
    return 'beveteli-nyilvantartas-$year';
  }

  @override
  String get sendReport => 'Küldés vagy mentés';

  @override
  String sendAs(String format) {
    return 'Küldés $format formátumban';
  }

  @override
  String saveAs(String format) {
    return 'Mentés $format formátumban';
  }

  @override
  String get fileSaved => 'Elmentve.';

  @override
  String get reportError => 'A fájl elkészítése nem sikerült.';

  @override
  String get reportReturnMonth => 'Bevallás hónapja';

  @override
  String get cumulativeRevenue => 'Bevétel az év elejétől';

  @override
  String get taxesSoFar => 'Adók az év elejétől';

  @override
  String get flatRateSummary => 'Éves összesítő';

  @override
  String get taxesOfYear => 'Az év adói';

  @override
  String get quarters => 'Negyedévek';

  @override
  String flatRateQuarterTitle(int year, int quarter) {
    return 'Átalányadó $year – $quarter. negyedév';
  }

  @override
  String flatRateSummaryTitle(int year) {
    return 'Átalányadó $year – éves összesítő';
  }

  @override
  String flatRateQuarterFile(int year, int quarter) {
    return 'atalanyado-$year-$quarter-negyedev';
  }

  @override
  String flatRateSummaryFile(int year) {
    return 'atalanyado-$year-osszesito';
  }

  @override
  String get reportItem => 'Megnevezés';

  @override
  String get reportBase => 'Alap (Ft)';

  @override
  String get reportAmount => 'Összeg (Ft)';

  @override
  String get reportPayee => 'Kedvezményezett';

  @override
  String get reportTaxCode => 'Adónem';

  @override
  String get reportAccount => 'Bankszámlaszám';

  @override
  String get taxFreeIncome => 'Adómentes jövedelem';

  @override
  String get deadlineLabel => 'Határidő';

  @override
  String get flatRateCost => 'Költség';

  @override
  String costRatioHint(int ratio) {
    return '$ratio% költséghányad';
  }

  @override
  String get taxFreePart => 'Adómentes rész';

  @override
  String taxFreePartHint(String amount) {
    return 'Az éves minimálbér fele: $amount';
  }

  @override
  String taxFreeRevenueNote(String amount) {
    return '$amount bevételig nincs adó (ezzel a költséghányaddal).';
  }
}
