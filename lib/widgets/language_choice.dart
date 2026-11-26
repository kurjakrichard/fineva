import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

/// The app's language; changing it takes effect at once.
class LanguageChoice extends ConsumerWidget {
  const LanguageChoice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<String>(
      segments: [
        for (final code in appLanguages)
          ButtonSegment(
            value: code,
            label: Text(appLanguageNames[code] ?? code),
          ),
      ],
      selected: {ref.watch(localeProvider).languageCode},
      onSelectionChanged: (value) =>
          ref.read(localeProvider.notifier).setLanguage(value.first),
    );
  }
}
