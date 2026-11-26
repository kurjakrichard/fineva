import 'package:fineva/data/data_export.dart';
import 'package:fineva/providers/providers.dart';
import 'package:fineva/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_database.dart';

void main() {
  late TestDatabase testDb;
  late ProviderContainer container;

  setUp(() async {
    testDb = await TestDatabase.create();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        financeDatasourceProvider.overrideWithValue(testDb.datasource),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  FinanceNotifier notifier() => container.read(financeProvider.notifier);
  FinanceState state() => container.read(financeProvider);
  tearDown(() async {
    container.dispose();
    await testDb.dispose();
  });

  test(
    'saving an account and entries updates the state and balances',
    () async {
      final notifier = container.read(financeProvider.notifier);
      await notifier.load();
      expect(container.read(financeProvider).loaded, isTrue);
      await notifier.saveProfile(const Profile(name: 'Kiss Anna'));
      expect(container.read(financeProvider).categories, isNotEmpty);

      // A new account with its opening entry.
      expect(
        await notifier.saveAccount(
          const Account(name: 'Wallet'),
          opening: 1000,
          openingDate: DateTime(2026, 11),
        ),
        isTrue,
      );
      final account = container.read(financeProvider).accounts.single;
      final opening = container.read(financeProvider).entries.single;
      expect(opening.opening, isTrue);
      expect(opening.signedAmount, 1000);
      expect(opening.date, DateTime(2026, 11));
      expect(opening.categoryId, isNull);

      await notifier.saveEntry(
        Entry(
          accountId: account.id!,
          type: EntryType.expense,
          amount: 300,
          date: DateTime(2026, 11, 22),
        ),
      );
      await notifier.saveEntry(
        Entry(
          accountId: account.id!,
          type: EntryType.income,
          amount: 50,
          date: DateTime(2026, 11, 23),
        ),
      );

      final state = container.read(financeProvider);
      // The newest first.
      expect(state.entries.map((e) => e.amount), [50, 300, 1000]);
      expect(state.balanceOf(account), 750);
      expect(
        state.totalInMain(state.balances, DateTime(2026, 11, 23)).total,
        750,
      );

      expect(await notifier.deleteEntry(state.entries.first), isTrue);
      expect(container.read(financeProvider).balanceOf(account), 700);

      // Only an account without entries is deleted, the opening one counts.
      expect(await notifier.deleteAccount(account), isFalse);
      expect(container.read(financeProvider).accounts, hasLength(1));
      for (final entry in container.read(financeProvider).entries) {
        await notifier.deleteEntry(entry);
      }
      expect(await notifier.deleteAccount(account), isTrue);
      expect(container.read(financeProvider).accounts, isEmpty);
    },
  );

  test('no user until the onboarding saves one', () async {
    await notifier().load();
    expect(state().loaded, isTrue);
    expect(state().profile, isNull);
    expect(state().profiles, isEmpty);

    const profile = Profile(
      name: 'Kiss Anna',
      userType: UserType.soleProprietor,
      taxRegime: TaxRegime.itemized,
    );
    expect(await notifier().saveProfile(profile), isTrue);
    final saved = state().profile;
    expect(saved!.id, isNotNull);
    expect(saved.taxRegime, TaxRegime.itemized);

    // Saving the loaded profile updates it.
    expect(
      await notifier().saveProfile(
        saved.copyWith(vatStatus: VatStatus.registered),
      ),
      isTrue,
    );
    expect(state().profiles, hasLength(1));
    expect(state().profile!.vatStatus, VatStatus.registered);
  });

  test('every user has their own data; a new user becomes current', () async {
    await notifier().load();
    await notifier().saveProfile(const Profile(name: 'Anna'));
    final anna = state().profile!;
    await notifier().saveAccount(const Account(name: "Anna's wallet"));
    expect(state().accounts.single.userId, anna.id);

    await notifier().saveProfile(const Profile(name: 'Béla'));
    final bela = state().profile!;
    expect(bela.name, 'Béla');
    expect(state().profiles.map((p) => p.name), ['Anna', 'Béla']);
    expect(state().accounts, isEmpty);
    expect(
      state().categories,
      hasLength(BuiltInCategories.current.ofSet(BuiltInSet.personal).length),
    );
    // A personal user sees the personal ones only.
    expect(
      state().visibleCategories.map((c) => c.systemKey),
      unorderedEquals(
        BuiltInCategories.current
            .ofSet(BuiltInSet.personal)
            .map((c) => c.systemKey),
      ),
    );

    // Editing another user doesn't switch to them, unless asked to.
    await notifier().saveProfile(anna.copyWith(address: 'Budapest'));
    expect(state().profile!.id, bela.id);
    await notifier().saveProfile(anna, select: true);
    expect(state().profile!.id, anna.id);
    expect(state().accounts.single.name, "Anna's wallet");

    await notifier().selectProfile(bela);
    expect(state().profile!.id, bela.id);

    // Deleting the current user switches to the first one left.
    expect(await notifier().deleteProfile(bela), isTrue);
    expect(state().profiles.map((p) => p.name), ['Anna']);
    expect(state().profile!.id, anna.id);
  });

  test("invoices are saved as the current user's", () async {
    await notifier().load();
    await notifier().saveProfile(
      const Profile(name: 'EV', userType: UserType.soleProprietor),
    );
    final user = state().profile!;
    expect(
      await notifier().saveInvoice(
        Invoice(
          direction: InvoiceDirection.incoming,
          number: 'B-1',
          issueDate: DateTime(2026, 5, 2),
          fulfillmentDate: DateTime(2026, 5, 2),
          netAmount: 10000,
          vatCode: VatCode.vat27,
          vatAmount: 2700,
        ),
      ),
      isTrue,
    );
    expect(state().invoices.single.userId, user.id);
    expect(state().invoices.single.gross, 12700);

    // Another user doesn't see it.
    await notifier().saveProfile(const Profile(name: 'Más'));
    expect(state().invoices, isEmpty);
  });

  test(
    'itemized taxation: business categories, assets, exchange rates',
    () async {
      await notifier().load();
      await notifier().saveProfile(
        const Profile(
          name: 'EV',
          userType: UserType.soleProprietor,
          taxRegime: TaxRegime.itemized,
        ),
      );
      expect(await notifier().addBusinessCategories(), isTrue);
      // Twice adds nothing more.
      await notifier().addBusinessCategories();
      final business = state().categories
          .where((c) => c.taxTreatment != TaxTreatment.none)
          .toList();
      expect(business, hasLength(BuiltInCategories.current.itemized.length));
      final revenue = business.firstWhere(
        (c) => c.taxTreatment == TaxTreatment.revenue,
      );
      expect(revenue.systemKey, 'bizRevenue');

      await notifier().saveAccount(
        const Account(name: 'Bank EUR', currency: Currency.eur),
      );
      final account = state().accounts.single;
      await notifier().saveEntry(
        Entry(
          accountId: account.id!,
          categoryId: revenue.id,
          type: EntryType.income,
          amount: 833300,
          date: DateTime(2026, 1, 5),
          rate: 386.07,
        ),
      );
      expect(state().entries.single.exchangeRate, 3860700);
      expect(state().entries.single.rate, 386.07);
      expect(state().entries.single.huf(Currency.eur), 3217121);

      await notifier().saveAsset(
        Asset(
          name: 'Laptop',
          purchaseDate: DateTime(2026, 2, 1),
          amount: 600000,
          rate: 3300,
        ),
      );
      expect(state().assets.single.userId, state().profile!.id);

      // A renamed business category keeps its treatment.
      await notifier().saveCategory(revenue.copyWith(name: 'Árbevétel'));
      final renamed = state().category(revenue.id)!;
      expect(renamed.systemKey, isNull);
      expect(renamed.taxTreatment, TaxTreatment.revenue);
    },
  );

  test('restoring a backup reloads the state', () async {
    await notifier().load();
    await notifier().saveProfile(const Profile(name: 'Anna'));
    final bytes = await notifier().backup();
    await notifier().saveProfile(const Profile(name: 'Béla'));
    expect(state().profiles, hasLength(2));

    await notifier().restore(bytes);
    expect(state().profiles.map((p) => p.name), ['Anna']);
    expect(state().profile!.name, 'Anna');
  });

  test('a failed save returns false and keeps the state', () async {
    final notifier = container.read(financeProvider.notifier);
    await notifier.load();
    // Amount 0 breaks the CHECK constraint.
    final ok = await notifier.saveEntry(
      Entry(
        accountId: 1,
        type: EntryType.income,
        amount: 0,
        date: DateTime(2026),
      ),
    );
    expect(ok, isFalse);
    expect(container.read(financeProvider).entries, isEmpty);
  });

  test("a user can't change or delete another user's category, account, "
      'entry or transfer', () async {
    await notifier().load();
    await notifier().saveProfile(const Profile(name: 'Anna'));
    await notifier().saveAccount(const Account(name: 'Anna bank'));
    await notifier().saveAccount(const Account(name: 'Anna cash'));
    // Without entries: only being hers stops deleting it.
    await notifier().saveAccount(const Account(name: 'Anna empty'));
    final annasCategory = state().categories.first;
    final annasAccounts = state().accounts.take(2).toList();
    final annasEmpty = state().accounts.last;
    await notifier().saveEntry(
      Entry(
        accountId: annasAccounts.first.id!,
        categoryId: annasCategory.id,
        type: annasCategory.type,
        amount: 100,
        date: DateTime(2026, 11, 1),
      ),
    );
    final annasEntry = state().entries.single;
    final sides = transferSides(
      from: annasAccounts.first,
      to: annasAccounts.last,
      fromAmount: 50,
      date: DateTime(2026, 11, 2),
      main: Currency.huf,
    )!;
    await notifier().saveTransfer(null, sides.from, sides.to);
    final annasTransfer = state().entries
        .firstWhere((e) => e.isTransfer)
        .transferId!;

    // Béla is the current user now.
    await notifier().saveProfile(const Profile(name: 'Béla'));
    await notifier().saveAccount(const Account(name: 'Béla bank'));
    final belasAccount = state().accounts.single;
    expect(state().profile!.name, 'Béla');

    expect(
      await notifier().saveCategory(annasCategory.copyWith(name: 'Hacked')),
      isFalse,
    );
    expect(await notifier().deleteCategory(annasCategory), isFalse);
    expect(
      await notifier().saveAccount(
        annasAccounts.first.copyWith(name: 'Hacked'),
      ),
      isFalse,
    );
    expect(await notifier().deleteAccount(annasEmpty), isFalse);
    // An entry: not on her account, not in her category, not hers.
    final belasEntry = Entry(
      accountId: belasAccount.id!,
      type: EntryType.expense,
      amount: 1,
      date: DateTime(2026, 11, 3),
    );
    expect(
      await notifier().saveEntry(
        Entry(
          accountId: annasAccounts.first.id!,
          type: EntryType.expense,
          amount: 1,
          date: DateTime(2026, 11, 3),
        ),
      ),
      isFalse,
    );
    expect(
      await notifier().saveEntry(
        Entry(
          accountId: belasAccount.id!,
          categoryId: annasCategory.id,
          type: annasCategory.type,
          amount: 1,
          date: DateTime(2026, 11, 3),
        ),
      ),
      isFalse,
    );
    expect(
      await notifier().saveEntry(
        Entry(
          id: annasEntry.id,
          accountId: belasAccount.id!,
          type: EntryType.expense,
          amount: 1,
          date: DateTime(2026, 11, 3),
        ),
      ),
      isFalse,
    );
    expect(await notifier().deleteEntry(annasEntry), isFalse);
    expect(await notifier().deleteTransfer(annasTransfer), isFalse);
    // His own goes.
    expect(await notifier().saveEntry(belasEntry), isTrue);

    // Anna's things are as they were.
    await notifier().selectProfile(state().profiles.first);
    expect(state().profile!.name, 'Anna');
    expect(
      state().categories.firstWhere((c) => c.id == annasCategory.id).name,
      annasCategory.name,
    );
    expect(state().accounts.map((a) => a.name), [
      'Anna bank',
      'Anna cash',
      'Anna empty',
    ]);
    expect(state().entries, hasLength(3));
    expect(
      state().entries.firstWhere((e) => e.id == annasEntry.id).amount,
      100,
    );
  });
}
