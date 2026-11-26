import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// The current user, the users, the onboarding at start, language, theme,
/// backup and restore.
class SettingsPage extends ConsumerWidget {
  static SettingsPage builder(BuildContext context, GoRouterState state) =>
      const SettingsPage();

  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final mode = ref.watch(modeProvider);
    final profile = ref.watch(financeProvider.select((state) => state.profile));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      drawer: mainDrawer(context, MainDestination.settings),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  if (profile != null)
                    ListTile(
                      leading: UserAvatar(profile: profile),
                      title: Text(l10n.userName(profile)),
                      subtitle: Text(l10n.profileSummary(profile)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.pushNamed(Routes.profile.name),
                    ),
                  SwitchListTile(
                    secondary: const Icon(Icons.start),
                    title: Text(l10n.onboardingAtStart),
                    subtitle: Text(l10n.onboardingAtStartText),
                    value: ref.watch(onboardingAtStartProvider),
                    onChanged: ref.read(onboardingAtStartProvider.notifier).set,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(l10n.language, style: titleStyle),
            const SizedBox(height: 8),
            const LanguageChoice(),
            const SizedBox(height: 24),
            Text(l10n.theme, style: titleStyle),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto),
                  label: Text(l10n.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode),
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode),
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (value) =>
                  ref.read(modeProvider.notifier).setMode(value.first),
            ),
            const SizedBox(height: 24),
            Text(l10n.data, style: titleStyle),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.currency_exchange),
                    title: Text(l10n.exchangeRates),
                    subtitle: Text(l10n.exchangeRatesText),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.pushNamed(Routes.rates.name),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.download),
                    title: Text(l10n.ratesAtStart),
                    subtitle: Text(l10n.ratesAtStartText),
                    value: ref.watch(ratesAtStartProvider),
                    onChanged: ref.read(ratesAtStartProvider.notifier).set,
                  ),
                  ListTile(
                    leading: const Icon(Icons.save_alt),
                    title: Text(l10n.backup),
                    subtitle: Text(l10n.backupText),
                    onTap: () => _backup(context, ref),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore),
                    title: Text(l10n.restore),
                    subtitle: Text(l10n.restoreText),
                    onTap: () => _restore(context, ref),
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

/// Saves every user's data into a file the user picks.
Future<void> _backup(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  try {
    final bytes = await ref.read(financeProvider.notifier).backup();
    final saved = await FilePicker.saveFile(
      dialogTitle: l10n.backup,
      fileName: 'fineva-${Entry.dateText(DateTime.now())}.db',
      bytes: bytes,
    );
    if (saved != null && context.mounted) {
      showMessage(context, l10n.backupSaved);
    }
  } catch (e) {
    debugPrint('Backup failed: $e');
    if (context.mounted) showMessage(context, l10n.backupError);
  }
}

/// Replaces every user's data with a backup file the user picks.
Future<void> _restore(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final confirmed = await showConfirmDialog(
    context,
    l10n.restoreConfirm,
    confirmText: l10n.restore,
  );
  if (!confirmed) return;
  try {
    final file = await FilePicker.pickFile(dialogTitle: l10n.restore);
    if (file == null) return;
    await ref.read(financeProvider.notifier).restore(await file.readAsBytes());
    if (!context.mounted) return;
    showMessage(context, l10n.restored);
    final empty = ref.read(financeProvider).profiles.isEmpty;
    context.go(empty ? Routes.onboarding.path : Routes.dashboard.path);
  } on BackupException catch (e) {
    if (!context.mounted) return;
    showMessage(context, switch (e.error) {
      BackupError.invalid => l10n.restoreInvalid,
      BackupError.newer => l10n.restoreNewer,
    });
  } catch (e) {
    debugPrint('Restore failed: $e');
    if (context.mounted) showMessage(context, l10n.restoreError);
  }
}
