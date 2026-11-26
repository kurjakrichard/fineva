import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

/// The first page. When the data is loaded it goes on to the onboarding (no
/// user yet, or the onboarding is turned on for every start in Settings) or
/// the dashboard.
///
/// Windows and Linux show it for at least [minDuration]. On Android the
/// native splash, which looks the same, covers it until the data is loaded
/// (app.dart), so it goes on at once.
class SplashPage extends ConsumerStatefulWidget {
  static SplashPage builder(BuildContext context, GoRouterState state) =>
      const SplashPage();

  const SplashPage({super.key});

  static Duration get minDuration =>
      Platform.isAndroid ? Duration.zero : const Duration(milliseconds: 1500);

  /// Goes on even if loading takes longer.
  static const Duration maxDuration = Duration(seconds: 5);

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  final _loaded = Completer<void>();

  @override
  void initState() {
    super.initState();
    // Starts loading the data now, so the dashboard has it at once.
    ref.listenManual(financeProvider.select((state) => state.loaded), (
      _,
      loaded,
    ) {
      if (loaded && !_loaded.isCompleted) _loaded.complete();
    }, fireImmediately: true);
    _goOn();
  }

  Future<void> _goOn() async {
    await Future.wait([
      Future<void>.delayed(SplashPage.minDuration),
      _loaded.future.timeout(SplashPage.maxDuration, onTimeout: () {}),
    ]);
    if (!mounted) return;
    // After a failed load the dashboard shows the error.
    final state = ref.read(financeProvider);
    final onboarding =
        state.loaded &&
        state.error == null &&
        (state.profiles.isEmpty ||
            ref.read(onboardingAtStartProvider) ||
            // E.g. a sole proprietor without a tax number can't go on.
            !(state.profile?.isComplete ?? false));
    context.go(onboarding ? Routes.onboarding.path : Routes.dashboard.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: splashColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(logoMarkAsset, height: 160),
            const SizedBox(height: 32),
            Text(
              l10n.appTitle,
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tagline,
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
