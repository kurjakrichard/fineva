import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';

/// Shown by the router for an unknown route.
class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key, this.error});

  final GoException? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.errorMessage('${error?.message}'),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
