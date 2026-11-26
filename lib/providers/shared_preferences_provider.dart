import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/utils.dart';

/// Overridden in main() with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final sharedUtilityProvider = Provider<SharedUtility>((ref) {
  final sharedPrefs = ref.watch(sharedPreferencesProvider);
  return SharedUtility(sharedPreferences: sharedPrefs);
});

/// The app's settings in SharedPreferences.
class SharedUtility {
  SharedUtility({required this.sharedPreferences});

  final SharedPreferences sharedPreferences;

  /// Saved language code, null until the user picks one.
  String? getLocale() => sharedPreferences.getString(shareLocaleKey);

  void setLocale({required String locale}) {
    sharedPreferences.setString(shareLocaleKey, locale);
  }

  /// Saved theme mode name ('system', 'light', 'dark'), '' if none.
  String getMode() => sharedPreferences.getString(shareModeKey) ?? '';

  void setMode({required String mode}) {
    sharedPreferences.setString(shareModeKey, mode);
  }

  /// Id of the user the app was last used as, null if none.
  int? getCurrentUser() => sharedPreferences.getInt(shareCurrentUserKey);

  void setCurrentUser(int id) {
    sharedPreferences.setInt(shareCurrentUserKey, id);
  }

  /// Whether the onboarding opens at every start, not only at the first.
  /// On until it is turned off in Settings.
  bool getOnboardingAtStart() =>
      sharedPreferences.getBool(shareOnboardingKey) ?? true;

  void setOnboardingAtStart(bool value) {
    sharedPreferences.setBool(shareOnboardingKey, value);
  }

  /// Whether the missing exchange rates are downloaded at every start. On
  /// until it is turned off on the rates page.
  bool getRatesAtStart() =>
      sharedPreferences.getBool(shareRatesAtStartKey) ?? true;

  void setRatesAtStart(bool value) {
    sharedPreferences.setBool(shareRatesAtStartKey, value);
  }
}
