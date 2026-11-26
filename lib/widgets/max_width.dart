import 'package:flutter/material.dart';

import '../utils/utils.dart';

/// [child] centered and at most [maxWidth] wide, for large screens.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
