import 'package:flutter/material.dart';

import '../data/data_export.dart';
import '../utils/utils.dart';

/// A category's icon on its color in a circle. Without a category, gray
/// with an arrow of the entry's [type]; an opening entry's a flag, a
/// transfer's two arrows.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.category,
    this.type,
    this.radius = 20,
    this.opening = false,
    this.transfer = false,
  });

  /// Of an opening entry ([Entry.opening]).
  final bool opening;

  /// Of a transfer's side ([Entry.transferId]).
  final bool transfer;

  final EntryCategory? category;

  /// For the arrow when there is no category.
  final EntryType? type;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final category = this.category;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(
        opening || transfer ? 0xFF546E7A : category?.color ?? 0xFF9E9E9E,
      ),
      foregroundColor: Colors.white,
      child: Icon(
        opening
            ? Icons.flag
            : transfer
            ? Icons.swap_horiz
            : category != null
            ? categoryIcon(category.icon, category.id)
            : type == EntryType.income
            ? Icons.arrow_downward
            : Icons.arrow_upward,
        size: radius * 1.1,
      ),
    );
  }
}
