import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'confirm_dialog.dart';

/// New category of [type] (without [category]) or edit / delete [category].
Future<void> showCategoryDialog(
  BuildContext context, {
  EntryCategory? category,
  EntryType type = EntryType.expense,
}) => showDialog(
  context: context,
  builder: (context) => CategoryDialog(category: category, type: type),
);

class CategoryDialog extends ConsumerStatefulWidget {
  const CategoryDialog({super.key, this.category, required this.type});

  final EntryCategory? category;
  final EntryType type;

  @override
  ConsumerState<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late EntryType _type;
  late int _color;
  late TaxTreatment _treatment;
  late String _icon;
  bool _saving = false;
  bool _initialized = false;

  // The name as the field first showed it (translated for a built-in
  // category): only a different text renames the category.
  String _shownName = '';

  bool get _isNew => widget.category == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _type = widget.category?.type ?? widget.type;
    _color = widget.category?.color ?? categoryColors.first;
    _treatment = widget.category?.taxTreatment ?? TaxTreatment.none;
    final category = widget.category;
    // A new category starts with a random icon; a saved one without icon
    // keeps the one shown for it.
    _icon = category == null
        ? categoryIcons.keys.elementAt(Random().nextInt(categoryIcons.length))
        : category.icon ??
              categoryIcons.keys.elementAt(
                (category.id ?? 0) % categoryIcons.length,
              );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final category = widget.category;
    if (category != null) {
      _shownName = context.l10n.categoryName(category);
      _name.text = _shownName;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    final name = _name.text.trim();
    final old = widget.category;
    final category = old == null
        ? EntryCategory(
            name: name,
            type: _type,
            color: _color,
            taxTreatment: _treatment,
            // Of the current user's kind.
            scope: ref.read(financeProvider).categoryScope,
            icon: _icon,
          )
        : old.copyWith(
            name: name == _shownName ? null : name,
            color: _color,
            taxTreatment: _treatment,
            icon: _icon,
          );
    setState(() => _saving = true);
    final ok = await ref.read(financeProvider.notifier).saveCategory(category);
    if (!mounted) return;
    if (ok) {
      nav.pop();
    } else {
      setState(() => _saving = false);
      showMessage(context, l10n.saveError);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    if (!await showConfirmDialog(context, l10n.deleteCategoryConfirm)) return;
    final ok = await ref
        .read(financeProvider.notifier)
        .deleteCategory(widget.category!);
    if (!mounted) return;
    if (ok) {
      nav.pop();
    } else {
      showMessage(context, l10n.deleteError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The tax treatment only matters for itemized taxation.
    final profile = ref.watch(financeProvider.select((s) => s.profile));
    final itemized =
        (profile?.isSoleProprietor ?? false) &&
            profile?.taxRegime == TaxRegime.itemized ||
        _treatment != TaxTreatment.none;
    return AlertDialog(
      title: Text(_isNew ? l10n.addCategory : l10n.editCategory),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                autofocus: _isNew,
                decoration: InputDecoration(labelText: l10n.name),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? l10n.nameRequired : null,
              ),
              const SizedBox(height: 12),
              // Fixed once saved: its entries have this type.
              SegmentedButton<EntryType>(
                segments: [
                  for (final type in EntryType.values)
                    ButtonSegment(
                      value: type,
                      label: Text(l10n.entryTypeName(type)),
                    ),
                ],
                selected: {_type},
                onSelectionChanged: _isNew
                    ? (value) => setState(() {
                        _type = value.first;
                        if (_treatment.type != null &&
                            _treatment.type != _type) {
                          _treatment = TaxTreatment.none;
                        }
                      })
                    : null,
              ),
              if (itemized) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<TaxTreatment>(
                  // Other choices for the other type.
                  key: ValueKey(_type),
                  initialValue: _treatment,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.taxTreatment),
                  items: [
                    for (final treatment in TaxTreatment.of(_type))
                      DropdownMenuItem(
                        value: treatment,
                        child: Text(
                          l10n.taxTreatmentName(treatment),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _treatment = value!),
                ),
              ],
              const SizedBox(height: 12),
              Text(l10n.color),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in categoryColors)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _color = color),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(color),
                        child: color == _color
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.icon),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final MapEntry(key: key, value: icon)
                      in categoryIcons.entries)
                    IconButton(
                      tooltip: key,
                      isSelected: key == _icon,
                      style: IconButton.styleFrom(
                        backgroundColor: key == _icon ? Color(_color) : null,
                        foregroundColor: key == _icon ? Colors.white : null,
                      ),
                      onPressed: () => setState(() => _icon = key),
                      icon: Icon(icon),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!_isNew)
          TextButton(
            onPressed: _saving ? null : _delete,
            child: Text(l10n.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.save)),
      ],
    );
  }
}
