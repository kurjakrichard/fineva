import 'package:flutter/material.dart';

/// One of several choices, like a radio button, as a card with a title and
/// an explanation.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;

  /// Null: it can't be chosen (shown, but disabled).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final subtitle = this.subtitle;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      // Outlined only: a shadow made the border look dark.
      elevation: 0,
      shape: shape.copyWith(
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        shape: shape,
        selected: selected,
        leading: icon == null ? null : Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        ),
        onTap: onTap,
      ),
    );
  }
}
