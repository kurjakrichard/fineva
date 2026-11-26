import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../pages/pages.dart';
import '../../utils/utils.dart';
import 'app_routes.dart';

final navigationKey = GlobalKey<NavigatorState>();

/// The app's router, created once. It starts at SplashPage, which goes on
/// to the onboarding or the dashboard once the data is loaded.
final routesProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: navigationKey,
    initialLocation: Routes.splash.path,
    errorBuilder: (context, state) => ErrorPage(error: state.error),
    routes: appRoutes,
  );
});
