import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_preferences_provider.dart';

/// Light, dark, or the device's setting (the default).
class ModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.watch(sharedUtilityProvider).getMode();
    return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
  }

  void setMode(ThemeMode mode) {
    ref.read(sharedUtilityProvider).setMode(mode: mode.name);
    state = mode;
  }
}

final modeProvider = NotifierProvider<ModeNotifier, ThemeMode>(
  ModeNotifier.new,
);
