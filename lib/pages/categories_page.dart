import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// The income and expense categories of the current user's kind (personal
/// or business); tap one to edit it.
class CategoriesPage extends ConsumerWidget {
  static CategoriesPage builder(BuildContext context, GoRouterState state) =>
      const CategoriesPage();

  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(financeProvider);
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.categories)),
      drawer: mainDrawer(context, MainDestination.categories),
      body: MaxWidth(
        child: ListView(
          children: [
            for (final type in EntryType.values) ...[
              ListTile(
                title: Text(l10n.entryTypeName(type), style: titleStyle),
                trailing: IconButton(
                  tooltip: l10n.addCategory,
                  icon: const Icon(Icons.add),
                  onPressed: () => showCategoryDialog(context, type: type),
                ),
              ),
              for (final category in state.visibleCategories)
                if (category.type == type)
                  ListTile(
                    leading: CategoryAvatar(category: category, radius: 16),
                    title: Text(l10n.categoryName(category)),
                    onTap: () =>
                        showCategoryDialog(context, category: category),
                  ),
              const Divider(),
            ],
          ],
        ),
      ),
    );
  }
}
