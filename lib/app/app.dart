import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/config.dart';
import '../l10n/l10n.dart';
import '../providers/providers.dart';

class Fineva extends ConsumerStatefulWidget {
  const Fineva({super.key});

  /// Android: the native splash goes away after this even if the data is
  /// still loading.
  static const Duration maxSplashDuration = Duration(seconds: 3);

  @override
  ConsumerState<Fineva> createState() => _FinevaState();
}

class _FinevaState extends ConsumerState<Fineva> {
  bool _splashRemoved = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;
    // main() kept the native splash: remove it when the data is loaded.
    ref.listenManual(financeProvider.select((state) => state.loaded), (
      _,
      loaded,
    ) {
      if (loaded) _removeSplash();
    }, fireImmediately: true);
    Future.delayed(Fineva.maxSplashDuration, _removeSplash);
  }

  // Only once: removing it twice would fail.
  void _removeSplash() {
    if (_splashRemoved) return;
    _splashRemoved = true;
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ref.watch(modeProvider),
      routerConfig: ref.watch(routesProvider),
    );
  }
}
