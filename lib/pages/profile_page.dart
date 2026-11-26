import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// A user's details and financial profile: personal or sole proprietor
/// finances, taxation, VAT, EU reporting. Edits [profile] (the current user
/// if null), or adds it as a new user if it has no id; a new user becomes
/// the current one. Opened from Settings and the users page.
class ProfilePage extends ConsumerStatefulWidget {
  static ProfilePage builder(BuildContext context, GoRouterState state) =>
      ProfilePage(profile: state.extra as Profile?);

  const ProfilePage({super.key, this.profile});

  final Profile? profile;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late Profile _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile =
        widget.profile ?? ref.read(financeProvider).profile ?? const Profile();
  }

  bool get _isNew => _profile.id == null;

  Future<void> _delete() async {
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      l10n.deleteUserConfirm(l10n.userName(_profile)),
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(financeProvider.notifier).deleteProfile(_profile);
    if (!mounted) return;
    if (ok) {
      nav.pop();
    } else {
      showMessage(context, l10n.deleteError);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final ok = await ref.read(financeProvider.notifier).saveProfile(_profile);
    if (!mounted) return;
    if (ok && _isNew) {
      // The new user is the current one: their dashboard.
      context.go(Routes.dashboard.path);
    } else if (ok) {
      nav.pop();
    } else {
      setState(() => _saving = false);
      showMessage(context, l10n.saveError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    // The last user can't be deleted.
    final canDelete =
        !_isNew &&
        ref.watch(financeProvider.select((s) => s.profiles.length)) > 1;
    return Scaffold(
      drawer: mainDrawer(context, MainDestination.settings),
      appBar: AppBar(
        leading: backButton(context),
        title: Text(_isNew ? l10n.newUser : l10n.profile),
        actions: [
          if (canDelete)
            IconButton(
              tooltip: l10n.deleteUser,
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: MaxWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Fixed once saved: not shown then.
              if (_isNew) ...[
                UserTypeChoice(
                  profile: _profile,
                  onChanged: (profile) => setState(() => _profile = profile),
                ),
                const SizedBox(height: 24),
              ],
              Text(l10n.detailsTitle, style: titleStyle),
              const SizedBox(height: 16),
              UserDataForm(
                profile: _profile,
                onChanged: (profile) => setState(() => _profile = profile),
              ),
              if (_profile.isSoleProprietor) ...[
                const SizedBox(height: 24),
                Text(l10n.businessTitle, style: titleStyle),
                const SizedBox(height: 16),
                BusinessProfileForm(
                  profile: _profile,
                  onChanged: (profile) => setState(() => _profile = profile),
                ),
              ],
              const SizedBox(height: 24),
              // Leaving without saving: Cancel.
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.maybePop(context),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
