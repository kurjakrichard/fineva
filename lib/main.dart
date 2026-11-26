import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'data/data_export.dart';
import 'providers/providers.dart';
import 'utils/utils.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Android: the native splash stays until the data is loaded (app.dart).
  // Windows and Linux show SplashPage instead.
  if (Platform.isAndroid) FlutterNativeSplash.preserve(widgetsBinding: binding);
  final prefs = await SharedPreferences.getInstance();
  // Before the database is opened: new users and the new ones of every
  // user come from it, and the names of the categories made from it.
  await BuiltInCategories.load();
  final container = ProviderContainer(
    observers: [if (kDebugMode) MyObserver()],
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const Fineva()),
  );
  // The missing exchange rates, if Settings allow it; nothing waits for it.
  unawaited(container.read(ratesProvider.notifier).update(atStart: true));
}
