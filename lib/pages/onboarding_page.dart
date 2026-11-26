import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// Language and user (an existing one or a new one), personal or sole
/// proprietor finances, the user's details (name, address, tax
/// identifiers), then (for a sole proprietor) taxation, VAT and EU
/// reporting. Saving the [Profile] finishes it, and makes it the current
/// user. An existing user can skip the rest after the first page.
///
/// SplashPage shows it while there is no user, and at every start while it
/// is turned on in Settings.
///
/// The pages only change with the buttons, so the details are always
/// checked before going on.
class OnboardingPage extends ConsumerStatefulWidget {
  static OnboardingPage builder(BuildContext context, GoRouterState state) =>
      const OnboardingPage();

  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _pageChange = Duration(milliseconds: 250);

  /// Index of the steps with a form.
  static const _usagePage = 1;
  static const _detailsPage = 2;
  static const _businessPage = 3;

  final _pages = PageController();
  final _usageForm = GlobalKey<FormState>();
  final _detailsForm = GlobalKey<FormState>();
  final _businessForm = GlobalKey<FormState>();
  int _page = 0;

  /// The users there were when it opened.
  late final List<Profile> _users;

  /// The user being set up: one of [_users] or a new one (without id).
  late Profile _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(financeProvider);
    _users = state.profiles;
    _profile = state.profile ?? const Profile();
  }

  // The business step only for a sole proprietor.
  int get _pageCount => _profile.isSoleProprietor ? 4 : 3;
  bool get _isLast => _page == _pageCount - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    // The steps with a form are checked before going on: a sole proprietor
    // can't go on without a tax number.
    final form = switch (_page) {
      _usagePage => _usageForm,
      _detailsPage => _detailsForm,
      _businessPage => _businessForm,
      _ => null,
    };
    if (form != null && !form.currentState!.validate()) return;
    if (_isLast) {
      _finish();
    } else {
      _pages.nextPage(duration: _pageChange, curve: Curves.easeInOut);
    }
  }

  void _back() =>
      _pages.previousPage(duration: _pageChange, curve: Curves.easeInOut);

  // An existing user goes on without changes.
  Future<void> _skip() async {
    setState(() => _saving = true);
    await ref.read(financeProvider.notifier).selectProfile(_profile);
    if (mounted) context.go(Routes.dashboard.path);
  }

  Future<void> _finish() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    final ok = await ref
        .read(financeProvider.notifier)
        .saveProfile(_profile, select: true);
    if (!mounted) return;
    if (ok) {
      context.go(Routes.dashboard.path);
    } else {
      setState(() => _saving = false);
      showMessage(context, l10n.saveError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  _Step(
                    child: _Welcome(
                      users: _users,
                      selected: _profile.id,
                      onSelected: (user) =>
                          setState(() => _profile = user ?? const Profile()),
                    ),
                  ),
                  _Step(
                    title: l10n.usageTitle,
                    child: Form(
                      key: _usageForm,
                      child: UserTypeChoice(
                        profile: _profile,
                        onChanged: (profile) =>
                            setState(() => _profile = profile),
                      ),
                    ),
                  ),
                  _Step(
                    title: l10n.detailsTitle,
                    child: Form(
                      key: _detailsForm,
                      child: UserDataForm(
                        profile: _profile,
                        onChanged: (profile) =>
                            setState(() => _profile = profile),
                      ),
                    ),
                  ),
                  if (_profile.isSoleProprietor)
                    _Step(
                      title: l10n.businessTitle,
                      child: Form(
                        key: _businessForm,
                        child: BusinessProfileForm(
                          profile: _profile,
                          onChanged: (profile) =>
                              setState(() => _profile = profile),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _page > 0
                          ? TextButton(onPressed: _back, child: Text(l10n.back))
                          : _profile.id != null && _profile.isComplete
                          ? TextButton(
                              onPressed: _saving ? null : _skip,
                              child: Text(l10n.skip),
                            )
                          : null,
                    ),
                  ),
                  Expanded(
                    child: _PageDots(count: _pageCount, current: _page),
                  ),
                  SizedBox(
                    width: 120,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _saving ? null : _next,
                        child: Text(_isLast ? l10n.getStarted : l10n.next),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One page of the onboarding: [title] and [child], scrollable.
class _Step extends StatelessWidget {
  const _Step({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return MaxWidth(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Logo, welcome, the language and, if there are users, which one.
class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.users,
    required this.selected,
    required this.onSelected,
  });

  final List<Profile> users;

  /// Id of the selected user, null for a new one.
  final int? selected;

  /// Called with null for a new user.
  final ValueChanged<Profile?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: splashColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Image.asset(logoMarkAsset, height: 80),
        ),
        const SizedBox(height: 32),
        Text(
          users.isEmpty ? l10n.welcomeTitle : l10n.welcomeBackTitle,
          style: textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          users.isEmpty ? l10n.welcomeText : l10n.welcomeBackText,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Text(l10n.language, style: textTheme.titleMedium),
        const SizedBox(height: 8),
        const LanguageChoice(),
        if (users.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(l10n.whoUses, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final user in users)
            ChoiceCard(
              icon: Icons.person,
              title: l10n.userName(user),
              subtitle: l10n.profileSummary(user),
              selected: user.id == selected,
              onTap: () => onSelected(user),
            ),
          ChoiceCard(
            icon: Icons.person_add,
            title: l10n.newUser,
            subtitle: l10n.newUserText,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
        ],
      ],
    );
  }
}

/// Which page of [count] is shown.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
