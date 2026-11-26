import 'package:flutter/material.dart';

/// Width class of the window. The menu and the page layouts follow it:
/// a drawer on phones, a navigation rail on tablets and narrow windows, a
/// menu that is always open on wide screens.
enum ScreenSize {
  compact,
  medium,
  expanded;

  /// Narrowest [medium] window.
  static const double mediumWidth = 720;

  /// Narrowest [expanded] window.
  static const double expandedWidth = 1140;

  static ScreenSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= expandedWidth) return expanded;
    if (width >= mediumWidth) return medium;
    return compact;
  }

  bool get isCompact => this == compact;
}

/// [children] side by side (equally wide) from [ScreenSize.medium], under
/// each other on a phone. [spacing] between them either way.
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({super.key, required this.children, this.spacing = 12});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (ScreenSize.of(context).isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing,
        children: children,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing,
      children: [for (final child in children) Expanded(child: child)],
    );
  }
}
