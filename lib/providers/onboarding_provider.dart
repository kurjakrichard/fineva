import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_preferences_provider.dart';

/// Whether SplashPage opens the onboarding at every start (Settings), not
/// only when there is no user yet.
class OnboardingAtStartNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedUtilityProvider).getOnboardingAtStart();

  void set(bool value) {
    ref.read(sharedUtilityProvider).setOnboardingAtStart(value);
    state = value;
  }
}

final onboardingAtStartProvider =
    NotifierProvider<OnboardingAtStartNotifier, bool>(
      OnboardingAtStartNotifier.new,
    );
