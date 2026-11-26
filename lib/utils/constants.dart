import 'package:flutter/material.dart';

// SharedPreferences keys
const String shareLocaleKey = 'locale';
const String shareModeKey = 'mode';
const String shareCurrentUserKey = 'currentUser';
const String shareOnboardingKey = 'onboardingAtStart';
const String shareRatesAtStartKey = 'ratesAtStart';

/// Widest content on large screens (forms, lists).
const double maxWidth = 900;

/// The app's database, in the app support folder.
const String dbName = 'fineva.db';

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

/// Both themes are generated from this color.
const Color seedColor = Color.fromRGBO(22, 120, 104, 1);

/// Background of the splash screens (also flutter_native_splash in
/// pubspec.yaml: #167868) and the drawer header.
const Color splashColor = seedColor;

/// The logo's white "F." mark, see assets/logo.
const String logoMarkAsset = 'assets/logo/splash.png';

/// Amounts of income and expense entries.
const Color incomeColor = Color.fromRGBO(46, 125, 50, 1);
const Color expenseColor = Color.fromRGBO(198, 40, 40, 1);

/// Colors a category can have (ARGB).
const List<int> categoryColors = [
  0xFF2E7D32, // green
  0xFF00897B, // teal
  0xFF1E88E5, // blue
  0xFF3949AB, // indigo
  0xFF8E24AA, // purple
  0xFFD81B60, // pink
  0xFFE53935, // red
  0xFFF4511E, // deep orange
  0xFFFFB300, // amber
  0xFF6D4C41, // brown
  0xFF546E7A, // blue grey
];
