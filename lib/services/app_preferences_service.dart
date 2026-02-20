import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'user_service.dart';
import '../theme/app_theme.dart';

class AppPreferencesService {
  static final AppPreferencesService _instance =
      AppPreferencesService._internal();

  factory AppPreferencesService() => _instance;

  AppPreferencesService._internal();

  final _authService = AuthService();
  final _userService = UserService();

  final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> notificationsEnabledNotifier =
      ValueNotifier<bool>(true);

  Future<void> loadPreferences() async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final profile = await _userService.getUserProfile(userId);
    final darkMode = profile?.darkMode ?? false;
    final notificationsEnabled = profile?.enableNotifications ?? true;

    darkModeNotifier.value = darkMode;
    notificationsEnabledNotifier.value = notificationsEnabled;
    AppColors.setDarkMode(darkMode);
  }

  Future<void> setDarkMode(bool enabled) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    darkModeNotifier.value = enabled;
    AppColors.setDarkMode(enabled);
    await _userService.updateUserProfile(userId, {'darkMode': enabled});
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    notificationsEnabledNotifier.value = enabled;
    await _userService.updateUserProfile(userId, {
      'enableNotifications': enabled,
    });
  }
}
